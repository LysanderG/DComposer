//      dirview.d
//
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.


module dirview;

import std.file;
import std.path;
import std.stdio;
import std.array;
import std.conv;
import std.string;

import core.thread;
import core.memory;

import ui;
import dcore;
import elements;
import project;
import docman;

import gtk.Builder;
import gtk.ToolButton;
import gtk.ToggleToolButton;
import gtk.TreeView;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeViewColumn;
import gtk.Entry;
import gtk.Label;
import gtk.Viewport;
import gtk.ListStore;
import gtk.EditableIF;
import gtk.ComboBox;
import gtk.ComboBoxEntry;
import gtk.CellEditableIF;
import gtk.HBox;
import gtk.VBox;
import gtk.CheckButton;


import gtkc.gtk;




class DIR_VIEW : ELEMENT
{
    private:

    string              mName;
    string              mInfo;
    bool                mState;

    string              mFolder;

    DirEntry[]          mContents;



    Builder             mBuilder;

    VBox                mRoot;
    ToolButton          mUpBtn;
    ToolButton          mRefreshBtn;
    ToolButton          mHomeBtn;
    ToolButton          mSetBtn;
    ToggleToolButton    mHiddenBtn;

    Label               mDirLabel;
    ComboBoxEntry       mComboFilter;
    Entry               mEntryFilter;
    HBox                mhbox;

    TreeView            mFolderView;

    ListStore           mStore;
    ListStore           mStore2;


    DIR_VIEW_PREF		mPrefPage;
    bool				mEnabled;


    void RefreshOLD()
    {
		scope(exit) GC.enable();
        scope(failure)
        {
            mComboFilter.setActiveText("");
            mStore.clear();
            return;
        }

        TreeIter ti = new TreeIter;
        mDirLabel.setText(mFolder);
        mStore.clear();

        ListStore xStore = new ListStore([GType.STRING, GType.STRING, GType.STRING]);

        string theFileFilter;

        theFileFilter = mComboFilter.getActiveText();
        if(theFileFilter.length < 1) theFileFilter = "*";

		scope(failure)
		{
			xStore.append(ti);
			xStore.setValue(ti, 1, "Check Folder/File permissions");
			return;
		}

        auto Contents = dirEntries(mFolder, SpanMode.shallow);


        foreach(DirEntry item; Contents)
        {
            if((!mHiddenBtn.getActive) && (baseName(item.name)[0] == '.')) continue;

            if(item.isDir)
            {
                xStore.append(ti);
                xStore.setValue(ti, 0, " " );
                xStore.setValue(ti, 1, baseName(item.name));
                xStore.setValue(ti, 2, to!string(item.size));
            }

            else if (globMatch(baseName(item.name), theFileFilter))
            {
                xStore.append(ti);
                xStore.setValue(ti, 0, " ");
                xStore.setValue(ti, 1, baseName(item.name));
                xStore.setValue(ti, 2, to!string(item.size));
            }
        }

        mStore = xStore;
        mFolderView.setModel(xStore);
        mStore.setSortColumnId(1,SortType.ASCENDING);
        mStore.setSortFunc(0, &SortFunciton, null, null); //ha darn paste and copy funciton ... and it all works
        mStore.setSortFunc(1, &SortFunciton, null, null);
    }

