module debug_ui;

import std.traits;
import std.conv;
import std.file;
import std.string;
import core.demangle;
import std.stdio;
import std.path;


import gtk.Tooltip;
import gio.Cancellable;
import vte.Pty;

import dcore;
import ui;
import elements;
import document;

extern (C) string GetClassName()
{
    return fullyQualifiedName!DEBUG_UI;
}


class DEBUG_UI : ELEMENT
{
    public:
    
    void Engage()
    {
        
        
        auto builder = new Builder(ElementPath(Config.GetValue("debug_ui", "glade_file", "resources/debug_ui.glade")));
        
        mSideRoot = cast(Box)builder.getObject("sideroot");
        mSidePane = cast(Paned)builder.getObject("paned1");
        mInScopeView = cast(TreeView)builder.getObject("treeview1");
        mInScopeStore = cast(TreeStore)builder.getObject("treestore1");
        mOutScopeView = cast(TreeView)builder.getObject("treeview5");
        mOutScopeStore = cast(TreeStore)builder.getObject("treestore2");
        
        mExtraRoot      = cast(Box)builder.getObject("extraroot");
        mExtraPane      = cast(Paned)builder.getObject("paned2");
        mBtn_Start      = cast(ToolButton)builder.getObject("toolbutton1");
        mBtn_Continue   = cast(ToolButton)builder.getObject("toolbutton8");
        mBtn_Step_Over  = cast(ToolButton)builder.getObject("toolbutton2");
        mBtn_Step_In    = cast(ToolButton)builder.getObject("toolbutton3");
        mBtn_Step_Out   = cast(ToolButton)builder.getObject("toolbutton4");
        mBtn_To_Cursor  = cast(ToolButton)builder.getObject("toolbutton7");
        mBtn_Interrupt  = cast(ToolButton)builder.getObject("toolbutton5");
        mBtn_SwitchGdb  = cast(ToggleToolButton)builder.getObject("toggletoolbutton1");

        
        mFramesView     = cast(TreeView)builder.getObject("treeview2");
        mFramesStore    = cast(ListStore)builder.getObject("liststore1");
        
        mBreakBox       = cast(Box)builder.getObject("box5");
        mBreaksView     = cast(TreeView)builder.getObject("treeview4");
        mBreaksStore    = cast(ListStore)builder.getObject("liststore3");
                
        mBtn_Ins_Break  = cast(ToolButton)builder.getObject("toolbutton9");
        mBtn_Remove_Break=cast(ToolButton)builder.getObject("toolbutton10");
        
        mTglBreakEnabled = cast(CellRendererToggle)builder.getObject("cellrenderertoggle1");
        
        mTextView       = cast(TextView)builder.getObject("textview1");
        
        mTerminalWindow = cast(Window)builder.getObject("window1");

        
        mExtraPane.setPosition(Config.GetValue("debug_ui", "extra_pane_pos", 100));
        mSidePane.setPosition(Config.GetValue("debug_ui", "side_pane_pos", 100));
        
        mBtn_SwitchGdb.addOnToggled(&ToggleGdb);
        
	mBtn_Start.addOnClicked(delegate void(ToolButton tb)
        {
            ResetPty();
            mNtdb.StartTarget();
        });
	mBtn_Continue.addOnClicked(delegate void(ToolButton tb){mNtdb.ContinueTarget();});
	mBtn_Step_Over.addOnClicked(delegate void(ToolButton tb){mNtdb.StepOver();});
	mBtn_Step_In.addOnClicked(delegate void(ToolButton tb){mNtdb.StepIn();});
	mBtn_Step_Out.addOnClicked(delegate void(ToolButton tb){mNtdb.StepOut();});
	mBtn_To_Cursor.addOnClicked(delegate void(ToolButton tb)
	{
            string name;
            int oline,ocol;
            if(DocMan.Current is null) return;
            mNtdb.ToCursor(DocMan.Current.GetLocation(name, oline, ocol));
        });        
		mBtn_Interrupt.addOnClicked(delegate void(ToolButton tb){mNtdb.Interrupt();});
        
        mBtn_Ins_Break.addOnClicked(delegate void(ToolButton tb)
		{
		    //THIS SHOULD PULL UP A BREAKPOINT (AND MAYBE WATCHPOINT)
		    //CREATION DIALOG
		    //OR...
		    //BREAKS AND WATCHES WILL BE ADDED ELSEWHERE
		    //AND OPENS AN EDIT BREAKPOINT DIALOG
		    //DON'T GO ANYWHERE I'LL BE RIGHT BACK
		});
        mBtn_Remove_Break.addOnClicked(delegate void(ToolButton tb)
		{
			auto ti = mBreaksView.getSelectedIter();
			if(ti is null) return;
			auto doc = DocMan.GetDoc(ti.getValueString(12));
		        if(doc !is null)ToggleBreakPoint(doc, ti.getValueString(11).to!int-1);
			    
			//mNtdb.RemoveBreak(ti.getValueString(0));
		});
        
        mTglBreakEnabled.addOnToggled(delegate void(string path, CellRendererToggle crt)
	{

		TreeIter ti = new TreeIter(mBreaksStore, path);
		auto enabled = new Value;
		ti.getValue(3, enabled);
		auto id = ti.getValueString(0);
		crt.setActive(!enabled.getBoolean());			
		if(!enabled.getBoolean())
		{
			mNtdb.EnableBreak(id);
			enabled.setBoolean(true);
			mBreaksStore.setValue(ti, 3, enabled.getBoolean());
		}
		else
		{
			mNtdb.DisableBreak(id);
			enabled.setBoolean(false);
			mBreaksStore.setValue(ti, 3, enabled.getBoolean());
		}
	});
        
        mFramesView.addOnRowActivated(delegate void(TreePath tp, TreeViewColumn tvc, TreeView self)
        {
            TreeIter ti = new TreeIter;
            mFramesStore.getIter(ti, tp);
            if(ti is null) return;
            mNtdb.CreateVariables(ti.getValueString(0)); 
            if(ti.getValueString(2) == "-") return;
            GotoExecPoint(ti.getValueString(2), ti.getValueString(3).to!int -1 );
        });
        
        mInScopeView.addOnQueryTooltip(&QueryTip);
        
        mTerminalWindow.addOnDelete(delegate bool(Event e, Widget w)
        {
            return true;
        });
        mTerminalWindow.setVisible(false);
        
        //set watchpoint action
        AddIcon("watchpoint_icon",SystemPath(Config.GetValue("debug_ui", "watchpoint-icon", "elements/resources/target.png")));
        AddAction("ActWatchpoint",
                  "Add Watchpoint",
                  "Set a watchpoint on a variable",
                  "watchpoint_icon",
                  "<Control>B",
                  &AddWatchpointCB);
        uiContextMenu.AddAction("ActWatchpoint");
        
        DocMan.GutterActivated.connect(&ToggleBreakPoint);
        
        DocMan.Tooltip.connect(&DocTooltip);
        
        AddSidePage(mSideRoot, "Variables");
        AddExtraPage(mExtraRoot, "Debugger");
        
        Log.Entry("Engaged");
    }
    
