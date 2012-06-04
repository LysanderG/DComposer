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
import docman;

import std.stdio;
import std.path;
import std.string;

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
import gtk.ScrolledWindow;
import gtk.Button;
import gtk.TextView;
import gtk.ToggleButton;

import gdk.Display;
import gdk.Cursor;



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
    PREFERENCE_PAGE[] mObjects;
    Button          mApplyBtn;
    Button          mDiscardBtn;
    


    void ShowPrefPage()
    {
        
        if(!mGuiBuilt) BuildGui();
        mRoot.show();
        dui.GetExtraPane().setCurrentPage(mRoot);

    }


    void BuildGui()
    {
        AddCorePrefs();
        AddUIPrefs();
        AddElementPrefs();

        mGuiBuilt = true;
    }

    void AddCorePrefs()
    {
		auto ConfPrefs = new CONFIG_PAGE("Core", "Configuration File :");
		mObjects ~= ConfPrefs;
		AddPrefPart(ConfPrefs);
	
		auto LogPrefs  = new LOG_PAGE("Core", "Logging :");
		mObjects ~= LogPrefs;
		AddPrefPart(LogPrefs);

        auto SymbolPrefs = new SYMBOL_PAGE("Core", "Symbols :");
        mObjects ~= SymbolPrefs;
        AddPrefPart(SymbolPrefs);

    }

    void AddUIPrefs()
    {
        auto DocPrefs = new DOC_PAGE("Documents", "Editor :");
        mObjects ~= DocPrefs;
        AddPrefPart(DocPrefs);
    }

    void AddElementPrefs()
    {
        foreach( element; mElements)
        {
            auto tmpobj = element.GetPreferenceObject();
            if(tmpobj is null) continue;
            mObjects ~= tmpobj;
            AddPrefPart(tmpobj);
        }

    }

    void AddPrefPart(PREFERENCE_PAGE X)
    {
        if(X.PageName in mPage)
        {
            mPage[X.PageName].add(X.GetPrefWidget());
            mPage[X.PageName].setChildPacking (X.GetPrefWidget(), X.Expand(), 1, 0, GtkPackType.START); 
        }
        else
        {
            ScrolledWindow sw = new ScrolledWindow;
            sw.show();
            sw.setPolicy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            mPage[X.PageName] = new VBox(1,1);
            mPage[X.PageName].add(X.GetPrefWidget());
            mPage[X.PageName].setHomogeneous(0);
            sw.addWithViewport(mPage[X.PageName]);
			mPage[X.PageName].setChildPacking (X.GetPrefWidget, X.Expand(),1, 0, GtkPackType.START); 
            
            
            
            mBook.appendPage(sw, X.PageName);
        }
        mPage[X.PageName].showAll();
    }
    void ApplyChanges()
    {
		//set cursor to a busy cursor 
        int xx, yy;
        auto watch = new Cursor(GdkCursorType.WATCH);
        auto tmpwindow = Display.getDefault.getWindowAtPointer(xx,yy);
        tmpwindow.setCursor(watch);
        Display.getDefault.sync();
        watch.unref();


        foreach(obj; mObjects)
        {
            writeln( "prefs >>",obj.PageName);
            obj.Apply;
        }

        Config.Reconfigure();

        //restore default cursor
        tmpwindow.setCursor(null);
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

        mRoot       =   cast(VBox)      mBuilder.getObject("root");
        mBook       =   cast(Notebook)  mBuilder.getObject("notebook");
        mApplyBtn   =   cast(Button)    mBuilder.getObject("applybtn");
        mDiscardBtn =   cast(Button)    mBuilder.getObject("discardbtn");

        mApplyBtn.addOnClicked(delegate void(Button X){ApplyChanges();});
        mDiscardBtn.addOnClicked(delegate void(Button X){mRoot.hide();Log.Entry("discard preferences","Debug");});

        //dui.GetCenterPane.prependPage(mRoot, new Label("Preferences"));
        dui.GetExtraPane.prependPage(mRoot, new Label("Preferences"));
        
	    Log.Entry("Engaged PREFERENCES_UI element");
    }

    void Disengage()
    {
	    Log.Entry("Disengaged PREFERENCES_UI");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        //of course preferences has no preferences page
        return null;
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
        
        //mFrameKid.add(mEntry);

        mEntry.addOnEditingDone(delegate void(CellEditableIF EditCell){Log.Entry("Preferences Test " ~ mEntry.getText());});
        mEntry.addOnActivate(delegate void(Entry x){Log.Entry("Preferences Test " ~ mEntry.getText());});

        mFrame.showAll();
    }

    override void Apply()
    {
        Config.setString("CONFIG", "this_file", mEntry.getText());
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

    override void Apply()
    {
        Config.setString("LOG", "default_log_file", mEntry.getText());
        Config.setInteger("LOG", "max_file_size", mMaxSize.getValueAsInt());
        Config.setInteger("LOG", "max_lines_buffer", mMaxLines.getValueAsInt());
    }
    
}

class SYMBOL_PAGE : PREFERENCE_PAGE
{
    CheckButton mCheckBtn;
    LISTUI      mTagFiles;
    //VBox        mVBox;
    

    this(string PageName, string SectionName)
    {
        string listgladefile = expandTilde(Config.getString("PROJECT", "list_glad_file", "~/.neontotem/dcomposer/multilist.glade"));
        
        super(PageName, Config.getString("PREFERENCES", "glade_file_symbols", "~/.neontotem/dcomposer/symbolpref.glade"));

        mTagFiles = new LISTUI("Symbol files to load at start up", ListType.FILES, listgladefile);

        

        mCheckBtn   = cast(CheckButton) mBuilder.getObject("checkbutton1");

        mTagFiles.ClearItems(null);
        string[] ItemstoSet;
        foreach(key; Config.getKeys("SYMBOL_LIBS"))
        {
            ItemstoSet ~=Config.getString("SYMBOL_LIBS", key);
        }
        mTagFiles.SetItems(ItemstoSet);
            
            

        mCheckBtn.setActive(Config.getBoolean("SYMBOLS", "auto_load_project_symbols", 1));

        mTagFiles.GetWidget.setSensitive(mCheckBtn.getActive());

        mCheckBtn.addOnToggled(delegate void(ToggleButton x){mTagFiles.GetWidget.setSensitive(mCheckBtn.getActive());});
                
        
        Add(mTagFiles.GetWidget());
        //mVBox.setChildPacking (mTagFiles.GetWidget(), 1,1, 0, GtkPackType.START); 
        
        mFrame.showAll();
    }

    override void Apply()
    {
        Config.setBoolean("SYMBOLS", "auto_load_project_symbols", mCheckBtn.getActive());

        string[] Names = mTagFiles.GetShortItems();
        string[] Files = mTagFiles.GetFullItems();

        if(Config.hasGroup("SYMBOL_LIBS"))Config.removeGroup("SYMBOL_LIBS");
        foreach(int i, name; Names)
        {
            name = name.chomp("lib.json");
            Config.setString("SYMBOL_LIBS", name, Files[i]);
        }
    }
    override bool Expand(){return true;}
}
