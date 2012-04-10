// preferences.d
// 
// Copyright 2012 Anthony Goins <anthony@LinuxGen11>
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
// MA 02110-1301, USA.

module preferencesui;

import dcore;
import ui;
import elements;

import std.stdio;

import gtk.Builder;
import gtk.VBox;
import gtk.Notebook;
import gtk.Label;
import gtk.Action;
import gtk.CheckButton;
import gtk.Frame;
import gtk.Entry;
import gtk.CellEditableIF;
import gtk.Alignment;
import gtk.SpinButton;




class PREFERENCES_UI : ELEMENT
{
    private:

    string          mName;
    string          mInfo;
    bool            mState;

    bool            mGuiBuilt;
    Builder         mBuilder;
    VBox            mRoot;
    Notebook        mBook;
    VBox[string]    mPage;


    void ShowPrefPage()
    {
        if(!mGuiBuilt) BuildGui();
        mRoot.show();
        dui.GetCenterPane().setCurrentPage(mRoot);
    }


    void BuildGui()
    {
        AddCorePrefs();
        AddUIPrefs();
        AddElementPrefs();
    }

    void AddCorePrefs()
    {
        auto ConfPrefs = new CONFIG_PAGE("Core", "Configuration File :");
        AddPrefPart(ConfPrefs);
        auto LogPrefs  = new LOG_PAGE("Core", "Logging :");
        AddPrefPart(LogPrefs);

    }

    void AddUIPrefs()
    {
    }

    void AddElementPrefs()
    {
    }

    void AddPrefPart(PREFERENCE_PAGE X)
    {
        if(X.PageName in mPage)
        {
            mPage[X.PageName].add(X.GetPrefWidget());
        }
        else
        {
            mPage[X.PageName] = new VBox(1,1);
            mPage[X.PageName].add(X.GetPrefWidget());
            mBook.appendPage(mPage[X.PageName], X.PageName);
        }
        mPage[X.PageName].showAll();
    }
    
    public :
    

    this()
    {
        mName = "PREFERENCES_UI";
        mInfo = "Dialog to set program preferences.";

        mGuiBuilt = false;

        Action  ShowPrefAct = new Action("ShowPrefAct", "Preferences", "Set program options", "gtk-preferences");
        ShowPrefAct.addOnActivate(delegate void (Action x){ShowPrefPage();});
        ShowPrefAct.setAccelGroup(dui.GetAccel());
        dui.Actions.addActionWithAccel(ShowPrefAct, "<Ctrl>P");
        dui.AddMenuItem("_System", ShowPrefAct.createMenuItem(), 0);
    }
    
    @property string Name(){return mName;}
    @property string Information(){return mInfo;}
    @property bool   State(){return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        (mState) ? Engage() : Disengage();
    }

    void Engage()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("PREFERENCES", "glade_file", "~/.neontotem/dcomposer/preferences.glade"));

        mRoot   =   cast(VBox)  mBuilder.getObject("root");
        mBook   =   cast(Notebook)mBuilder.getObject("notebook");
        

        dui.GetCenterPane.prependPage(mRoot, new Label("Preferences"));
        
        
	    Log.Entry("Engaged PREFERENCES_UI element");
    }

    void Disengage()
    {
	    Log.Entry("Disengaged PREFERENCES_UI");
    }


    Frame GetPreferenceWidget()
    {
        //of course preferences has no preferences page
        return null;
    }
}






class PREFERENCE_PAGE
{
    string      mPageName;
    
    Builder     mBuilder;
    Frame       mFrame;
    Alignment   mFrameKid;

    this(string PageName, string gladefile)
    {
        mPageName = PageName;
        
        mBuilder = new Builder;
        mBuilder.addFromFile(gladefile);

        mFrame = cast(Frame)mBuilder.getObject("frame");

        mFrameKid = cast(Alignment)mBuilder.getObject("alignment1");
    }

    Frame GetPrefWidget()
    {
        return mFrame;
    }
    string PageName()
    {
        return mPageName;
    }
    
}
        


class CONFIG_PAGE :PREFERENCE_PAGE
{
    Entry   mEntry;

    this(string PageName, string SectionName)
    {
        super(PageName, Config.getString("PREFERENCES", "glade_file_config", "~/.neontotem/dcomposer/configpref.glade"));
        mFrame.setLabel(SectionName);
        mEntry = cast(Entry) mBuilder.getObject("entry1");
        mEntry.setText(Config.getString("CONFIG", "this_file", ""));
        
        mFrameKid.add(mEntry);

        mEntry.addOnEditingDone(delegate void(CellEditableIF EditCell){Log.Entry("Preferences Test " ~ mEntry.getText());});
        mEntry.addOnActivate(delegate void(Entry x){Log.Entry("Preferences Test " ~ mEntry.getText());});

        mFrame.showAll();
    }
}


class LOG_PAGE : PREFERENCE_PAGE
{
    Entry       mEntry;
    SpinButton  mMaxSize;
    SpinButton  mMaxLines;
    this(string PageName, string SectionName)
    {
        super(PageName, Config.getString("PREFERENCES", "glade_file_log", "~/.neontotem/dcomposer/logpref.glade"));
        mEntry      = cast(Entry) mBuilder.getObject("entry1");
        mMaxSize    = cast(SpinButton) mBuilder.getObject("spinbutton1");
        mMaxLines   = cast(SpinButton) mBuilder.getObject("spinbutton2");
        

        
        mEntry.setText(Config.getString("LOG", "default_log_file", "~/.neontotem/dcomposer/dcomposer.log"));
        
        mMaxSize.setRange(ulong.min, ulong.max);
        mMaxSize.setIncrements(1024, 102400);
        mMaxSize.setValue(cast(double) Config.getInteger("LOG", "max_file_size", 23));

        mMaxLines.setRange(ulong.min, ulong.max);
        mMaxLines.setIncrements(1, 10);
        mMaxLines.setValue(cast(double) Config.getInteger("LOG", "max_lines_buffer", 234));        
        mFrame.showAll();
    }
}
        
    
    

