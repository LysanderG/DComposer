module ui_elementmanager;

import std.path;
import core.runtime;
import core.sys.posix.dlfcn;


import dcore;
import ui;
import elements;
import ui_preferences;

import gtk.Builder;
import gtk.Dialog;
import gtk.TreeView;
import gtk.ListStore;
import gtk.Button;
import gtk.TreeViewColumn;
import gtk.CellRendererToggle;

import gobject.Value;



private Dialog mElementManager;
private TreeView mView;
private ListStore mStore;
private Button  mPreferenceBtn;
private CellRendererToggle mCellToggle;


void Engage()
{
    AddIcon("ui_element_manager", SystemPath("resources/plug.png"));
    AddAction("ActElementManager", "Manager", "Manage additional elements","ui_element_manager","", delegate void(Action){Execute();LoadElements();});
    AddToMenuBar("ActElementManager", "E_lements");

    auto builder = new Builder;
    builder.addFromFile( SystemPath( Config.GetValue("ui_element_manager", "glade_file", "glade/ui_elements.glade")));

    mElementManager = cast(Dialog)builder.getObject("dialog1");
    mView = cast(TreeView)builder.getObject("treeview1");
    mStore = cast(ListStore)builder.getObject("liststore1");
    mPreferenceBtn = cast(Button)builder.getObject("button2");
    mCellToggle = cast(CellRendererToggle)builder.getObject("cellrenderertoggle1");

    void RowActivated(TreePath tp, TreeViewColumn tvc, TreeView me)
    {
        auto ti = new TreeIter;
        auto val = new Value;
        //val.init(GType.BOOLEAN);


        mStore.getIter(ti, tp);

        auto libraryKey = mStore.getValueString(ti, 4);
        mStore.getValue(ti, 0, val);
        auto tglValue = val.getBoolean();
        if(tglValue == 0)
        {
            Libraries[libraryKey].mEnabled = true;
            LoadElements();
            tglValue = 1;
        }
        else
        {
            Libraries[libraryKey].mEnabled = false;
            if(Libraries[libraryKey].ptr !is null)
            {
                Elements[Libraries[libraryKey].mClassName].Disengage();
                Elements.remove(Libraries[libraryKey].mClassName);
                Libraries[libraryKey].ptr = null;
            }
            tglValue = 0;
        }
        mPreferenceBtn.setSensitive(tglValue);

        mStore.setValue(ti, 0, Libraries[libraryKey].mEnabled);
        mStore.setValue(ti, 1, Libraries[libraryKey].mFile.baseName());
        mStore.setValue(ti, 2, Libraries[libraryKey].mName);
        mStore.setValue(ti, 3, Libraries[libraryKey].mInfo);
        mStore.setValue(ti, 4, Libraries[libraryKey].mFile);
    }
    mView.addOnRowActivated (&RowActivated);

    void RowToggled(string Path, CellRendererToggle crt)
    {
        RowActivated(new TreePath(Path), cast(TreeViewColumn)null, mView);

        dwrite("hello");
    }

    mCellToggle.addOnToggled(&RowToggled);

    void CursorChanged(TreeView me)
    {
        auto tp = new TreePath;
        auto tvc = new TreeViewColumn;
        auto ti = new TreeIter;
        auto val = new Value;

        mView.getCursor(tp, tvc);
        mStore.getIter(ti, tp);
        mStore.getValue(ti, 0, val);

        mPreferenceBtn.setSensitive(val.getBoolean());
    }
    mView.addOnCursorChanged(&CursorChanged);

    void PreferenceClicked()
    {
        auto tp = new TreePath;
        auto tvc = new TreeViewColumn;
        auto ti = new TreeIter;

        mView.getCursor(tp, tvc);
        if(tp is null)
        {
            Log.Entry("Bad state: Preference Button enabled while TreeView cursor is null", "Debug");
            mPreferenceBtn.setSensitive(false);
            return;
        }
        mStore.getIter(ti, tp);
        string libKey = mStore.getValueString(ti, 4);
        //scope(failure)

        auto prefPage = Elements[Libraries[libKey].mClassName].PreferencePage();
        if (prefPage is null)
        {
            ShowMessage("Element Prefences","No user configurable preferences for this element","Are you kidding me?", "OK");
            return;
        }
        ShowPreferencePageDialog(prefPage);
        Elements[Libraries[libKey].mClassName].Configure();
    }
    mPreferenceBtn.addOnClicked(delegate void(Button Me){PreferenceClicked();});

    Log.Entry("Engaged");

}

void PostEngage()
{
    Log.Entry("PostEngaged");
}

void Disengage()
{
    Log.Entry("Disengaged");
}


void Execute()
{
    //load up the liststore
    //AcquireLibraries();
    mStore.clear();

    foreach(lib; Libraries)
    {
        auto ti = new TreeIter;
        mStore.append(ti);

        mStore.setValue(ti, 0, lib.mEnabled);
        mStore.setValue(ti, 1, lib.mFile.baseName());
        mStore.setValue(ti, 2, lib.mName);
        mStore.setValue(ti, 3, lib.mInfo);
        mStore.setValue(ti, 4, lib.mFile);
    }

    mView.setCursor(new TreePath(true), null, false);

    mElementManager.run();
    mElementManager.hide();

    RegisterLibraries();
}



