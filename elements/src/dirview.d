module dirview;

import elements;
import dcore;
import ui;
import ui_preferences;

import std.traits;
import std.file;
import std.string;
import std.path;
import std.conv;
import std.algorithm;

import gtk.Builder;
import gtk.Box;
import gtk.Toolbar;
import gtk.TreeView;
import gtk.ListStore;
import gtk.ComboBoxText;
import gtk.Entry;
import gtk.Label;
import gtk.ToolButton;
import gtk.ToggleToolButton;
import gtk.TreeViewColumn;

import gio.ContentType;


extern (C) string GetClassName()
{
    return "dirview.DIR_VIEW";
}


class DIR_VIEW : ELEMENT
{
    private:

    Box         mRoot;
    Toolbar     mToolbar;
    TreeView    mView;
    ListStore   mStore;
    ComboBoxText mComboText;
    Entry       mText;
    Label       mDirLabel;

    string      mCurrentFolder;
    bool        mViewHidden;

    void GoHome()
    {
        if(Project.TargetType != TARGET.EMPTY) Folder = Project.Folder;
        else Folder = expandTilde("~");
    }
    void GotoParent()
    {
        Folder = Folder.dirName();
    }

    void GotoDocFolder()
    {
        if(DocMan.Current is null) return;
        Folder = dirName(DocMan.Current.Name);
    }

    void ToggleViewHidden(ToggleToolButton tglButton)
    {
        mViewHidden = ! (cast(bool)tglButton.getActive());
        if(mViewHidden == true) //view hidden
        {
            tglButton.setStockId("dir_view_hidden_true");
        }
        else
        {
            tglButton.setStockId("dir_view_hidden_false");
        }
        Refresh();
    }



    void Refresh()
    {
        mStore.clear();
        string filterText = mText.getText();
        if(filterText.length < 1)filterText = "*";
        foreach(DirEntry entry; dirEntries(mCurrentFolder, filterText, SpanMode.shallow))
        {
            scope(failure)
            {
                Log.Entry("\tDirectory error detected... continuing");
                continue;
            }
            string sortname;
            string simplename = entry.name.baseName();
            ulong filesize = entry.size;
            string stringsize = format("% 18s ", filesize);
            string iconname = "gtk-missing-image";

            if( (simplename.startsWith(".")) && (mViewHidden) ) continue;
            if(entry.isDir)
            {
                iconname = "dir_view_folder";
                filesize = 0UL;
                stringsize = "(DIR)";
                sortname = "0"~simplename;
            }
            if(entry.isFile)
            {
                auto ext = extension(simplename);
                if( (ext == ".d") || (ext == ".di"))
                {
                    sortname = "1"~simplename;
                    iconname = "dir_view_file_d";
                }
                else
                {
                    sortname = "2"~simplename;
                    iconname = "dir_view_file";
                }
            }

            TreeIter ti = new TreeIter;
            mStore.append(ti);
            mStore.setValue(ti, 0, iconname);
            mStore.setValue(ti, 1, simplename);
            mStore.setValue(ti, 2, stringsize);
            mStore.setValue(ti, 3, cast(uint)filesize);
            mStore.setValue(ti, 4, sortname);

        }
        mDirLabel.setMarkup(`<span size="larger"><b>` ~ Folder ~ `</b></span>`);

    }

    void WatchViewActivated(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        //get what was activated
        TreeIter trit = new TreeIter;
        mStore.getIter(trit, tp);

        //basename
        string bname = mStore.getValueString(trit, 1);
        //fullname
        string fullname = buildPath(Folder, bname);

        //what is this selection
        if(fullname.isDir())
        {
            string cleanup = Folder;

            scope(failure)
            {
                ShowMessage("Can not view Folder","Please check permission/existance of " ~ fullname);
                Folder = cleanup;
                return;
            }
            Folder = fullname;
            return;
        }
        if(fullname.isFile())
        {
            DocMan.Open(fullname);
            return;
        }

        ShowMessage("What is this thing", "DComposer can't open this file (" ~ fullname ~ ")");
    }




    public:

    string Name(){ return "Directory Viewer";}
    string Info(){ return "File Browser with a very limited number of actions to perform.";}
    string Version() {return "00.01";}
    string CopyRight() {return "Anthony Goins © 2014";}
    string License() {return "New BSD license";}
    string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}

    void Engage()
    {
        mViewHidden = true;

        auto builder = new Builder;
        builder.addFromFile(Config.GetValue("dir_view", "glade_file", SystemPath("elements/resources/dirview.glade")));

        //stuff we need to manipulate or just look at
        mRoot = cast(Box)builder.getObject("root");
        mToolbar = cast(Toolbar)builder.getObject("toolbar1");
        mView = cast(TreeView)builder.getObject("treeview1");
        mStore = cast(ListStore)builder.getObject("liststore1");
        mComboText = cast(ComboBoxText)builder.getObject("comboboxtext1");
        mText = cast(Entry)builder.getObject("internal-entry");
        mDirLabel = cast(Label)builder.getObject("label2");

        //setup the comboboxtext stuff
        auto savedfilters = Config.GetArray!string("dir_view", "saved_filters", ["*.d", "*.di", "*.dpro"]);
        foreach(filter; uniq(sort(savedfilters)))mComboText.appendText(filter);
        mText.addOnActivate(delegate void(Entry){mComboText.prependText(mText.getText());Refresh();});
        mText.addOnIconRelease(delegate void (GtkEntryIconPosition, GdkEvent*, Entry){mText.setText("");Refresh();});


        //icons, actions, unspoken holy vows
        AddIcon("dir_view_up", SystemPath("elements/resources/navigation-090-frame.png"));
        AddIcon("dir_view_refresh", SystemPath("elements/resources/arrow-circle-double-135.png"));
        AddIcon("dir_view_home", SystemPath("elements/resources/home.png"));
        AddIcon("dir_view_sync", SystemPath("elements/resources/navigation-270-frame.png"));
        AddIcon("dir_view_hidden_true", SystemPath("elements/resources/eye-close.png"));
        AddIcon("dir_view_hidden_false", SystemPath("elements/resources/eye.png"));
        AddIcon("dir_view_folder", SystemPath("elements/resources/folder.png"));
        AddIcon("dir_view_file", SystemPath("elements/resources/document.png"));
        AddIcon("dir_view_file_d", SystemPath("elements/resources/document-attribute-d.png"));

        //buttons
        auto upButton = new ToolButton("dir_view_up");
        upButton.setHasTooltip(true);
        upButton.setTooltipText("Go to parent directory (../)");

        auto refreshButton = new ToolButton("dir_view_refresh");
        refreshButton.setHasTooltip(true);
        refreshButton.setTooltipText("refresh the folder view (will not automatically refresh)");

        auto homeButton = new ToolButton("dir_view_home");
        homeButton.setHasTooltip(true);
        homeButton.setTooltipText("Go to home folder (~/ or project root folder if project is loaded)");

        auto syncButton = new ToolButton("dir_view_sync");
        syncButton.setHasTooltip(true);
        syncButton.setTooltipText("Go to current document's folder");

        auto hiddenButton = new ToggleToolButton("dir_view_hidden_true");
        hiddenButton.setHasTooltip(true);
        hiddenButton.setTooltipText("View (or don't view) hidden files/folders");


        //build toolbar
        mToolbar.add(upButton);
        mToolbar.add(refreshButton);
        mToolbar.add(homeButton);
        mToolbar.add(syncButton);
        mToolbar.add(hiddenButton);

        //callbacks for buttons
        upButton.addOnClicked(delegate void(ToolButton){GotoParent();} );
        refreshButton.addOnClicked(delegate void(ToolButton){Refresh();});
        homeButton.addOnClicked(delegate void(ToolButton){GoHome();});
        syncButton.addOnClicked(delegate void(ToolButton){GotoDocFolder();});
        hiddenButton.addOnToggled(delegate void(ToggleToolButton ttb){ToggleViewHidden(ttb);});

        //lock and load the tree and its model
        Folder = getcwd();


        //what to do when treeview row is activated
        mView.addOnRowActivated (&WatchViewActivated);

        //mRoot.showAll();
        AddSidePage(mRoot, "File Viewer");
        mRoot.showAll();

        Log.Entry("Engaged");
    }



    void Disengage()
    {
        //combobox crap
        string[] filters2save;
        TreeIter trit = new TreeIter;
        auto treemodel = mComboText.getModel();
        int validiter = treemodel.getIterFirst(trit);
        while(validiter)
        {
            filters2save ~= treemodel.getValueString(trit, 0);
            validiter = treemodel.iterNext(trit);
        }
        Config.SetArray("dir_view", "saved_filters", filters2save);

        RemoveSidePage(mRoot);
        mRoot.destroy();


        Log.Entry("Disengaged");
    }

    void Configure(){}


    @property string Folder()
    {
        return mCurrentFolder;
    }
    @property void Folder(string nuFolder)
    {
        mCurrentFolder = nuFolder;
        Refresh();
    }

    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }
}