	void Refresh()
	{
		TreeIter ti;
		scope(exit)
		{
			GC.enable();
		}
		scope(failure)
		{
			ti = new TreeIter;
			mStore.clear();
			mStore.append(ti);
			mStore.setValue(ti, 1, "Check Folder/File permissions");
			return;
		}

		mDirLabel.setText(mFolder);

        string theFileFilter = mComboFilter.getActiveText();
        if(theFileFilter.length < 1) theFileFilter = "*";

		auto Contents = dirEntries(mFolder, SpanMode.shallow);

		ti = new TreeIter;

		GC.disable();
		mStore.clear();
		foreach(DirEntry item; Contents)
        {
			scope(failure)continue;
            if((!mHiddenBtn.getActive) && (baseName(item.name)[0] == '.')) continue;

            if(item.isDir)
            {
                mStore.append(ti);
                //mStore.setValue(ti, 0, " " );
                mStore.setValue(ti, 0, "DIRVIEW_FOLDER" );
                mStore.setValue(ti, 1, baseName(item.name));
                mStore.setValue(ti, 2, "            ");
            }

            else if (globMatch(baseName(item.name), theFileFilter))
            {
                mStore.append(ti);
                mStore.setValue(ti, 0, "DIRVIEW_DOCUMENT");
                mStore.setValue(ti, 1, baseName(item.name));
                auto number = format("%s", item.size);

                mStore.setValue(ti, 2, number);
            }
        }
        //GC.enable();
		mStore.setSortColumnId(1,SortType.ASCENDING);
        mStore.setSortFunc(0, &SortFunciton, null, null); //ha darn paste and copy funciton ... and it all works
        mStore.setSortFunc(1, &SortFunciton, null, null);

	}

    void UpClicked(ToolButton x)
    {
        Folder = mFolder.dirName;
    }

    void GoHome(ToolButton x)
    {
        if((Project.Target == TARGET.NULL) || (Project.Target == TARGET.UNDEFINED))Folder = expandTilde("~");
        else Folder = Project.WorkingPath;
    }

    void GoToCurrentDocFolder(ToolButton x)
    {
		if(dui.GetDocMan.Current is null)return;
        scope (failure) return;
        Folder = dirName(dui.GetDocMan.Current.Name);
    }

    void FileClicked( TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter;

        if(!mStore.getIter(ti, tp)) return;

        string type = mStore.getValueString(ti, 0);

        if(type == "DIRVIEW_FOLDER") Folder = buildPath(mFolder , mStore.getValueString(ti,1));
        if(type == "DIRVIEW_DOCUMENT") dui.GetDocMan.Open(buildPath(mFolder, mStore.getValueString(ti,1)));

    }

    void FileSelected(TreeView tv)
    {
        TreeIter ti = new TreeIter;

        ti = tv.getSelectedIter();
        if(ti is null) return;

        dui.Status.push(0, mStore.getValueString(ti,0) ~ ": " ~ mStore.getValueString(ti, 1) ~ "\t:\t\tsize " ~ mStore.getValueString(ti,2));

    }


    void AddFilter()
    {
        CHECK SendData;
        SendData.Text = mEntryFilter.getText();
        SendData.Bool = true;

        mStore2.foreac(&Check, &SendData);
        //mComboFilter.getModel().foreac(&Check, &SendData);

       if(SendData.Bool) mComboFilter.appendText(mEntryFilter.getText());
    }

    void Configure()
    {
		mEnabled = Config.getBoolean("DIRVIEW","enabled", true);
		mStore2.clear();
		TreeIter ti = new TreeIter;
		string x = Config.getString("DIRVIEW", "file_filter", "*.d:*.di:*.dpro");

		auto xarray = x.split(":");

		foreach(filter; xarray)
		{
			mStore2.append(ti);
			mStore2.setValue(ti, 0, filter);
		}
		mRoot.showAll();
		mRoot.setVisible(mEnabled);
	}

	void SetPagePosition(UI_EVENT uie)
	{
		switch (uie)
		{
			case UI_EVENT.RESTORE_GUI :
			{
				dui.GetSidePane.reorderChild(mRoot, Config.getInteger("DIRVIEW", "page_position"));
				break;
			}
			case UI_EVENT.STORE_GUI :
			{
				Config.setInteger("DIRVIEW", "page_position", dui.GetSidePane.pageNum(mRoot));
				break;
			}
			default :break;
		}
	}


    public:

