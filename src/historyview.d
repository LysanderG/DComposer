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

import gtk.Builder;
import gtk.Viewport;
import gtk.RecentChooserWidget;
import gtk.RecentFilter;
import gtk.RecentChooserIF;


class HISTORY_VIEW : ELEMENT
{
    private:

    string              mName;
    string              mInfo;
    bool                mState;

    Builder             mBuilder;
    Viewport            mRoot;
    RecentChooserWidget mRecentProjects;
    RecentChooserWidget mRecentFiles;

    RecentFilter        mFilterProjects;
    RecentFilter        mFilterFiles;


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
        mBuilder.addFromFile(GetConfig.getString("RECENT_VIEW", "glade_file", "/home/anthony/.neontotem/dcomposer/historyview.glade"));

        mRoot               =   cast(Viewport)              mBuilder.getObject("viewport1");
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


        mRecentProjects.addOnItemActivated ( delegate void(RecentChooserIF x) {string str = x.getCurrentUri(); GetProject.Open(str[7..$]);}); 

        mRecentFiles.addOnItemActivated(delegate void (RecentChooserIF x) {writeln(x);string str = x.getCurrentUri();writeln(str[7..$]); dui.GetDocMan.OpenDoc(str[7..$]);});
        

        dui.GetSidePane.appendPage(mRoot, "History");
        mRoot.showAll();

        GetLog.Entry("Engaged HISTORY_VIEW element");
        
    }
        

    void Disengage()
    {
        mRoot.hide();
        GetLog.Entry("Disengaged HISTORY_VIEW element");
    } 
    

}

    

