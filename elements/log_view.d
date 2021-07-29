module log_view;


import qore;
import ui;
import elements;

extern(C) string GetElementName()
{
    return "log_view.LOG_VIEW";
}


class LOG_VIEW : ELEMENT
{
    private:
    
    ScrolledWindow      mRootScroll;
    TreeView            mTree;
    ListStore           mStore;
    Dialog              mPreferencesDialog;
    
    void WatchLog(string msg, string level, string mod)
    {
        TreeIter ti = new TreeIter();
        mStore.append(ti);
        mStore.setValue(ti, 0, level);
        mStore.setValue(ti, 1, mod);
        mStore.setValue(ti, 2, msg);
        
        auto path = mStore.getPath(ti);
        mTree.setCursor(path, null, false);
    } 
    
    
    public:
    void Engage()
    {
        mRootScroll = new ScrolledWindow();
        mTree = new TreeView();
        mStore = new ListStore([GType.STRING, GType.STRING, GType.STRING]);
        
        TreeViewColumn tvcLevel = new TreeViewColumn("Level", new CellRendererText(), "markup", 0);
        TreeViewColumn tvcModule = new TreeViewColumn("Module", new CellRendererText(), "markup", 1);        
        TreeViewColumn tvcMessage = new TreeViewColumn("Message", new CellRendererText(), "markup", 2);
        mTree.appendColumn(tvcLevel);
        mTree.appendColumn(tvcModule);
        mTree.appendColumn(tvcMessage);
        
        tvcLevel.setResizable(false);
        tvcModule.setResizable(true);        
        tvcMessage.setResizable(true);
        mTree.setModel(mStore);

        mRootScroll.add(mTree);
        mRootScroll.showAll();
        AddExtraPane(mRootScroll, "Log View");        
        Log.connect(&WatchLog);
        
        
        mPreferencesDialog = new Dialog("Log_View Element Preferences",mMainWindow, DialogFlags.MODAL,["Finished"], [ResponseType.CLOSE]);
        Box box = mPreferencesDialog.getContentArea();        
        FontButton fontbtn = new FontButton();
        box.add(fontbtn);
        box.showAll();  
        fontbtn.addOnFontSet(delegate void(FontButton fb)
        {
            Config.SetValue("element", "log_view_font", fb.getFont().idup);
            Configure();
        });
        Configure();
        
        Log.Entry("Engaged");
        
    }
    
    void Mesh()
    {
        Log.Entry("Meshed");
    }
    void Disengage()
    {
        destroy(mPreferencesDialog);
        Log.disconnect(&WatchLog);
        RemoveExtraPaneWidget(mRootScroll);  
        Log.Entry("Disengaged"); 
    }
    

    void Configure()
    {
        string cfgstr = Config.GetValue!string("element", "log_view_font","monospace 8".idup);
        mTree.modifyFont(PgFontDescription.fromString(cfgstr));
    }

    string Name(){return "Log View".idup;}
    string Info(){return "shows log output".idup;}
    string Version(){return "0.00".idup;}
    string License(){return "to be determined".idup;}
    string CopyRight(){return "2021 Anthony Goins".idup;}
    string Authors(){return "Lysander".idup;}

    Dialog SettingsDialog()
    {
        return mPreferencesDialog;
    }
}