    void Disengage()
    {
        Config.SetValue("debug_ui", "extra_pane_pos", mExtraPane.getPosition());
        Config.SetValue("debug_ui", "side_pane_pos", mSidePane.getPosition());
        
        int xlen, ylen;
        mTerminalWindow.getSize(xlen, ylen);
        Config.SetValue("debug_ui", "x_len", xlen);
        Config.SetValue("debug_ui", "y_len", ylen);
        
        uiContextMenu.RemoveAction("ActWatchpoint");
        RemoveAction("ActWatchpoint");
                
        DocMan.Tooltip.disconnect(&DocTooltip);
        DocMan.GutterActivated.disconnect(&ToggleBreakPoint);
        
        RemoveSidePage(mSideRoot);
        RemoveExtraPage(mExtraRoot);
        destroy(mTerminalWindow);
        destroy(mTerminal);
        destroy(mNtdb);
        Log.Entry("Disengaged");
    }
    void Configure()
    {
    }
    string Name()       {return "Debugger UI";}
    string Info()       {return "UI for dcomposer's GDB interface. (Fingers crossed it works :)";}
    string Version()    {return "00.01";}
    string License()    {return "MIT";}
    string CopyRight()  {return "Anthony Goins © 2016";}
    string[] Authors()  {return ["Anthony Goins <neontotem@gmail.com>"];}

