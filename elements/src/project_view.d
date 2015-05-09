module project_view;

import std.path;
import std.conv;
import std.stdio;
import std.algorithm;


import elements;
import ui;
import dcore;
import ui_preferences;

//import gtk.Builder;
//import gtk.Label;
//import gtk.TreeView;
//import gtk.TreeIter;
//import gtk.ComboBox;
//import gtk.Toolbar;
//import gtk.ListStore;
//import gtk.TreePath;
//import gtk.TreeViewColumn;
//import gtk.ToolButton;
//import gtk.FileChooserDialog;
//import gtk.CellRendererText;
//import gtk.Viewport;
//import gtk.Frame;
//import gtk.CheckButton;
//import gtk.Widget;
//
//import gobject.Value;



extern (C) string GetClassName()
{
    return "project_view.PROJECT_VIEW";
}

class PROJECT_VIEW : ELEMENT
{
    private:

    Builder         mBuilding;
    Box             mRoot;

    Label           mLabel;
    Toolbar         mToolBar;
    ComboBox        mKeyBox;

    TreeView            mListView;
    CellRendererText    mCellText;
    TreeViewColumn      mTVC;
    CellRendererText    mCRT;
    ListStore           mViewStore;
    ListStore           mComboStore;

    ToolButton          mAdd;
    ToolButton          mRemove;

    TreeIter            mAddedIdentifierTI;


    void UpdateList(ComboBox X)
    {
        TreeIter ti = new TreeIter;
        if (!X.getActiveIter(ti)) return;

        string key = mComboStore.getValueString(ti, 0);

        if( (key == LIST_NAMES.VERSIONS ) || (key == LIST_NAMES.DEBUGS)  || (key == "DESCRIPTION") || (key == LIST_NAMES.OTHER))
        {
            mCellText.setProperty("mode", CellRendererMode.EDITABLE);
            mCellText.setProperty("editable",true);
        }
        else
        {
            mCellText.setProperty("editable", false);
            mCellText.setProperty("mode",CellRendererMode.ACTIVATABLE);
        }

        Value x = new Value(GType.INT);
        mCellText.getProperty("mode", x);

        dwrite(key);
        auto values = Project.Lists[key];

        mViewStore.clear();

        ti = new TreeIter;
        foreach(val; values)
        {
            mViewStore.append(ti);
            mViewStore.setValue(ti, 0, baseName(val));
            mViewStore.setValue(ti, 1, val);

        }

    }

    void UpdateList(string key, string[] Values)
    {

        if( (key == LIST_NAMES.VERSIONS ) || (key == LIST_NAMES.DEBUGS) || (key == LIST_NAMES.NOTES) || (key == LIST_NAMES.OTHER) )
        {
            mCellText.setProperty("mode", CellRendererMode.EDITABLE);
            mCellText.setProperty("editable",true);
        }
        else
        {
            mCellText.setProperty("editable", false);
            mCellText.setProperty("mode",CellRendererMode.ACTIVATABLE);
        }

        Value x = new Value(GType.INT);
        mCellText.getProperty("mode", x);

        TreeIter ti = new TreeIter;
        if(mKeyBox.getActiveIter(ti))
        {
            string currentKey = mComboStore.getValueString(ti,0);
            if(key == currentKey)
            {
                mViewStore.clear();
                foreach(item; Values)
                {
                    dwrite(item);
                    mViewStore.append(ti);
                    mViewStore.setValue(ti, 0, baseName(item));
                    mViewStore.setValue(ti, 1, item);
                }
            }
        }
        return;
    }

    void UpdateName(string nuName)
    {
        mLabel.setText(nuName);
    }

    void OpenFile(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        int CurKey = mKeyBox.getActive();

        if((CurKey == 0) || (CurKey == 1))
        {

            auto ti = tv.getSelectedIter();
            string Filename = ti.getValueString(1);
            dwrite(buildPath(Project.Folder, Filename));
            DocMan.Open([buildPath(Project.Folder, Filename)]);
        }
    }

