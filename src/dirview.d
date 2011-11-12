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

import ui;
import dcore;
import elements;
import dproject;
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
    Entry               mFilter;

    TreeView            mFolderView;

    ListStore           mStore;





    void Refresh()
    {
        scope(failure)
        {
            mFilter.setText("*");
            Refresh();
        }
        TreeIter ti = new TreeIter;
        mDirLabel.setText(mFolder);        
        mStore.clear();        

        auto Contents = dirEntries(mFolder, mFilter.getText(), SpanMode.shallow);

        foreach(item; Contents)
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
        if(Project.Type != TARGET.NULL) Folder = Project.BaseDir;
        else Folder = expandTilde("~");
    }

    void GoToCurrentDocFolder(ToolButton x)
    {
        auto docX = dui.GetDocMan.GetDocX();
        if(docX is null) return;

        Folder = dirName(docX.FullName);
    }

    void FileClicked( TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter;

        if(!mStore.getIter(ti, tp)) return;

        string type = mStore.getValueString(ti, 0);
        writeln(type);

        if(type == " ") Folder = buildPath(mFolder , mStore.getValueString(ti,1));
        if(type == " ") dui.GetDocMan.OpenDoc(buildPath(mFolder, mStore.getValueString(ti,1)));
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
        writeln(mFolder);
        Refresh();
    }
    
    void Engage()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("DIRVIEW","glade_file", "/home/anthony/.neontotem/dcomposer/dirview.glade"));
        
        mRoot           = cast(Viewport)    mBuilder.getObject("viewport1");
        mFilter         = cast(Entry)       mBuilder.getObject("entry1");
        mFolderView     = cast(TreeView)    mBuilder.getObject("treeview1");
        mStore          = cast(ListStore)   mBuilder.getObject("liststore1");
        mDirLabel       = cast(Label)       mBuilder.getObject("addresslabel");
        mUpBtn          = cast(ToolButton)  mBuilder.getObject("toolbutton1");
        mRefreshBtn     = cast(ToolButton)  mBuilder.getObject("toolbutton2");
        mHomeBtn        = cast(ToolButton)  mBuilder.getObject("toolbutton3");
        mSetBtn         = cast(ToolButton)  mBuilder.getObject("toolbutton4");
        mHiddenBtn      = cast(ToggleToolButton)  mBuilder.getObject("toolbutton5");


        mUpBtn.addOnClicked(&UpClicked);
        mRefreshBtn.addOnClicked(delegate void (ToolButton x){Refresh();});
        mHomeBtn.addOnClicked(&GoHome);
        mSetBtn.addOnClicked(&GoToCurrentDocFolder);
        mHiddenBtn.addOnClicked(delegate void (ToolButton x){Refresh();});
        //mFilter.addOnChanged(delegate void (EditableIF x){Refresh();});
        mFilter.addOnActivate(delegate void (Entry x){Refresh();});

        mFolderView.addOnRowActivated(&FileClicked);

        
        Refresh();
        mRoot.showAll();
        dui.GetSidePane.appendPage(mRoot, "Files");
        Log.Entry("Engaged DIRECTORY_VIEW element");
    }
        

    void Disengage()
    {
        Log.Entry("Disengaged DIRECTORY_VIEW element");
    }
    
}