    PREFERENCE_PAGE PreferencePage()
    {
        //need to know where/which gdb to run
        //maybe max depth
        return null;
    }
    
    private:
    
    NTDB                mNtdb;
    
    Box                 mSideRoot;
    Paned               mSidePane;
    
    TreeView            mInScopeView;
    TreeStore           mInScopeStore;
    
    TreeView            mOutScopeView;
    TreeStore           mOutScopeStore;
    
    
    Box                 mExtraRoot;
    Paned               mExtraPane;
    
    ToolButton          mBtn_Start;
    ToolButton          mBtn_Continue;
    ToolButton          mBtn_Step_Over;
    ToolButton          mBtn_Step_In;
    ToolButton          mBtn_Step_Out;
    ToolButton          mBtn_To_Cursor;
    ToolButton          mBtn_Interrupt;
    ToggleToolButton    mBtn_SwitchGdb;
    
    ToolButton          mBtn_Ins_Break;
    ToolButton          mBtn_Remove_Break;
    CellRendererToggle  mTglBreakEnabled;
    
    TreeView            mFramesView;
    ListStore           mFramesStore;
    
    Box                 mBreakBox;
    TreeView            mBreaksView;
    ListStore           mBreaksStore;
    
    TextView            mTextView;
    
    Window              mTerminalWindow;
    Terminal            mTerminal;
    
    string              mPts;
    int                 mTerminalFd;
    
    SourceMark          mExecPoint;
    
    string              mNextUniqName = "0";
    
    DOC_IF              mTooltipDoc;
    string              mTooltipExpr;
    
    string srcUniqName()
    {
        auto rv = mNextUniqName;
        mNextUniqName = rv.succ;
        return rv;
    }
        
    
    bool StartNtdb(string Target)
    {
        mNtdb = new NTDB;
        mNtdb.connect(&DebugWatcher);
        
        mTerminal = new Terminal;
        mTerminal.setInputEnabled(true);
        mTerminal.setVisible(true);
        mTerminal.setPty(mTerminal.ptyNewSync(VtePtyFlags.DEFAULT, null));
        mTerminalFd = mTerminal.getPty().getFd();
        
        import core.sys.posix.stdlib;
        mPts = ptsname(mTerminalFd).to!string;
       	dwrite("StartNtdb ", mPts); 
        mTerminalWindow.add(mTerminal);
        
                
        bool rewrap = Config.GetValue("debug_ui", "rewrap", true);
        int xlen = Config.GetValue("debug_ui","x_len", 180);
        int ylen = Config.GetValue("debug_ui","y_len", 130);
        
        mTerminal.setRewrapOnResize(rewrap);
	int child_pid;
	
        
        mTerminalWindow.resize(xlen, ylen);
         mTerminal.spawnSync( VtePtyFlags.DEFAULT,
                            getcwd(),
                            ["/usr/bin/bash"],
                            [],
                            GSpawnFlags.DEFAULT,
                            null,
			    null,
                            child_pid,
                            null);

        //mTerminalWindow.setVisible(true);
	mTerminalWindow.showAll(); 
        return mNtdb.StartGdb(Target, mPts);
    }
    
    void ResetPty()
    {
        //mTerminal.setPty(mTerminal.ptyNewSync(VtePtyFlags.DEFAULT, null));
        mTerminalFd = mTerminal.getPty().getFd();
        import core.sys.posix.stdlib;
        mPts = ptsname(mTerminal.getPty().getFd()).to!string;
	dwrite("reset ",mPts);
        mNtdb.SetTty(mPts);
    }
    
    
    void StopNtdb()
    {
	if(mNtdb is null) return;
        mNtdb.StopGdb();
	if(mTerminal)
	{
		mTerminalWindow.remove(mTerminal);
		mTerminal.destroy();
	}
        mNtdb.disconnect(&DebugWatcher);
        mNtdb = null;
    }
    
    void GotoExecPoint(string source_file, int zline)
    {
        if(mExecPoint !is null)
        {
            auto buff = mExecPoint.getBuffer();
            if(buff !is null)buff.deleteMarkByName("ExecPt");
        }
        if(DocMan.GoTo(source_file, zline))
        {
            auto ti = new TextIter;
            auto doc = cast(DOCUMENT)DocMan.Current();
            if(doc is null) return;
            doc.getBuffer().getIterAtLine(ti,zline);
            mExecPoint = doc.getBuffer().createSourceMark("ExecPt", "ExecPoint", ti);
        }
    }
    