    void UpdateProject(PROJECT_EVENT EventType)
    {
        switch (EventType)
        {

            case PROJECT_EVENT.OPENED           :
                                                {
                                                    UpdateList(mKeyBox);
                                                    mLabel.setText(Project.Name);
                                                    mSidePane.setCurrentPage(mRoot);
                                                    break;
                                                }
            case PROJECT_EVENT.CREATED          :
                                                {
                                                    mSidePane.setCurrentPage(mRoot);
                                                    break;
                                                }
            case PROJECT_EVENT.LISTS            :
                                                {
                                                    UpdateList(mKeyBox);
                                                    mLabel.setText(Project.Name);
                                                    break;
                                                }
            case PROJECT_EVENT.NAME             :
                                                {
                                                    mLabel.setText(Project.Name);
                                                    break;
                                                }
            default : break;

        }
        return;

        //if(EventType == "ListChange")UpdateList(mKeyBox);
        //if(EventType == "Name")mLabel.setText(Project.Name);
        //if(EventType == "Opened")
        //{
        //    UpdateList(mKeyBox);
        //    mLabel.setText(Project.Name);
        //    dui.GetSidePane.setCurrentPage(mRoot);
        //}
        //if(EventType == "Close")
        //{
        //    UpdateList(mKeyBox);
        //    mLabel.setText("No Project Loaded");
        //}
        //if(EventType == "New")
        //{
        //    dui.GetSidePane.setCurrentPage(mRoot);
        //}

    }
    void AppendToolItems()
    {

        auto tmp = GetAction("ActProjNew");
        mToolBar.insert(tmp.createToolItem());
        tmp = GetAction("ActProjOpen");
        mToolBar.insert(tmp.createToolItem());
        tmp = GetAction("ActProjSave");
        mToolBar.insert(tmp.createToolItem());
        tmp = GetAction("ActProjEdit"    );
        mToolBar.insert(tmp.createToolItem());
        tmp = GetAction("ActProjBuild"  );
        mToolBar.insert(tmp.createToolItem());
        tmp = GetAction("ActProjRun"    );
        mToolBar.insert(tmp.createToolItem());
        tmp = GetAction("ActProjRunArgs");
        mToolBar.insert(tmp.createToolItem());
    }

    void Add(ToolButton x)
    {
        //Log.Entry("proview.Add");
        string CurrentKey;
        TreeIter ti = new TreeIter;
        if(mKeyBox.getActiveIter(ti))
        {
            CurrentKey = mComboStore.getValueString(ti,0);
        }
        else return;
        //yes yes I am aware that this is not an exactly "robust" way to handle the situation.
        switch (CurrentKey) with (LIST_NAMES)
        {
            case SRC_FILES      :
            case REL_FILES      :
            case LIBRARIES      : AddAFile(CurrentKey); break;
            case IMPORT         :
            case STRING         :
            case LIBRARY_PATHS  : AddAPath(CurrentKey); break;
            default : AddAnIdentifier(CurrentKey);

        }
        return;
    }

    void Remove(ToolButton x)
    {
        TreeIter ti = new TreeIter;
        string CurrentKey;

        if(mKeyBox.getActiveIter(ti))
        {
            CurrentKey = mComboStore.getValueString(ti,0);
        }
        else return;

        ti = mListView.getSelectedIter();

        Project.DeleteListItem(CurrentKey, mViewStore.getValueString(ti,1));
    }


    void AddAFile(string CurrentKey)
    {
        auto FileDialog = new FileChooserDialog("Select Files", MainWindow, FileChooserAction.OPEN);
        scope(exit)FileDialog.destroy();
        FileDialog.setSelectMultiple(true);
        FileDialog.setCurrentFolder(Project.Folder);

        auto DialogResponse = FileDialog.run();
        FileDialog.hide();

        if(DialogResponse != ResponseType.OK)return;

        string afile;
        TreeIter ti = new TreeIter;

        auto SelFiles = FileDialog.getFilenames();
        while(SelFiles !is null)
        {
            afile = toImpl!(string, char *)(cast(char *)SelFiles.data());
            auto afileAbsPath = afile.absolutePath();
            auto projectAbsPath = Project.Folder.absolutePath();

            if(afileAbsPath.startsWith(projectAbsPath))afile = afile.relativePath(projectAbsPath);
            //else afile = afileAbsPath.buildNormalizedPath();

            dwrite(afile, "+++", Project.Lists[CurrentKey]);
            if(!Project.Lists[CurrentKey].canFind(afile))//Project.AddItem(CurrentKey, afile); //AddUniqueItem
            {

                Project.AddListItem(CurrentKey, afile);
            }
            SelFiles = SelFiles.next();
        }

    }
    void AddAPath(string CurrentKey)
    {
        auto FileDialog = new FileChooserDialog("Select Files", MainWindow, FileChooserAction.SELECT_FOLDER);
        FileDialog.setSelectMultiple(true);

        auto DialogResponse = FileDialog.run();
        FileDialog.hide();

        if(DialogResponse != ResponseType.OK)return;

        string apath;
        TreeIter ti = new TreeIter;


        auto SelFiles = FileDialog.getFilenames();
        while(SelFiles !is null)
        {
            apath = toImpl!(string, char *)(cast(char *)SelFiles.data());
            //Project.AddItem(CurrentKey, afile); //AddUniqueItem?
            //Project.Lists[CurrentKey] ~= apath;
            Project.AddListItem(CurrentKey, apath);
            SelFiles = SelFiles.next();
        }

    }
    void AddAnIdentifier(string CurrentKey)
    {

        mAddedIdentifierTI = new TreeIter;
        mViewStore.append(mAddedIdentifierTI);
        mViewStore.setValue(mAddedIdentifierTI, 0, "NewValue");
        mViewStore.setValue(mAddedIdentifierTI, 1, "NewValue");
        mListView.realize();
        mListView.setCursorOnCell(mViewStore.getPath(mAddedIdentifierTI), mTVC, mCRT,  true);

        mListView.grabFocus();
    }

