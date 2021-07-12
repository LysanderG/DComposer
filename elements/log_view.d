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
    
    
    void WatchLog(string msg, string level, string mod)
    {
        TreeIter ti = new TreeIter();
        mStore.append(ti);
        mStore.setValue(ti, 0, level);
        mStore.setValue(ti, 1, mod);
        mStore.setValue(ti, 2, msg);
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
        tvcModule.setResizable(false);        
        tvcMessage.setResizable(true);
        /*TreeIter ti = new TreeIter();
        mStore.append(ti);
        mStore.setValue(ti, 0, "one");
        mStore.setValue(ti, 1, "two");
        mStore.setValue(ti, 2, "three");*/
        mTree.setModel(mStore);

        mRootScroll.add(mTree);
        mRootScroll.showAll();
        AddExtraPane(mRootScroll, "Log View");
        
        Log.connect(&WatchLog);
    }
    
    void Mesh(){}
    void Disengage()
    {
        Log.disconnect(&WatchLog);
        RemoveExtraPaneWidget(mRootScroll);   
    }
    

    void Configure(){}

    string Name(){return "Log View".idup;}
    string Info(){return "shows log output".idup;}
    string Version(){return "0.00".idup;}
    string License(){return "to be determined".idup;}
    string CopyRight(){return "2021 Anthony Goins".idup;}
    string Authors(){return "Lysander".idup;}

    Dialog SettingsDialog()
    {
        return new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.OTHER, ButtonsType.CLOSE, "Hey this is working");
    }
}
