module debugui;

import ui;
import dcore;
import config;
import elements;
import document;
import debugger;

import gtk.Builder;
import gtk.Button;
import gtk.HButtonBox;
import gtk.HPaned;
import gtk.Label;
import gtk.Label;
import gtk.TextBuffer;
import gtk.TextBuffer;
import gtk.TextView;
import gtk.ToggleButton;
import gtk.VBox;
import gtk.VPaned;
import gtk.TextIter;
import gtk.Widget;
import gtk.Tooltip;

import gdk.Color;
import gdk.Rectangle;

import glib.Idle;

import std.conv;
import std.stdio;
import std.string;
import std.file;
import std.demangle;
import std.algorithm;
import std.path;

class DEBUG_UI : ELEMENT
{

private:
    string mName;
    string mInfo;
    bool mState;

    //gtkd stuff
    Builder mBuilder;
    VBox mSideRoot;
    VBox mExtraRoot;
    Idle mIdle;

    HButtonBox mButtonBox;
    Button mBtnRun;
    Button mBtnContinue;
    Button mBtnStepIn;
    Button mBtnStepOver;
    Button mBtnStepOut;
    Button mBtnRunToCursor;
    Button mBtnStop;
    ToggleButton mSpawnGdb;

    HPaned mPane1;
    HPaned mPane2;
    VPaned mPane3;
    VPaned mPane4;

    TextView mCallStackView;
    TextView mDisassemblyView;
    TextView mOutputView;
    TextView mWatchView;
    TextView mLocalView;
    TextView mBreakpointView;

    string mCallStackText;
    string mDisassemblyText;
    string mOutputText;
    string mWatchText;
    string mLocalText;
    string mBreakpointText;

    Label mLblWarning;

    //commonly used commands stored to hopefully reduce errors
    //and a common place to make changes
    string StrCmdRun = "-exec-run";
    string StrCmdContinue = "-exec-continue";
    string StrCmdStepIn = "-exec-step";
    string StrCmdStepOver = "-exec-next";
    string StrCmdStepOut = "-exec-finish";
    string StrCmdRunToCursor = "-exec-until";
    string StrCmdInsertBreakPoint = "-break-insert";

    
    //store length of disassembly values to make a "pretty" table
    int mDisFuncLen;
    int mDisAddressLen;
    int mDisOffsetLen;
    int mDisInstLen;
    int mDisOpcodeLen;

    //store where program was *stopped
    string mLocationFile;
    int mLocationLine;
    string mLocationAddress;
    
    //value of tooltip will on querytooltip will ask for --data-eval-exp word at mouse
    //then when that value is returned will set tooltip to it
    string mDebugTooltip;
    bool mTooltipHolding;
    
    void SetItemSensitivity(DBGR_STATE state)
    {
	    mButtonBox.setSensitive(1);
	    mBtnRun.setSensitive(1);
	    mBtnStop.setSensitive(0);
	    
        void TraceButtonsSensitive(bool active)
        {
	        mBtnContinue.setSensitive(active);
	        mBtnStepIn.setSensitive(active);
	        mBtnStepOver.setSensitive(active);
	        mBtnStepOut.setSensitive(active);
	        mBtnRunToCursor.setSensitive(active);
        }
	    
	    final switch (state) with (DBGR_STATE)
	    {
		    case OFF_OFF:
		            mButtonBox.setSensitive(0);
		            break;
		            
	        case ON_OFF:
	                TraceButtonsSensitive(0);
	                break;
	                
	        case ON_PAUSED:
	                TraceButtonsSensitive(1);
	                break;
	        
	        case BUSY_OFF:
	                TraceButtonsSensitive(0);
	                break;
	        
	        case BUSY_PAUSED:
	                TraceButtonsSensitive(0);
	                break;
	                
	        case BUSY_RUNNING:
                    mBtnRun.setSensitive(0);
                    TraceButtonsSensitive(0);
                    mBtnStop.setSensitive(1);
	                break;
	                
	        case BUSY_STOPPED:
	                break;
	        case ON_QUITTING:
	                TraceButtonsSensitive(1);
	                ClearText();
	                break;
	                
	        case QUITTING_ANY:
	                mButtonBox.setSensitive(0);
	                ClearText();
        }
        

		    
    }