    this()
    {
        mName = "DIR_VIEW";
        mInfo = "Simple File Browser";
        mFolder = getcwd();
        mEnabled = true;

        dui.AddIcon("DIRVIEW_FOLDER", Config.ExpandPath("$(HOME_DIR)/glade/folder-horizontal-open.png"));
        dui.AddIcon("DIRVIEW_DOCUMENT", Config.ExpandPath("$(HOME_DIR)/glade/document.png"));
        dui.AddIcon("DIRVIEW_UP", Config.ExpandPath("$(HOME_DIR)/glade/arrow-090.png"));
        dui.AddIcon("DIRVIEW_REFRESH", Config.ExpandPath("$(HOME_DIR)/glade/arrow-circle-double.png"));
        dui.AddIcon("DIRVIEW_HOME", Config.ExpandPath("$(HOME_DIR)/glade/home.png"));
        dui.AddIcon("DIRVIEW_SET", Config.ExpandPath("$(HOME_DIR)/glade/arrow-step.png"));
        dui.AddIcon("DIRVIEW_HIDDEN", Config.ExpandPath("$(HOME_DIR)/glade/ghost.png"));
        mPrefPage = new DIR_VIEW_PREF;
    }

    @property string Name() {return mName;}
    @property string Information(){return mInfo;}
    @property bool   State() {return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        if(mState) Engage();
        else Disengage();

        mFolder = getcwd();
    }
    @property void Folder(string nuFolder)
    {
        mFolder = nuFolder;
        Refresh();
    }

    void Engage()
    {
		scope(failure) Log.Entry("Failed to Engage DIR_VIEW element", "Error");
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("DIRVIEW","glade_file", "$(HOME_DIR)/glade/dirview.glade"));

        mRoot           = cast(VBox)    mBuilder.getObject("vbox1");

        mFolderView     = cast(TreeView)    mBuilder.getObject("treeview1");
        mStore          = cast(ListStore)   mBuilder.getObject("liststore1");
        mDirLabel       = cast(Label)       mBuilder.getObject("addresslabel");
        mUpBtn          = cast(ToolButton)  mBuilder.getObject("toolbutton1");
        mRefreshBtn     = cast(ToolButton)  mBuilder.getObject("toolbutton2");
        mHomeBtn        = cast(ToolButton)  mBuilder.getObject("toolbutton3");
        mSetBtn         = cast(ToolButton)  mBuilder.getObject("toolbutton4");
        mHiddenBtn      = cast(ToggleToolButton)  mBuilder.getObject("toolbutton5");

        mStore2         = cast(ListStore)   mBuilder.getObject("liststore2");

		mStore.setSortColumnId(1,SortType.ASCENDING);
        mStore.setSortFunc(0, &SortFunciton, null, null); //ha darn paste and copy funciton ... and it all works
        mStore.setSortFunc(1, &SortFunciton, null, null);

        mUpBtn.addOnClicked(&UpClicked);
        mRefreshBtn.addOnClicked(delegate void (ToolButton x){Refresh();});
        mHomeBtn.addOnClicked(&GoHome);
        mSetBtn.addOnClicked(&GoToCurrentDocFolder);
        mHiddenBtn.addOnClicked(delegate void (ToolButton x){Refresh();});

        mUpBtn.setStockId("DIRVIEW_UP");
        mRefreshBtn.setStockId("DIRVIEW_REFRESH");
        mHomeBtn.setStockId("DIRVIEW_HOME");
        mSetBtn.setStockId("DIRVIEW_SET");
        mHiddenBtn.setStockId("DIRVIEW_HIDDEN");


        //all the following section is for the comboboxentry crap that wont work out of the box

        auto c_mComboFilter = gtk_combo_box_entry_new_text();
        auto c_mComboEntry  = gtk_bin_get_child(cast(GtkBin *)c_mComboFilter);

        mComboFilter = new ComboBoxEntry(cast(GtkComboBoxEntry*) c_mComboFilter);

        mEntryFilter = new Entry(cast(GtkEntry*)c_mComboEntry);
        mEntryFilter.setStockId(EntryIconPosition.SECONDARY, StockID.APPLY);

        mComboFilter.setModel(mStore2);

        mComboFilter.addOnChanged(delegate void (ComboBox x){Refresh();});
        mEntryFilter.addOnActivate(delegate void (Entry x){AddFilter();});
        mEntryFilter.addOnIconPress(delegate void (GtkEntryIconPosition pos, GdkEvent* event, Entry entry) {AddFilter();});

        mhbox = cast(HBox)mBuilder.getObject("hbox1");

        mhbox.add(mComboFilter);


