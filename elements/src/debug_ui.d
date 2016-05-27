module debug_ui;

import std.traits;
import std.file;
import std.string;
import core.demangle;

import dcore;
import ui;
import elements;

extern (C) string GetClassName()
{
    return fullyQualifiedName!DEBUG_UI;
}


class DEBUG_UI : ELEMENT
{
    public:
    
    void Engage()
    {
        mNtdb = new NTDB;
        
        auto builder = new Builder(SystemPath(Config.GetValue("debug_ui", "glade_file", "elements/resources/debug_ui.glade")));
        
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
        
        mBreaksView     = cast(TreeView)builder.getObject("treeview4");
        mBreaksStore    = cast(ListStore)builder.getObject("liststore3");
                
        mBtn_Ins_Break  = cast(ToolButton)builder.getObject("toolbutton9");
        mBtn_Remove_Break=cast(ToolButton)builder.getObject("toolbutton10");
        
        mTglBreakEnabled = cast(CellRendererToggle)builder.getObject("cellrenderertoggle1");
        
        mTextView       = cast(TextView)builder.getObject("textview1");
        
        mBtn_SwitchGdb.addOnToggled(&ToggleGdb);
        
		mBtn_Start.addOnClicked(delegate void(ToolButton tb){mNtdb.StartTarget();});
		mBtn_Continue.addOnClicked(delegate void(ToolButton tb){mNtdb.ContinueTarget();});
		mBtn_Step_Over.addOnClicked(delegate void(ToolButton tb){mNtdb.StepOver();});
		mBtn_Step_In.addOnClicked(delegate void(ToolButton tb){mNtdb.StepIn();});
		mBtn_Step_Out.addOnClicked(delegate void(ToolButton tb){mNtdb.StepOut();});
		mBtn_To_Cursor.addOnClicked(delegate void(ToolButton tb)
        {
            string name;
            int line,col;
            if(DocMan.Current is null) return;
            mNtdb.ToCursor(DocMan.Current.GetLocation(name, line, col));
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
			mNtdb.RemoveBreak(ti.getValueString(0));
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
        });
        
        AddSidePage(mSideRoot, "Variables");
        AddExtraPage(mExtraRoot, "Debugger");
        
        mNtdb.connect(&DebugWatcher);
        
        Log.Entry("Engaged");
    }
    
    void Disengage()
    {
        mNtdb.StopGdb();
        mNtdb.disconnect(&DebugWatcher);
        
        RemoveSidePage(mSideRoot);
        RemoveExtraPage(mExtraRoot);
        destroy(mNtdb);
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
    
    TreeView            mBreaksView;
    ListStore           mBreaksStore;
    
    TextView            mTextView;
    
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
                TargetFile = Project.Name;
            else
            {
                auto doc = DocMan.Current();
                if(doc !is null) TargetFile = doc.Name;
            }
            if (!TargetFile.exists())
            {
                ShowMessage("Debugger", "No Target for debugging");
                mBtn_SwitchGdb.setActive(false);
                Log.Entry("Failed to Start Debugger... " ~ TargetFile ~ " does not exist");
                return;
            }                                    
            if(!mNtdb.StartGdb(TargetFile))
            {
                mBtn_SwitchGdb.setActive(false);
                Log.Entry("Failed to Start Debugger","Error");
                return;                  
            }
            AddStatus("debugger", "Debug session started. Target: " ~ TargetFile);
        }
        else
        {
            mNtdb.StopGdb();
            AddStatus("debugger", "Debug session ended.");
        }						
        mBtn_Start.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Continue.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Step_Over.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Step_In.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Step_Out.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_To_Cursor.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Interrupt.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Ins_Break.setSensitive(mBtn_SwitchGdb.getActive());
        mBtn_Remove_Break.setSensitive(mBtn_SwitchGdb.getActive());
        mFramesView.setSensitive(mBtn_SwitchGdb.getActive());
        if(!mBtn_SwitchGdb.getActive())mFramesStore.clear();
    }

    void DebugWatcher(RECORD rec)
    {
        auto tmpstring = Cooked(rec._rawString);
        if(tmpstring.length)mTextView.appendText(tmpstring);
        //UpdateVariables(); // this is called way too often!! prune it down
        
        switch(rec._class)
        {
            case "*stopped":
                mNtdb.GetStackList();
                AddStatus("Debugger", "Debug target stopped");
                if(rec.Get("reason").startsWith("exited"))AddStatus("Debugger", "Debut target exited");
                break;
            case "^done":
                if(rec.GetResult("stack"))UpdateFramesView(rec);
                if(rec.GetResult("BreakpointTable"))UpdateBreakView(rec);
                break;
            case "^running":
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
			auto cond = ("cond" in breakpt._tuple) ? breakpt.GetString("cond") : "?";
			auto ignore = ("ignore" in breakpt._tuple) ? breakpt.GetString("ignore") : "-";
			auto times = ("times" in breakpt._tuple) ? breakpt.GetString("times") : "?";
			auto what = ("what" in breakpt._tuple) ? breakpt.GetString("what") : "-";
			//auto location = ("location" in breakpt._tuple) ? breakpt._tuple["id"]._const : "-";
			string location;
			if("pending" in breakpt._tuple) location = breakpt._tuple["pending"]._const;
			if("func" in breakpt._tuple) location ~= breakpt._tuple["func"]._const.demangle() ~ " ";
			if("filename" in breakpt._tuple) location ~= breakpt._tuple["filename"]._const;
			if("line" in breakpt._tuple) location ~= ":" ~ breakpt._tuple["line"]._const;
			
			
			Value enabledbool = new Value;
			enabledbool.init(GType.BOOLEAN);
			enabledbool.setBoolean(enabled);
			
			mBreaksStore.append(ti);
			mBreaksStore.setValue(ti, 0, id);
			mBreaksStore.setValue(ti, 1, type);
			mBreaksStore.setValue(ti, 2, disp);
			mBreaksStore.setValue(ti, 3, enabledbool);
			mBreaksStore.setValue(ti, 4, location);
			mBreaksStore.setValue(ti, 5, cond);
			mBreaksStore.setValue(ti, 6, ignore);
			mBreaksStore.setValue(ti, 7, times);
			mBreaksStore.setValue(ti, 8, what);
		}
	}
        
    
}


string Cooked(string raw)
{
	import std.string;
	string rv = "\0";
	if(raw.startsWith("(gdb)")) return rv;
	if(raw == `&"\n"`) return rv;
	rv = raw.replace(`\n`, "");
	rv = rv.replace(`\"`, `"`) ~ "\n";
	
	return rv;
}
