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


    void Refresh()
    {
        scope(failure)
        {
            mComboFilter.setActiveText("");
            mStore.clear();
            return;
            //Refresh(); //hey stupid you can't do this
        }
        TreeIter ti = new TreeIter;
        mDirLabel.setText(mFolder);        
        mStore.clear();

        ListStore xStore = new ListStore([GType.STRING, GType.STRING, GType.STRING]);

        string theFileFilter;

        theFileFilter = mComboFilter.getActiveText();
        if(theFileFilter.length < 1) theFileFilter = "*";

        version(DMD)
        {
            //auto Contents = dirEntries(mFolder, mFilter.getText(), SpanMode.shallow);
            scope(failure)
            {
                xStore.append(ti);
                xStore.setValue(ti, 1, "Check Folder/File permissions");
                return;
            }
            //auto Contents = dirEntries(mFolder, theFileFilter, SpanMode.shallow);
            auto Contents = dirEntries(mFolder, SpanMode.shallow);
            
        }
        version(GDMD)
        {
            auto Contents = dirEntries(mFolder, SpanMode.shallow);
        }

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
        auto docX = dui.GetDocMan.GetDocX();
        if(docX is null) return;

        Folder = dirName(docX.FullPathName);
    }

    void FileClicked( TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter;

        if(!mStore.getIter(ti, tp)) return;

        string type = mStore.getValueString(ti, 0);

        if(type == " ") Folder = buildPath(mFolder , mStore.getValueString(ti,1));
        if(type == " ") dui.GetDocMan.OpenDoc(buildPath(mFolder, mStore.getValueString(ti,1)));

        //dui.Status.push(0, type ~ " : " ~ mStore.getValueString(ti,1) ~ to!string(mStore.getValueString(ti,2)) ~ ": size");
    }

    void FileSelected(TreeView tv)
    {
        TreeIter ti = new TreeIter;

        ti = tv.getSelectedIter();
        if(ti is null) return;

        //dui.Status.push(0, mStore.getValueString(ti,0) ~ ": " ~ mStore.getValueString(ti, 1) ~ "\t:\t\tsize " ~ mStore.getValueString(ti,2));

    }
        

    void AddFilter()
    {
        
        CHECK SendData;
        SendData.Text = mEntryFilter.getText();
        SendData.Bool = true;        
        
        mComboFilter.getModel().foreac(&Check, &SendData);            
        
       if(SendData.Bool) mComboFilter.appendText(mEntryFilter.getText());
    }
    
    

    public:

    this()
    {
        mName = "DIR_VIEW";
        mInfo = "Simple File Browser";
        mFolder = getcwd();
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
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("DIRVIEW","glade_file", "/home/anthony/.neontotem/dcomposer/dirview.glade"));
        
        //mRoot           = cast(Viewport)    mBuilder.getObject("viewport1");
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

        mStore.setSortFunc(0, &SortFunciton, null, null);
        mStore.setSortFunc(1, &SortFunciton, null, null);

        mUpBtn.addOnClicked(&UpClicked);
        mRefreshBtn.addOnClicked(delegate void (ToolButton x){Refresh();});
        mHomeBtn.addOnClicked(&GoHome);
        mSetBtn.addOnClicked(&GoToCurrentDocFolder);
        mHiddenBtn.addOnClicked(delegate void (ToolButton x){Refresh();});


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

            //ok now load the liststore filter data
            mStore2.clear();
            TreeIter ti = new TreeIter;
            string x = Config.getString("DIRVIEW", "file_filter", "*.d:*.di:*.dpro");

            auto xarray = x.split(":");

            foreach(filter; xarray)
            {
                mStore2.append(ti);
                mStore2.setValue(ti, 0, filter);
            }
            //ok                

        //end of comboentrycrap           

        mFolderView.addOnCursorChanged(&FileSelected);
        mFolderView.addOnRowActivated(&FileClicked);

        Refresh();
        mRoot.showAll();
        dui.GetSidePane.appendPage(mRoot, "Files");
        dui.GetSidePane.setTabReorderable (mRoot, true); 
        Log.Entry("Engaged DIRECTORY_VIEW element");
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
        Log.Entry("Disengaged DIRECTORY_VIEW element");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return null;
    }
    
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
