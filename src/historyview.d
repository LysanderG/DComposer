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
import gtk.VBox;
import gtk.CheckButton;
import gtk.Label;
import gtk.SeparatorToolItem;


class HISTORY_VIEW : ELEMENT
{
    private:

    string              mName;
    string              mInfo;
    bool                mState;

    Builder             mBuilder;
    VBox			    mRoot;
    RecentChooserWidget mRecentProjects;
    RecentChooserWidget mRecentFiles;

    RecentFilter        mFilterProjects;
    RecentFilter        mFilterFiles;

    Action              mHistoryAct;

    HISTORY_VIEW_PREF	mPrefPage;
    bool				mEnabled;

    void Configure()
    {
		mEnabled = Config.getBoolean("HISTORY_VIEW", "enabled", true);
		mRoot.setVisible(mEnabled);
	}


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

        mPrefPage = new HISTORY_VIEW_PREF;
    }
    


    void Engage()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("RECENT_VIEW", "glade_file", "$(HOME_DIR)/glade/historyview2.glade"));

        mRoot               =   cast(VBox)        mBuilder.getObject("vbox1");
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

        mRecentFiles.addOnItemActivated(delegate void (RecentChooserIF x) {string str = x.getCurrentUri(); dui.GetDocMan.Open(str[7..$]);});

		dui.AddIcon("dcomposer-history", Config.getString("ICONS", "history", "$(HOME_DIR)/glade/folder-history.png"));
        mHistoryAct = new Action("HistoryAct", "_History", "Bring the past only if you are going to build from it.  ~Doménico Cieri Estrada", "dcomposer-history");
        mHistoryAct.addOnActivate(&ShowHistory);
        mHistoryAct.setAccelGroup(dui.GetAccel());
        dui.Actions().addActionWithAccel(mHistoryAct, "<Ctrl>h");
        
        dui.AddMenuItem("_View", mHistoryAct.createMenuItem());
		dui.AddToolBarItem(mHistoryAct.createToolItem());
		dui.AddToolBarItem(new SeparatorToolItem);

        dui.GetSidePane.appendPage(mRoot, "History");
        dui.GetSidePane.setTabReorderable (mRoot, true); 
        mRoot.showAll();

		Config.Reconfig.connect(&Configure);
		Configure();
		
        Log.Entry("Engaged "~Name()~"\t\telement.");
        
    }
        

    void Disengage()
    {
        mRoot.hide();
        Log.Entry("Disengaged "~mName~"\t\telement.");
    } 
    
    void ShowHistory(Action X)
    {
		if(!mEnabled) return;
        mRoot.showAll();
        dui.GetSidePane.setCurrentPage(mRoot);
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return mPrefPage;
    }
}


class HISTORY_VIEW_PREF : PREFERENCE_PAGE
{
	CheckButton 	mEnabled;

	this()
	{
		//using same simple glade file for proview  -- maybe change name to generice simple glade ??
		super("Elements", Config.getString("PREFERENCES", "glade_file_history_view", "$(HOME_DIR)/glade/proviewpref.glade"));
		mEnabled = cast (CheckButton)mBuilder.getObject("checkbutton1");
		Label  x = cast (Label)      mBuilder.getObject("label1");
		x.setMarkup("<b>Recent History :</b>");

		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setBoolean("HISTORY_VIEW", "enabled", mEnabled.getActive());
	}

	override void PrepGui()
	{
		mEnabled.setActive(Config.getBoolean("HISTORY_VIEW", "enabled", true));
	}
} 