    void IssueCommands()
    {
	    GotoIP();
	    Debugger.Command(`100-data-disassemble -s "$pc-16" -e "$pc + 256" -- 0`, false);
	    Debugger.Command(`110-stack-list-frames`,false);

    }

    void ReceiveDisassembly(string msg)
    {
		int hiliteLine = -1;

	    if(msg.startsWith("100^done,"))
	    {
		    auto msgslice = msg["100^done,".length .. $];
		    auto result = RECORD(msgslice);
	        mDisassemblyText.length = 0;
	        string oldfname = "aggm1967firstrun";
	        auto loops = result.GetValue("asm_insns")._list._values.length;
	        foreach(i, ln; result.GetValue("asm_insns")._list._values)
	        {
				string fname, address, offset, inst;

				if("func-name" in ln._values) fname   = ln.Get("func-name").toString().demangle();
				else fname = " ";
				if("address" in ln._values)   address = ln.Get("address").toString().leftJustify(mDisAddressLen);
				else {address.length = mDisAddressLen; }
				if("offset" in ln._values)    offset  = ln.Get("offset").toString().leftJustify(mDisOffsetLen);
				else offset = "           ";
				if("inst" in ln._values)      inst    = ln.Get("inst").toString().leftJustify(mDisInstLen);
				else inst = "------";

				if( (fname != oldfname) || (oldfname == "aggm1967firstrun"))
				{
					oldfname = fname;
					mDisassemblyText ~= oldfname ~ '\n';
				}
				mDisassemblyText ~= format(" %s+%s   %s\n",address, offset, inst);
				if(address.strip() == mLocationAddress) hiliteLine = cast(int)i;
            }
            mDisassemblyView.getBuffer.setText(mDisassemblyText);

			TextIter tis = new TextIter;
			TextIter tie = new TextIter;

			mDisassemblyView.getBuffer.getBounds(tis, tie);

			mDisassemblyView.getBuffer.removeAllTags(tis, tie);
			if(hiliteLine > -1)
			{
				mDisassemblyView.getBuffer.getIterAtLine(tie, hiliteLine);
				tie.forwardToLineEnd();
				mDisassemblyView.getBuffer.getIterAtLine(tis, hiliteLine);
				mDisassemblyView.getBuffer.applyTagByName("hilite", tis, tie);
			}

        }
        
        if(msg.startsWith("100^error,"))
        {
	        auto result = RECORD(msg["100^error,".length .. $]);
	        mDisassemblyText = result.Get("msg");
            mDisassemblyView.getBuffer.setText(mDisassemblyText);
        }
        
    }
    
    void ReceiveCallStack(string msg)
    {
	    auto msgStart = msg[0..std.string.indexOf(msg,',')+1];
	    msg = msg[msgStart.length..$];
	    
	    if(msgStart == "110^error,")
	    {
		    auto result = RECORD(msg);
		    mCallStackView.getBuffer.setText(result.Get("msg"));
		    return;
	    }
	    
	    if(msgStart != "110^done,") return;
	            
        mCallStackText.length = 0;
        string indentation;

	    auto result = RECORD(msg);	    
	    foreach(frame; result.GetValue("stack")._list._values)
	    {
		    string func;
		    if("func" in frame._values)func = frame.Get("func").toString().demangle();
		    else func = "indeterminate";
		      
		    mCallStackText ~= frame.Get("level").toString() ~ "| ";
		    mCallStackText ~= frame.Get("addr").toString() ~".";
		    mCallStackText ~= indentation ~ func ~ '\n'; 
		    indentation =indentation ~ " ";		    
	    }
	    mCallStackView.getBuffer.setText(mCallStackText);
    }
	    