    void ToggleBreakPoint(DOC_IF doc, int zline)
    {
        if(!mBtn_SwitchGdb.getActive()) return;
        auto DOC = cast(DOCUMENT) doc;
        auto buff = DOC.getBuffer();
        auto marklist =  buff.getSourceMarksAtLine(zline, "Breakpoint");
        if(marklist)
        {
            DOC.getBuffer().deleteMark(marklist.toArray!SourceMark[0]);
            auto id = FindBreakID(doc.Name.baseName(), (1+zline).to!string);
            mNtdb.RemoveBreak(id);
        }
        else
        {
            auto ti = new TextIter;
            DOC.getBuffer().getIterAtLine(ti, zline);
            DOC.getBuffer().createSourceMark(srcUniqName, "Breakpoint", ti);
            mNtdb.InsertBreak(DOC.Name ~ ":" ~ (zline+1).to!string);
        }
    }
    
    void AddWatchpointCB(Action a)
    {
        auto doc = DocMan.Current();
        if(doc is null) return;
        auto symbol = doc.Word();
        mNtdb.InsertWatch(symbol);
    }
    
    void ResetUI()
    {
        mFramesStore.clear();
        mInScopeStore.clear();
        mOutScopeStore.clear();
        mTextView.getBuffer().setText("\0");
    }

    void ToggleGdb(ToggleToolButton tb)
    {
        auto starting = mBtn_SwitchGdb.getActive();

        if(starting)
        {
            string TargetFile;
            //project functions are retarded need a "getExecutable"
            //should return -of arg or name and ensure it is runnable
            //for now lets just use project name and failing that try
            //to run current doc

            if(Project.TargetType == TARGET.APPLICATION)
                TargetFile = Project.getExecutable();
            else
            {
                auto doc = DocMan.Current();
                if(doc !is null) TargetFile = doc.Name.stripExtension();
            }
            if (!TargetFile.exists())
            {
                ShowMessage("Debugger", "No Target for debugging[n" ~ TargetFile);
                mBtn_SwitchGdb.setActive(false);
                Log.Entry("Failed to Start Debugger... " ~ TargetFile ~ " does not exist");
                return;
            }                                    
            if(!StartNtdb(TargetFile))
            {
                mBtn_SwitchGdb.setActive(false);
                Log.Entry("Failed to Start Debugger","Error");
                return;                  
            }
            AddStatus("debugger", "Debug session started. Target: " ~ TargetFile);
        }
        else
        {
            StopNtdb();
            AddStatus("debugger", "Debug session ended.");
        }						
        mBtn_Start.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Continue.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Step_Over.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Step_In.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Step_Out.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_To_Cursor.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Interrupt.setSensitive(mBtn_SwitchGdb.getActive());
        mBreakBox.setSensitive(mBtn_SwitchGdb.getActive());
        mFramesView.setSensitive(mBtn_SwitchGdb.getActive());
        if(!mBtn_SwitchGdb.getActive())mFramesStore.clear();
        mTerminalWindow.setVisible(mBtn_SwitchGdb.getActive());
       
    }

