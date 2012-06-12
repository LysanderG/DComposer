//      messageui.d
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


module messageui;

import dcore;
import ui;
import elements;
import std.regex;
import std.conv;
import std.stdio;


import gtk.Viewport;
import gtk.ScrolledWindow;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.ListStore;
import gtk.CellRendererText;
import gtk.TreePath;

class MESSAGE_UI :ELEMENT
{
    private:

    string          mName;
    string          mInfo;
    bool            mState;

    Viewport        mRoot;
    ScrolledWindow  mScrWin;
    TreeView        mErrorView;
    ListStore       mStore;

    void WatchDMD(string line)
    {       
    	static int ActivityIndicator = 0;
    	
        scope(exit)mErrorView.setModel(mStore);
        if(line == `BEGIN`)
        {
            
            dui.Status.push (0, "Building  " ~ Project.Name ~ " ...");
            if(ActivityIndicator-- < -2) ActivityIndicator = -1;
            //Log.Entry("messageui.WatchDMD line = 'BEGIN'");
            
            mStore.clear();
            dui.GetExtraPane.setCurrentPage(mRoot);
            return;
        }
        if(line == `END`)
        {
           dui.Status.push (0, "Building  " ~ Project.Name ~ " ...  Done");
            return;
        }
        auto m = line.match(regex(`\(\d+\)`));

        TreeIter ti = new TreeIter;
        if(m.empty)
        {
            mStore.append(ti);
            mStore.setValue(ti, 1, ActivityIndicator);
            mStore.setValue(ti, 2, line);
            return;
        }
        auto m1 = m.pre;
        auto m2 = m.hit;
        auto m3 = m.post;
        string lno = m2[1..$-1];
       
        int number = to!int(lno);

        mStore.append(ti);
        mStore.setValue(ti, 0, m1);
        mStore.setValue(ti, 1, number);
        mStore.setValue(ti, 2, m3);
    }

    void RowActivated(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter;

        mStore.getIter(ti, tp);
        string file = mStore.getValueString(ti, 0);
        int line = mStore.getValueInt(ti, 1) -1;

        if(line < 0) return; //if this is not an error line (ie an info line) then do not try to open
        dui.GetDocMan.OpenDoc(file, line);
    }
        
    
    public:

    this()
    {
        mName = "MESSAGE_UI";
        mInfo = "Display compiler output (and allow navigating to error lines)";
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
    }

    void Engage()
    {
        mStore = new ListStore([GType.STRING, GType.INT, GType.STRING]);

        mErrorView = new TreeView;
        mErrorView.insertColumn(new TreeViewColumn("File", new CellRendererText, "text", 0), -1);
        mErrorView.insertColumn(new TreeViewColumn("Line", new CellRendererText, "text", 1), -1);
        mErrorView.insertColumn(new TreeViewColumn("Error",new CellRendererText, "text", 2), -1);

        mErrorView.addOnRowActivated (&RowActivated);
        
        mScrWin = new ScrolledWindow;
        mScrWin.add(mErrorView);
        mRoot = new Viewport(null, null);
        mRoot.add(mScrWin);

        mErrorView.setModel(mStore);

        mRoot.showAll();

        dui.GetExtraPane.appendPage(mRoot, "Build Messages");
        dui.GetExtraPane.setTabReorderable ( mRoot, true); 
        

        Project.BuildMsg.connect(&WatchDMD);

        Log.Entry("Engaged MESSAGE_UI element");
    }
        

    void Disengage()
    {
        Project.BuildMsg.disconnect(&WatchDMD);
        Log.Entry("Disengaged MESSAGE_UI element");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {

		//do not want to hide messages so ... no preferences I can think of
        return null;
    }

    
}