    void ReceiveTooltip(string msg)
    {
	    //gdb with a token of 120 is returning a -data-eval-exp for a tooltip query
	    auto msgStart = msg[0..std.string.indexOf(msg,',')+1];
	    msg = msg[msgStart.length..$];
	    
	    mDebugTooltip.length = 0;

	    if(msgStart != "120^done,") {return;}
	    
	    mDebugTooltip = RECORD(msg).GetValue("value").toString();	    
	    //dui.GetDocMan.Current.triggerTooltipQuery();
	    
    }
    
    
    void ClearText()
    {
	    string nutext;
	    if(Debugger.State == DBGR_STATE.ON_QUITTING)nutext = "Target program not running";
	    if(Debugger.State == DBGR_STATE.QUITTING_ANY) nutext = "Debugging process (gdb) is not running";
	    mOutputView.getBuffer.setText(nutext);
	    mDisassemblyView.getBuffer.setText(nutext);
	    mCallStackView.getBuffer.setText(nutext);
    }

	void GotoIP()
	{

		Debugger.GetLocation(mLocationFile, mLocationLine, mLocationAddress);
		if(mLocationFile.exists())dui.GetDocMan.Open(mLocationFile, mLocationLine);
	}


    void CatchBreakPoint(string Action, string Srcfile, int line)
    {
		Log.Entry(StrCmdInsertBreakPoint ~ " " ~ Srcfile ~ ":" ~ to!string(line));
		Debugger.Command(StrCmdInsertBreakPoint ~ " " ~ Srcfile ~ ":" ~ to!string(line));
	}

	void WatchForNewDocument(string EventId, DOCUMENT NewDoc)
    {
        if (NewDoc is null ) return;
        if(EventId != "AppendDocument") return;

        writeln(NewDoc.Name.extension);
        if(!((NewDoc.Name.extension == ".d") || (NewDoc.Name.extension == ".di"))) return;
        writeln("here");
        NewDoc.BreakPoint.connect(&CatchBreakPoint);
        
        NewDoc.addOnQueryTooltip(&SetSymbolTip);
    }
    
    bool SetSymbolTip(int X, int Y, int FromKeyBoard, GtkTooltip * tt, Widget obj)
    {
	    if(Debugger.State != DBGR_STATE.ON_PAUSED) return true;
	    static string DocSym;
	    
	    void GetDocSym()
	    {
		    int x,y, unusedTrailing;
	        TextIter ti = new TextIter;	
	        TextIter tiBegins = new TextIter;    
	        //auto Thedoc = cast(DOCUMENT)obj;
	        auto Thedoc = dui.GetDocMan.Current();	    	    
	        Thedoc.windowToBufferCoords(TextWindowType.WIDGET, X, Y, x, y);
	        Thedoc.getIterAtPosition(ti, unusedTrailing, x, y);	    
	        DocSym = Thedoc.Symbol(ti, tiBegins, true);
        }
        

	    auto docTip = new Tooltip(tt); 
	    GdkRectangle gdkRectangle = {x:X-5, y:Y-5, width:10, height:10};
	    docTip.setTipArea(new Rectangle(&gdkRectangle));
        
        GetDocSym();
        
        if(DocSym.length > 1)
        {
	        Debugger.Command("120-data-evaluate-expression " ~ DocSym, false);
        }

        docTip.setText(mDebugTooltip);
        if(mDebugTooltip.length < 1) return false;
        return true;
    }

    void ReceiveGdb(string message)
    {
	    if(message[0] == '1')return;
	    mOutputView.appendText(message ~ '\n');
    }

    bool PollGdb()
    {
	    
	    Debugger.Process();

	    return (cast (bool)mSpawnGdb.getActive());
    }

    void SpawnGdb(ToggleButton tb)
    {
	    if(Project.Target() != TARGET.APP)
	    {
			Log.Entry("DEBUG_UI: Failed to spawn gdb. Presently can only debug projects with an executable target.", "Error");
		    tb.setActive(0);
		    return;
        }
        if(!Project.Name.exists())
        {
	        Log.Entry("DEBUG_UI: Target executable does not exist.","Error");
	        tb.setActive(0);
	        return;
        }
	    if (tb.getActive()) 
	    {
		    mIdle = new Idle(&PollGdb, GPriority.LOW);
		    //Debugger.Spawn();
	    }
	    else 
	    {
		    mIdle.stop();
		    Debugger.State = KILL;
	    }
      
    }