    void DebugWatcher(RECORD rec)
    {
        auto tmpstring = Cooked(rec._rawString);
	dwrite(tmpstring);

        switch(rec._class)
        {
            case "*stopped":
                mTextView.appendText("\n" ~ tmpstring);
                mNtdb.GetStackList();
                AddStatus("Debugger", "Debug target stopped " ~ rec.Get("reason"));
                if(rec.Get("reason").startsWith("exit"))
                {
                    string statusStr = "Debug target exited : " ~ rec.Get("exit-code");
                    AddStatus("Debugger", statusStr);
                }
                if((rec.Get("reason") == "breakpoint-hit") || (rec.Get("reason") == "watchpoint-trigger"))
                {
                    mNtdb.GetBreakPoints();
                }
                if(rec.GetResult("frame"))
                {
                    scope(failure)
                    {
                        goto case;
                    }                    
                    string file = rec.Get("frame", "fullname");
                    int zline = (rec.Get("frame", "line").to!int)-1;
                    GotoExecPoint(file, zline);
                }
                break;
            case "^done":
                if(rec.GetResult("stack"))UpdateFramesView(rec);
                if(rec.GetResult("BreakpointTable"))UpdateBreakView(rec);
                if(rec.GetResult("noevaldata"))
                {
                    if(mTooltipDoc)
                    {
                        auto doc = cast(Widget)mTooltipDoc;
                        doc.setTooltipText(mTooltipExpr ~ " : no data");
                        mTooltipDoc = null;
                        break;
                    }
                    UpdateTooltip(rec);
                    break;
                }
                if(rec.GetResult("value"))
                {                    
                    if(mTooltipDoc)
                    {
                        auto doc = cast(Widget)mTooltipDoc;
                        doc.setTooltipText(mTooltipExpr ~ " : " ~ rec.Get("value").Cooked);
                        mTooltipDoc = null;
                        break;
                    }
                    UpdateTooltip(rec);
                    break;
                }
                break;
            case "^running":
                mTextView.appendText("\n"~tmpstring);
                AddStatus("Debugger", "Debug target running");
                break;
            case "$updatevariables":
                UpdateVariables();
                break;
            default:
        }
    }
    
    void UpdateVariables()
    {
        TreeIter RootTi;
        
        auto allvariables = mNtdb.GetVariables();
        
        void BuildChild(TreeIter Parent, VARIABLE child, TreeStore ts)
		{
			auto ti = ts.append(Parent);
			
			ts.setValue(ti, 0, child._name);
			ts.setValue(ti, 1, child._value);
			ts.setValue(ti, 2, child._type);
			ts.setValue(ti, 3, child._in_scope);
			ts.setValue(ti, 4, child._color);
            ts.setValue(ti, 5, child._exp);
			
			foreach(gran; child._children) BuildChild(ti, gran, ts);
			
		}       
        
        mOutScopeStore.clear();
        mInScopeStore.clear();
        
        foreach(var; allvariables)
        {
             TreeStore tmp;
            
            if(var._in_scope != "false") 
            {
                tmp = mInScopeStore;
            }
            else
            {
                tmp = mOutScopeStore;
            }
            
            RootTi = tmp.append(null);
            
            tmp.setValue(RootTi, 0, var._name);
            tmp.setValue(RootTi, 1, var._value);
            tmp.setValue(RootTi, 2, var._type);
            tmp.setValue(RootTi, 3, var._in_scope);
            tmp.setValue(RootTi, 4, var._color); //should be in ui only
            tmp.setValue(RootTi, 5, var._exp);
            foreach(kid; var._children) BuildChild(RootTi,kid, tmp);
        }        
    }
    
    void UpdateFramesView(RECORD frames)
    {
		TreeIter ti;
		
		mFramesStore.clear();
        
		foreach(frame; frames.GetResult("stack"))
		{			
			mFramesStore.append(ti);
			auto levelstr = ("level" in frame._tuple) ? frame._tuple["level"]._const : "-";			
			auto fromstr = ("from" in frame._tuple) ? frame._tuple["from"]._const : "-";
			auto addrstr = ("addr" in frame._tuple) ? frame._tuple["addr"]._const : "-";
			auto funcstr = ("func" in frame._tuple) ? frame._tuple["func"]._const : fromstr;
			auto filestr = ("file" in frame._tuple) ? frame._tuple["file"]._const : "-";								
			auto linestr = ("line" in frame._tuple) ? frame._tuple["line"]._const : "-";
			
			funcstr = demangle(funcstr).idup;
						
			mFramesStore.setValue(ti, 0, levelstr);
			mFramesStore.setValue(ti, 1, addrstr);
			mFramesStore.setValue(ti, 2, filestr);
			mFramesStore.setValue(ti, 3, linestr);
			mFramesStore.setValue(ti, 4, funcstr);
		}
        mNtdb.CreateVariables("0");
	}
    
