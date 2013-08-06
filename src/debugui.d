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

import gdk.Color;

import glib.Idle;

import std.conv;
import std.stdio;
import std.string;
import std.file;
import std.demangle;
import std.algorithm;

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

    string StrCmdRun = "-exec-run";
    string StrCmdContinue = "-exec-continue";
    string StrCmdStepIn = "-exec-step";
    string StrCmdStepOver = "-exec-next";
    string StrCmdStepOut = "-exec-finish";
    string StrCmdRunToCursor = "-exec-until";
    string StrCmdInsertBreakPoint = "-break-insert";

    int mDisFuncLen;
    int mDisAddressLen;
    int mDisOffsetLen;
    int mDisInstLen;
    int mDisOpcodeLen;

    string mLocationFile;
    int mLocationLine;
    string mLocationAddress;

    void PromptCommands()
    {
	    GotoIP();
	    Debugger.Command(`100-data-disassemble -s "$pc-16" -e "$pc + 256" -- 0`);
    }

    void RecieveDisassembly(string msg)
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
				mDisassemblyText ~= format("     %s:%s   %s\n",address, offset, inst);
				writeln(address.strip(), "--",mLocationAddress);
				if(address.strip() == mLocationAddress) hiliteLine = cast(int)i;
            }
            writeln(hiliteLine);
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
    }

    void ClearText()
    {
	    mOutputView.getBuffer.setText(" ");
	    mDisassemblyView.getBuffer.setText(" ");
	    mCallStackView.getBuffer.setText(" ");
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

        NewDoc.BreakPoint.connect(&CatchBreakPoint);
    }

    void GdbListener(string message)
    {
	    mOutputView.appendText(message ~ '\n');
    }

    bool PollGdb()
    {
	    bool AreStepButtonsSensitive;
	    Debugger.Process();
	    //if debugger state = prompting buttons = sensitive stop = not sensitive
	    if(Debugger.IsPrompting()) AreStepButtonsSensitive = true;
	    else AreStepButtonsSensitive = false;

	    //set stepping buttons sensitivity
	    //mBtnRun.setSensitive(AreExecButtonsSensitive());
	    mBtnStepIn.setSensitive(AreStepButtonsSensitive);
	    mBtnStepOut.setSensitive(AreStepButtonsSensitive);
	    mBtnStepOver.setSensitive(AreStepButtonsSensitive);
	    mBtnContinue.setSensitive(AreStepButtonsSensitive);
	    mBtnRunToCursor.setSensitive(AreStepButtonsSensitive);

	    //set run button sensitivity should only be on if (gdbspawned / target not running)
	    mBtnRun.setSensitive(!Debugger.IsRunning());

	    return (cast (bool)mSpawnGdb.getActive());
    }

    void SpawnGdb(ToggleButton tb)
    {
	    if(Project.Target() != TARGET.APP)
	    {
			Log.Entry("Failed to spawn gdb. Presently can only debug projects with an executable target.", "Error");
		    tb.setActive(0);
		    return;
        }

	    if (tb.getActive())
	    {
		    mButtonBox.setSensitive(1);
		    Debugger.Spawn(Project.Name());
		    mIdle = new Idle(&PollGdb);

	    }
	    else
	    {
		    mButtonBox.setSensitive(0);
		    Debugger.Unload();
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
			import core.sys.posix.signal;
			kill(Debugger.TargetID,2);
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

        Debugger.StreamOutput.connect(&GdbListener);
        Debugger.AsyncOutput.connect(&GdbListener);
        Debugger.ResultOutput.connect(&GdbListener);
        Debugger.ResultOutput.connect(&RecieveDisassembly);
        //Debugger.Prompt.connect(&GotoIP);
        Debugger.Stopped.connect(&PromptCommands);

        Debugger.GdbExited.connect(&ClearText);

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