        mFolderView.addOnCursorChanged(&FileSelected);
        mFolderView.addOnRowActivated(&FileClicked);

        Refresh();
        mRoot.showAll();

        dui.GetSidePane.appendPage(mRoot, "Files");
        dui.connect(&SetPagePosition);
        dui.GetSidePane.setTabReorderable (mRoot, true);
        Config.Reconfig.connect(&Configure);

        Configure();
        Log.Entry("Engaged "~Name()~"\t\telement.");
    }


    void Disengage()
    {
        string FilterString;
        TreeIter x = new TreeIter;

        if(mStore2.getIterFirst(x))
        {
            FilterString = mStore2.getValueString(x,0);

            while(mStore2.iterNext(x)) FilterString ~= ":" ~ mStore2.getValueString(x, 0);
        }
        if(FilterString.length < 1) FilterString = "*.d:*.di:*.dpro";
        Config.setString("DIRVIEW", "file_filter", FilterString);
        Log.Entry("Disengaged "~mName~"\t\telement.");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return mPrefPage;
    }

}



class DIR_VIEW_PREF :PREFERENCE_PAGE
{
	LISTUI 			mFilterList;
	CheckButton 	mEnabled;

	this()
	{
		super("Elements", Config.getString("PREFERENCES", "glade_file_dir_view", "$(HOME_DIR)/glade/dirviewpref.glade"));

		mEnabled = cast (CheckButton) mBuilder.getObject("checkbutton1");

		string listgladefile = Config.getString("PROJECT", "list_glad_file", "$(HOME_DIR)/glade/multilist.glade");
		mFilterList = new LISTUI("Filter Glob", ListType.IDENTIFIERS, listgladefile);

		//mVBox.add(mFilterList.GetWidget());
		mVBox.packEnd(mFilterList.GetWidget(), 1, 1, 0);

		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setBoolean("DIRVIEW", "enabled", mEnabled.getActive());

		string tmpfilters = "*";
		foreach (string f; mFilterList.GetFullItems()) tmpfilters ~= ':' ~ f;
		Config.setString("DIRVIEW", "file_filter", tmpfilters);
	}

	override void PrepGui()
	{
		mEnabled.setActive(Config.getBoolean("DIRVIEW", "enabled", true));

		string tmpstring = Config.getString("DIRVIEW", "file_filter", "*");
		auto tmpstrings = tmpstring.split(":");
		mFilterList.SetItems(tmpstrings);
	}

	override bool Expand() {return true;}
}





/++
 + Checks a possible new entry in combobox to see if it already exists.
 + If it does then sets CHECK.Bool to false and returns true stopping the treemodel.foreac() loop.
 + Otherwise returns false indicating possible candidate can be added.
 +/
extern (C) int Check (GtkTreeModel *model, GtkTreePath *path, GtkTreeIter *iter,  void * data)
{

    CHECK * retData = cast(CHECK *) data;

    ListStore ls = new ListStore(cast(GtkListStore*)model);

    TreeIter ti = new TreeIter(iter);
    if( retData.Text == ls.getValueString(ti,0))
    {
        retData.Bool = false;
        return true;
    }
    return false;
}

struct CHECK
{
    string Text;
    bool    Bool;
}

/++
 +  Sort the dir contents with folders up top
 +  Removes leading '.' and is case insensitive
 +
+/

extern (C) int SortFunciton(GtkTreeModel *model, GtkTreeIter *a, GtkTreeIter *b, gpointer user_data)
{
    ListStore ls = new ListStore(cast (GtkListStore *) model);
    TreeIter tiA  = new TreeIter(a);
    TreeIter tiB  = new TreeIter(b);
    if(ls.getValueString(tiA,0) < ls.getValueString(tiB,0)) return -1;
    if(ls.getValueString(tiA,0) > ls.getValueString(tiB,0)) return 1;


    string Aname = ls.getValueString(tiA,1);
    Aname = chompPrefix(Aname, ".").toUpper();
    string Bname = ls.getValueString(tiB,1);
    Bname = chompPrefix(Bname, ".").toUpper();
    if(Aname < Bname) return -1;
    if(Aname > Bname) return 1;

    return 0;
}