    void UpdateBreakView(RECORD break_rec)
	{
		TreeIter ti;
		mBreaksStore.clear();
				
		//foreach(breakpt; break_rec._values["BreakpointTable"]._tuple["body"]._list._values)
		foreach(breakpt; break_rec.GetValue("BreakpointTable", "body"))
        {
			if(!breakpt)break;
			//auto id = ("number" in breakpt._tuple) ? breakpt._tuple["number"]._const : "-";
			auto id = ("number" in breakpt._tuple) ? breakpt.Get("number")._const : "-";
			auto type = ("type" in breakpt._tuple) ? breakpt.GetString("type") : "-";
			auto disp = ("disp" in breakpt._tuple) ? breakpt.GetString("disp") : "-";
			auto enabled = ("enabled" in breakpt._tuple) ? (breakpt.GetString("enabled") == "y") : false;
            auto source = ("file" in breakpt._tuple) ? breakpt.GetString("file") : "-";
			auto cond = ("cond" in breakpt._tuple) ? breakpt.GetString("cond") : "?";
			auto ignore = ("ignore" in breakpt._tuple) ? breakpt.GetString("ignore") : "-";
			auto times = ("times" in breakpt._tuple) ? breakpt.GetString("times") : "?";
			auto what = ("what" in breakpt._tuple) ? breakpt.GetString("what") : "-";
            auto funct = ("func" in breakpt._tuple) ? breakpt.GetString("func").demangle().to!string : "-";
            auto line = ("line" in breakpt._tuple) ? breakpt.GetString("line") : "-" ;
            auto fullname = ("fullname" in breakpt._tuple) ? breakpt.GetString("fullname") : "-";
			if("pending" in breakpt._tuple) funct = breakpt.GetString("pending");
            
			Value enabledbool = new Value;
			enabledbool.init(GType.BOOLEAN);
			enabledbool.setBoolean(enabled);
			
			mBreaksStore.append(ti);
			mBreaksStore.setValue(ti, 0, id);
			mBreaksStore.setValue(ti, 1, type);
			mBreaksStore.setValue(ti, 2, disp);
			mBreaksStore.setValue(ti, 3, enabledbool);
			mBreaksStore.setValue(ti, 4, source);
			mBreaksStore.setValue(ti, 5, cond);
			mBreaksStore.setValue(ti, 6, ignore);
			mBreaksStore.setValue(ti, 7, times);
			mBreaksStore.setValue(ti, 8, what);
            mBreaksStore.setValue(ti, 10,funct);
            mBreaksStore.setValue(ti, 11,line);
            mBreaksStore.setValue(ti, 12,fullname);
		}
	}
    
    void UpdateTooltip(RECORD val)
    {
        auto tip = val.Get("value");
        mInScopeView.setTooltipText(tip.Cooked());       
    }
    
    bool QueryTip(int x, int y, bool keys, Tooltip tooltip, Widget w)
    {
        auto tvc = new TreeViewColumn;
        auto tp = new TreePath;
        auto ti = new TreeIter;
        int tvx, tvy, cx, cy;
        auto tv = cast(TreeView)w;
        tv.convertWidgetToBinWindowCoords(x, y, tvx, tvy);
        if(tv.getPathAtPos(tvx,tvy,tp, tvc, cx, cy))
        {
            tv.getModel().getIter(ti, tp);
            auto exp = ti.getValueString(0);
            mNtdb.EvaluateData(exp);
        }
        return false;
    }
    
    string FindBreakID(string name, string line)
    {
        auto ti = new TreeIter;
        if(!mBreaksStore.getIterFirst(ti))return "-";
        do
        {
            if((name == mBreaksStore.getValueString(ti, 4)) 
                &&
               (line == mBreaksStore.getValueString(ti,11)))
            {
                return mBreaksStore.getValueString(ti, 0);
            }
        }while (mBreaksStore.iterNext(ti));
        return "-";
    }
    
    
    void DocTooltip(DOC_IF doc, string word)
    {
        if(mBtn_SwitchGdb.getActive() == false)return;
        if(word.length < 1)
        {
            mTooltipDoc = null;
            (cast(Widget)(doc)).setTooltipText(null);
            (cast(Widget)(doc)).setHasTooltip(true);
            return;
        }
        mTooltipDoc = doc;
        mTooltipExpr = word;
        mNtdb.EvaluateData(word);
    }
    
    
}


string Cooked(string raw)
{
	import std.string;
    import std.utf;
    
	string rv = "";
	if(raw.startsWith("(gdb)")) return rv;
	if(raw == `&"\n"`) return rv;
	rv = raw.replace(`\n`, "");
    rv = rv.replace(`\\`, `\`);
	rv = rv.replace(`\"`, `"`);
	
	return rv.toUTF8;
}
