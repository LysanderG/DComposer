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

import gdk.Color;

import glib.Idle;

import std.conv;
import std.stdio;
import std.string;
import std.file;


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

    void PromptCommands()
    {
		write ('>');
	    Debugger.Command(`-data-disassemble -s "$pc" -e "$pc + 240" -- 0`);
    }

    void RecieveDisassembly(string msg)
    {
		writeln(" >>> ",msg);
	    if(msg.startsWith("^done,"))
	    {
		    auto msgslice = msg["^done,".length .. $];
		    auto result = RESULT(msgslice);
            writeln(result._name);
	        if(result._name != "asm_insns") return;
	        mDisassemblyText.length = 0;
	        foreach(ln; result._value._list._tupleItems)
	        {
				string fname, address, offset, inst;
				string space = "                                           ";
				writeln('-',ln);
				if("func-name" in ln)fname   = ln["func-name"]._value._const.leftJustify(20); else fname = space;
				if("address" in ln)  address = ln["address"]._value._const.leftJustify(22); else address = space;
				if("offset" in ln)   offset  = ln["offset"]._value._const.center(3);else offset = space[0..3];
				if("inst" in ln)     inst    = ln["inst"]._value._const.leftJustify(20);else inst = space ;
	            mDisassemblyText ~= format("%s:%s-%s: %s\n", fname[0..20], address[0..22], offset, inst[0..20]);
            }
            mDisassemblyView.getBuffer.setText(mDisassemblyText);
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
		string sfile;
		int sline;
		Debugger.GetLocation(sfile, sline);
		if(sfile.exists())dui.GetDocMan.Open(sfile, sline);
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
        mDisassemblyView.modifyFont("freemono", 10);



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
        mBtnStop.addOnClicked(&BtnCommand);


	    dui.connect(&SetPagePosition);
	    Config.Reconfig.connect(&Configure);

	    mSideRoot.showAll();
	    mExtraRoot.showAll();

        Debugger.StreamOutput.connect(&GdbListener);
        Debugger.AsyncOutput.connect(&GdbListener);
        Debugger.ResultOutput.connect(&GdbListener);
        Debugger.ResultOutput.connect(&RecieveDisassembly);
        Debugger.Prompt.connect(&GotoIP);
        Debugger.Stopped.connect(&PromptCommands);

        Debugger.GdbExited.connect(&ClearText);

        dui.GetDocMan.Event.connect(&WatchForNewDocument);

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
