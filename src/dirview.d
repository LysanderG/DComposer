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

    Viewport            mRoot;
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
            Refresh();
        }
        TreeIter ti = new TreeIter;
        mDirLabel.setText(mFolder);        
        mStore.clear();

        string theFileFilter;

        theFileFilter = mComboFilter.getActiveText();
        if(theFileFilter.length < 1) theFileFilter = "*";

        version(DMD)
        {
            //auto Contents = dirEntries(mFolder, mFilter.getText(), SpanMode.shallow);
            auto Contents = dirEntries(mFolder, theFileFilter, SpanMode.shallow);
        }
        version(GDMD)
        {
            auto Contents = dirEntries(mFolder, SpanMode.shallow);
        }

        foreach(DirEntry item; Contents)
        {
            if((!mHiddenBtn.getActive) && (baseName(item.name)[0] == '.')) continue;
            mStore.append(ti);
            if(item.isDir) mStore.setValue(ti, 0, " " );
            else mStore.setValue(ti, 0, " ");
            mStore.setValue(ti, 1, baseName(item.name));
        }

        mFolderView.setModel(mStore);
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
    }


    void AddFilter()
    {
        writeln("hello!!!");
        mComboFilter.appendText(mEntryFilter.getText());
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
        
        mRoot           = cast(Viewport)    mBuilder.getObject("viewport1");

        mFolderView     = cast(TreeView)    mBuilder.getObject("treeview1");
        mStore          = cast(ListStore)   mBuilder.getObject("liststore1");
        mDirLabel       = cast(Label)       mBuilder.getObject("addresslabel");
        mUpBtn          = cast(ToolButton)  mBuilder.getObject("toolbutton1");
        mRefreshBtn     = cast(ToolButton)  mBuilder.getObject("toolbutton2");
        mHomeBtn        = cast(ToolButton)  mBuilder.getObject("toolbutton3");
        mSetBtn         = cast(ToolButton)  mBuilder.getObject("toolbutton4");
        mHiddenBtn      = cast(ToggleToolButton)  mBuilder.getObject("toolbutton5");
        
        mStore2         = cast(ListStore)   mBuilder.getObject("liststore2");

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

        

        mFolderView.addOnRowActivated(&FileClicked);

        Refresh();
        mRoot.showAll();
        dui.GetSidePane.appendPage(mRoot, "Files");
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
        writeln("Filterstring = ",FilterString);
        if(FilterString.length < 1) FilterString = "*.d:*.di:*.dpro";

        Config.setString("DIRVIEW", "file_filter", FilterString);
        Log.Entry("Disengaged DIRECTORY_VIEW element");
    }
    
}
