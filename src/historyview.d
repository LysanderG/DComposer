//      history.d
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


module historyview;

import std.stdio;

import dcore;
import ui;
import elements;

import gtk.Action;
import gtk.Builder;
import gtk.Viewport;
import gtk.RecentChooserWidget;
import gtk.RecentFilter;
import gtk.RecentChooserIF;
import gtk.ScrolledWindow;


class HISTORY_VIEW : ELEMENT
{
    private:

    string              mName;
    string              mInfo;
    bool                mState;

    Builder             mBuilder;
    ScrolledWindow      mRoot;
    RecentChooserWidget mRecentProjects;
    RecentChooserWidget mRecentFiles;

    RecentFilter        mFilterProjects;
    RecentFilter        mFilterFiles;

    Action              mHistoryAct;


    public:

    @property string Name() {return mName;}
    @property string Information(){return mInfo;}
    @property bool   State() {return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        if(mState) Engage();
        else Disengage();
    }

    this()
    {
        mName = "HISTORY_VIEW";
        mInfo = "List of recent projects and files";
    }
    


    void Engage()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("RECENT_VIEW", "glade_file", "/home/anthony/.neontotem/dcomposer/historyview.glade"));

        mRoot               =   cast(ScrolledWindow)              mBuilder.getObject("scrolledwindow1");
        mRecentProjects     =   cast(RecentChooserWidget)   mBuilder.getObject("recentchooser1");
        mRecentFiles        =   cast(RecentChooserWidget)   mBuilder.getObject("recentchooser2");

        mFilterProjects = new RecentFilter;
        
        mFilterProjects.addPattern("*.dpro");
        mFilterProjects.addApplication("/home/anthony/projects/dcomposer2/dcomposer");

        //mRecentProjects.addFilter(mFilterProjects);
        mRecentProjects.setFilter(mFilterProjects);

        mFilterFiles = new RecentFilter;
    
        mFilterFiles.addPattern("*.d");
        mFilterFiles.addPattern("*.sh");
        mFilterFiles.addApplication("/home/anthony/projects/dcomposer2/dcomposer");

        //mRecentFiles.addFilter(mFilterFiles);
        mRecentFiles.setFilter(mFilterFiles);


        mRecentProjects.addOnItemActivated ( delegate void(RecentChooserIF x) {string str = x.getCurrentUri(); Project.Open(str[7..$]);}); 

        mRecentFiles.addOnItemActivated(delegate void (RecentChooserIF x) {string str = x.getCurrentUri(); dui.GetDocMan.OpenDoc(str[7..$]);});


        mHistoryAct = new Action("HistoryAct", "_History", "Bring the past only if you are going to build from it.  ~Doménico Cieri Estrada", null);
        mHistoryAct.addOnActivate(&ShowHistory);
        mHistoryAct.setAccelGroup(dui.GetAccel());
        dui.Actions().addActionWithAccel(mHistoryAct, "<Ctrl>h");
        
        dui.AddMenuItem("_View", mHistoryAct.createMenuItem());
		//dui.AddToolBarItem(SearchAct.createToolItem());

        dui.GetSidePane.appendPage(mRoot, "History");
        dui.GetSidePane.setTabReorderable (mRoot, true); 
        mRoot.showAll();

        Log.Entry("Engaged HISTORY_VIEW element");
        
    }
        

    void Disengage()
    {
        mRoot.hide();
        Log.Entry("Disengaged HISTORY_VIEW element");
    } 
    
    void ShowHistory(Action X)
    {
        mRoot.showAll();
        dui.GetSidePane.setCurrentPage(mRoot);
    }

    Frame GetPreferenceWidget()
    {
        return null;
    }
}

    