    void BtnCommand(Button TheButton)
    {
	    if(TheButton is mBtnRun)
	    {
		    Debugger.Command(StrCmdRun);
		    return;
	    }
	    if(TheButton is mBtnContinue)
	    {
			Debugger.Command(StrCmdContinue);
			return;
		}
		if(TheButton is mBtnStepIn)
		{
			Debugger.Command(StrCmdStepIn);
			return;
		}
		if(TheButton is mBtnStepOver)
		{
			Debugger.Command(StrCmdStepOver);
			return;
		}
		if(TheButton is mBtnStepOut)
		{
			Debugger.Command(StrCmdStepOut);
			return;
		}
		if(TheButton is mBtnRunToCursor)
		{
			string cmd = StrCmdRunToCursor;
			cmd ~= " " ~ dui.GetDocMan.Current().ShortName() ~":" ~ to!string(dui.GetDocMan.GetLineNo);
			Debugger.Command(cmd);
			return;
		}

		if(TheButton is mBtnStop)
		{
			//import core.sys.posix.signal;
			//kill(Debugger.TargetID,2);
			Debugger.Interrupt();			
			return;
		}

    }


protected:
	void Configure()
    {}

	void SetPagePosition(UI_EVENT uie)
	{
		switch (uie)
		{
			case UI_EVENT.RESTORE_GUI :
			{
				dui.GetSidePane.reorderChild(mSideRoot, Config.getInteger("DEBUG_UI", "side_page_position"));
				dui.GetExtraPane.reorderChild(mExtraRoot, Config.getInteger("DEBUG_UI", "extra_page_position"));

                mPane1.setPosition(Config.getInteger("DEBUG_UI", "hpaned1_position", 50));
                mPane2.setPosition(Config.getInteger("DEBUG_UI", "hpaned2_position", 50));

				mPane3.setPosition(Config.getInteger("DEBUG_UI", "vpaned1_position", 200));
                mPane4.setPosition(Config.getInteger("DEBUG_UI", "vpaned2_position", 100));
				break;
			}
			case UI_EVENT.STORE_GUI :
			{
				Config.setInteger("DEBUG_UI", "side_page_position", dui.GetSidePane.pageNum(mSideRoot));
				Config.setInteger("DEBUG_UI", "extra_page_position", dui.GetExtraPane.pageNum(mExtraRoot));
				break;
			}
			default :break;
		}
	}


public:
    this()
    {
	    mName = "DEBUG_UI";
	    mInfo = "Very primitive debugging tool using gdb as a backend. Probably very buggy itself :)";
    }