    void EditIdentifier(string Path, string text, CellRendererText crt)
    {

        TreeIter ti = new TreeIter;
        if(mKeyBox.getActiveIter(ti))
        {
            string CurrentKey = mComboStore.getValueString(ti,0);
            Project.AddListItem(CurrentKey, text);
            UpdateList(mKeyBox);
        }
    }

    void EditingDone(CellEditableIF x)
    {
        auto tiKey = new TreeIter;
        mKeyBox.getActiveIter(tiKey);
        string key = mComboStore.getValueString(tiKey, 0);
        auto ti = mListView.getSelectedIter();
        auto newValue = ti.getValueString(1);
        Project.AddListItem(key, newValue);
    }


    public:

    string Name(){ return "Project Viewer";}
    string Info(){ return "Browse Project.";}
    string Version() {return "00.01";}
    string CopyRight() {return "Anthony Goins © 2015";}
    string License() {return "New BSD license";}
    string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}


    void Engage()
    {
        mBuilding = new Builder;
        mBuilding.addFromFile(SystemPath(Config.GetValue("PROJECT_VIEW", "glade_file", "elements/resources/project_view.glade")));
        mRoot       = cast(Box)                mBuilding.getObject("box1");
        mLabel      = cast(Label)               mBuilding.getObject("label1");
        mToolBar    = cast(Toolbar)             mBuilding.getObject("toolbar2");
        mListView   = cast(TreeView)            mBuilding.getObject("treeview2");
        mTVC        = cast(TreeViewColumn)      mBuilding.getObject("treeviewcolumn2");
        mCRT        = cast(CellRendererText)    mBuilding.getObject("cellrenderetext3");
        mKeyBox     = cast(ComboBox)            mBuilding.getObject("combobox2");
        mViewStore  = cast(ListStore)           mBuilding.getObject("liststore2");
        mComboStore = cast(ListStore)           mBuilding.getObject("liststore1");
        mAdd        = cast(ToolButton)          mBuilding.getObject("toolbutton4");
        mRemove     = cast(ToolButton)          mBuilding.getObject("toolbutton5");
        mCellText   = cast(CellRendererText)    mBuilding.getObject("cellrenderertext4");

        mCellText.addOnEdited(&EditIdentifier);
        //mCellText.addOnEdited(&EditingDone);
        mKeyBox.addOnChanged(&UpdateList);
        mListView.addOnRowActivated(&OpenFile);

        mRemove.addOnClicked(&Remove);
        mAdd.addOnClicked(&Add);

        mKeyBox.setActive(0);

        UpdateList(mKeyBox);

        AppendToolItems();

        mRoot.showAll();
        AddSidePage(mRoot, "Project");


        Project.Event.connect(&UpdateProject);
        Config.Changed.connect(&Configure);
        Configure();

        Log.Entry("Engaged");
    }

    void Disengage()
    {
        Project.Event.disconnect(&UpdateProject);
        Config.Changed.disconnect(&Configure);
        RemoveSidePage(mRoot);
        mRoot.destroy();
        Log.Entry("Disengaged");
    }

    void Configure(string key = "", string name = "")
    {
        dwrite("here");
    }

    void Configure()
    {
    }


    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }
}

/*class PROJECT_VIEW_PREF : PREFERENCE_PAGE
{
    CheckButton     mEnabled;

    this()
    {
        super("Elements", Config.getString("PREFERENCES", "glade_file_project_view", "$(HOME_DIR)/glade/proviewpref.glade"));
        mEnabled = cast (CheckButton)mBuilder.getObject("checkbutton1");
        mFrame.showAll();
    }

    override void Apply()
    {
        Config.setBoolean("PROJECT_VIEW", "enabled", mEnabled.getActive());
    }

    override void PrepGui()
    {
        mEnabled.setActive(Config.getBoolean("PROJECT_VIEW", "enabled", true));
    }
}*/