    @property string Name()
    {
	    return mName;
    }
    @property string Information()
    {
	    return mInfo;
    }
    @property bool   State()
    {
	    return mState;
    }
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        if(mState) Engage();
        else Disengage();
    }


    void Engage()
    {


	    mBuilder = new Builder;
	    mBuilder.addFromFile(Config.getString("DEBUG_UI", "glade_file",  "$(HOME_DIR)/glade/ntdb.glade"));

	    mExtraRoot      = cast(VBox)     mBuilder.getObject("vbox1");
	    mSideRoot       = cast(VBox)     mBuilder.getObject("vbox5");

	    mPane1          = cast(HPaned)   mBuilder.getObject("hpaned1");
	    mPane2          = cast(HPaned)   mBuilder.getObject("hpaned2");
	    mPane3          = cast(VPaned)   mBuilder.getObject("vpaned1");
	    mPane4          = cast(VPaned)   mBuilder.getObject("vpaned2");

	    mButtonBox      = cast(HButtonBox)   mBuilder.getObject("hbuttonbox1");
	    mSpawnGdb       = cast(ToggleButton) mBuilder.getObject("spawnGdbBtn");
	    mBtnRun         = cast(Button)       mBuilder.getObject("runBtn");
	    mBtnContinue    = cast(Button)       mBuilder.getObject("continueBtn");
        mBtnStepIn      = cast(Button)       mBuilder.getObject("stepInBtn");
        mBtnStepOver    = cast(Button)       mBuilder.getObject("stepOverBtn");
        mBtnStepOut     = cast(Button)       mBuilder.getObject("stepOutBtn");
        mBtnRunToCursor = cast(Button)       mBuilder.getObject("runToCursorBtn");
        mBtnStop        = cast(Button)       mBuilder.getObject("stopBtn");

        mOutputView     = cast(TextView)     mBuilder.getObject("outputView");
        mDisassemblyView= cast(TextView)     mBuilder.getObject("disassemblyView");
        mCallStackView  = cast(TextView)     mBuilder.getObject("callStackView");
        mOutputView.modifyBase(StateType.NORMAL, new Color(1000, 1000, 1000));
        mDisassemblyView.modifyFont("freemono", 14);
        mDisassemblyView.getBuffer.createTag("hilite", "background", "yellow");
        mCallStackView.modifyFont("freemono", 14);


	    dui.GetSidePane().appendPage(mSideRoot, "Debug");
	    dui.GetExtraPane().appendPage(mExtraRoot, "Debug");
	    dui.GetSidePane.setTabReorderable ( mSideRoot, true);
	    dui.GetExtraPane.setTabReorderable ( mExtraRoot, true);

        mButtonBox.setSensitive(0);
        mSpawnGdb.addOnToggled(&SpawnGdb);

        mBtnRun.addOnClicked(&BtnCommand);
        mBtnContinue.addOnClicked(&BtnCommand);
        mBtnStepIn.addOnClicked(&BtnCommand);
        mBtnStepOver.addOnClicked(&BtnCommand);
        mBtnStepOut.addOnClicked(&BtnCommand);
        mBtnRunToCursor.addOnClicked(&BtnCommand);
        mBtnStop.addOnClicked(&BtnCommand);


	    dui.connect(&SetPagePosition);
	    Config.Reconfig.connect(&Configure);

	    mSideRoot.showAll();
	    mExtraRoot.showAll();

        Debugger.StreamOutput.connect(&ReceiveGdb);
        Debugger.AsyncOutput.connect(&ReceiveGdb);
        Debugger.ResultOutput.connect(&ReceiveGdb);
        Debugger.ResultOutput.connect(&ReceiveDisassembly);
        Debugger.ResultOutput.connect(&ReceiveCallStack);
        Debugger.ResultOutput.connect(&ReceiveTooltip);
        Debugger.TargetStopped.connect(&IssueCommands);
        Debugger.GdbExited.connect(&ClearText);
        Debugger.NewState.connect(&SetItemSensitivity);

        dui.GetDocMan.Event.connect(&WatchForNewDocument);

		mDisFuncLen = Config.getInteger("DEBUG_UI","disfunclen" , 30);
		mDisAddressLen = Config.getInteger("DEBUG_UI","misaddresslen" ,22);
		mDisOffsetLen = Config.getInteger("DEBUG_UI", "disoffsetlen" ,6);
		mDisInstLen = Config.getInteger("DEBUG_UI", "disinstlen",40);
		mDisOpcodeLen = Config.getInteger("DEBUG_UI", "disopcodelen",40);

		
	    mState = true;
	    Log.Entry("Engaged "~Name()~"\t\telement.");
    }

    void Disengage()
    {
	    Config.setInteger("DEBUG_UI", "side_page_position", dui.GetSidePane.pageNum(mSideRoot));
	    Config.setInteger("DEBUG_UI", "extra_page_position", dui.GetExtraPane.pageNum(mExtraRoot));
	    Config.setInteger("DEBUG_UI", "hpaned1_position", mPane1.getPosition());
	    Config.setInteger("DEBUG_UI", "hpaned2_position", mPane2.getPosition());
	    Config.setInteger("DEBUG_UI", "vpaned1_position", mPane3.getPosition());
	    Config.setInteger("DEBUG_UI", "vpaned2_position", mPane4.getPosition());

	    mState = false;
	    Log.Entry("Disengaged "~mName~"\t\telement.");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
	    return null;
    }

}
