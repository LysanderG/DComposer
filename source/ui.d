module ui;

import std.conv;
import std.traits; 

import quore;
import config;


import ui_docbook;

import gtk.CheckMenuItem;
import gtk.AccelLabel;
import gio.SimpleAction;
import gdk.Event;
import gio.ActionIF;
import gio.ActionMapIF;
import gio.Application : GApplication = Application;
import gio.ActionGroupIF;
import gio.Cancellable;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import glib.Variant;
import glib.VariantType;
import gtk.AccelGroup;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Builder;
import gtk.Button;
import gtk.IconFactory;
import gtk.Main;
import gtk.Menu;
import gtk.MenuBar;
import gtk.MenuItem;
import gtk.MessageDialog;
import gtk.Notebook;
import gtk.Toolbar;
import gtk.Widget;
import gtk.Window;



void Engage(string[] args)
{
	mApplication = new Application("dcomposer.com", GApplicationFlags.NON_UNIQUE);
	mApplication.register(new Cancellable());
	
	auto mBuilder = new Builder;
    mBuilder.addFromFile(config.findResource(Config.GetValue("ui", "ui_main_window", "glade/ui_main.glade"))); 
    

	mApplication.addOnActivate(delegate void(GApplication app)
	{
    	EngageMainWindow(mBuilder);
    	EngageMenuBar(mBuilder);    	

    	EngageToolBar(mBuilder);
    	EngageSidePane(mBuilder);
    	EngageExtraPane(mBuilder);
    	EngageStatusBar(mBuilder);
    	EngageDocBook(mBuilder);
    	    	
    });
	
	Log.Entry("Engaged");
}

void Mesh()
{
    Log.Entry("Meshed");
}

void Disengage()
{
    Log.Entry("Disengaged");
}

void run(string[] args)
{
	Log.Entry("++++++ Entering GTK Main Loop ++++++");
	mApplication.run(args);
	Log.Entry("------  Exiting GTK Main Loop ------");
	
}


//================================================================
private:
Application         mApplication;
ApplicationWindow 	mMainWindow;
MenuBar             mMenuBar;
CheckMenuItem       miViewMenubar;
CheckMenuItem       miViewSidepane;
CheckMenuItem       miViewExtrapane;
Toolbar             mToolbar;
Notebook 			mSidePane;
Notebook 			mExtraPane;
Box                 mStatusBox;
UI_DOCBOOK 			mDocBook;

void EngageMainWindow(Builder mBuilder)
{
	mMainWindow = cast(ApplicationWindow) mBuilder.getObject("main_window");
	
    mApplication.addWindow(mMainWindow);

	mMainWindow.addOnDelete(delegate bool(Event Ev, Widget wdgt)
	{
    	if(ConfirmQuit())mApplication.quit();
    	return true;
		
	});
	mMainWindow.showAll();

}


void EngageMenuBar(Builder mBuilder)
{
    mMenuBar = cast(MenuBar)mBuilder.getObject("menu_bar");
    miViewMenubar = cast(CheckMenuItem)mBuilder.getObject("view_menubar");
    miViewSidepane = cast(CheckMenuItem)mBuilder.getObject("view_sidepane");
    miViewExtrapane = cast(CheckMenuItem)mBuilder.getObject("view_extrapane");

//quit
    GActionEntry[] ag = [{"actionQuit", &action_quit,null, null, null}];
    mMainWindow.addActionEntries(ag, null);
    mApplication.setAccelsForAction("win.actionQuit",["<Control>q"]);
//pref
    GActionEntry aePref = {"actionPreferences", &action_preferences, null, null, null};
    mMainWindow.addActionEntries([aePref], null);
    mApplication.setAccelsForAction("win.actionPreferences", ["<Control>p"]);
//views
    GActionEntry[] aevViews =[
        {"actionViewMenubar",   &action_view_menubar,   null, null, null},
        {"actionViewToolbar",   &action_view_toolbar,   null, null, null},
        {"actionViewSidepane",  &action_view_sidepane,  null, null, null},
        {"actionViewExtrapane", &action_view_extrapane, null, null, null}
        ];
    mMainWindow.addActionEntries(aevViews, null);
    mApplication.setAccelsForAction("win.actionViewMenubar", ["<Control><Shift>m"]);
    mApplication.setAccelsForAction("win.actionViewToolbar", ["<Control><Shift>t"]);
    mApplication.setAccelsForAction("win.actionViewSidepane", ["<Control><Shift>s"]);
    mApplication.setAccelsForAction("win.actionViewExtrapane",["<Control><Shift>x"]);
    


    mMenuBar.showAll();
}


void EngageToolBar(Builder mBuilder)
{
	mToolbar = cast(Toolbar)mBuilder.getObject("tool_bar");
}


void EngageSidePane(Builder mBuilder)
{
	mSidePane = cast(Notebook)mBuilder.getObject("side_pane");
}

void EngageExtraPane(Builder mBuilder)
{
	mExtraPane = cast(Notebook)mBuilder.getObject("extra_pane");
}

void EngageStatusBar(Builder mBuilder)
{
	mStatusBox = cast(Box)mBuilder.getObject("status_box");
}

void EngageDocBook(Builder mBuilder)
{
	mDocBook = new UI_DOCBOOK;
	mDocBook.Engage(mBuilder);
}

bool ConfirmQuit()
{
	bool mQuitting = true;
    auto ModdedDocs = true; //DocMan.Modified();
    //DocMan.SaveSessionDocuments();
    if(ModdedDocs) with (ResponseType)
    {
        //confirm quit or return
        auto ConfQuit = new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, false, "");
        ConfQuit.setTitle("Quit DComposer?");
        ConfQuit.setMarkup("Do you really wish to quit with " ~ to!string(ModdedDocs) ~ " modified documents?");
        ConfQuit.addButtons(["Save all & quit", "Discard all & quit", "Pick & choose", "Oops, don't quit!!"], [YES, NO,OK,CANCEL]);
        auto response = ConfQuit.run();
        ConfQuit.destroy();
        switch (response)
        {
            //saveall & quit
            case YES : break;//DocMan.SaveAll();break;
            //discard changes & quit
            case NO  : break;
            //pick & choose & quit (or do not quit if modified docs haven't been closed)
            case OK  : //DocMan.CloseAll();
                       //if(!DocMan.Empty)
                       //{
	                   //    mQuitting = false;
	                   //    return;
                       //}
                       break;
            //any other response do nothing return to editting
            default  : 
        			   mQuitting = false;
        }

    }
    return mQuitting;
}

enum ROOT :string
{
    SYSTEM  = "System",
    VIEW    = "View",
    EDIT    = "Edit",
    DOCUMENT= "Document",
    PROJECT = "Project",
    TOOLS   = "Tools",
    ELEMENTS= "Elements",
    HELP    = "Help",
}


//action callbacks from gtk ... so extern c
extern (C)
{
    void action_quit(void* sa, void* v, void * vptr)
    {
       if(ConfirmQuit())mApplication.quit();
    }
    
    void action_preferences(void* simAction, void* varTarget, void* voidUserData)
    {
        auto x = new MessageDialog(mMainWindow, GtkDialogFlags.MODAL,GtkMessageType.INFO, GtkButtonsType.CLOSE,"Preferences",null);
        x.run();
        dwrite("preferences menu activated");
        x.close();
        x.destroy();
    }
    
    void action_view_menubar(void* simAction, void* varTarget, void* voidUserData)
    { 
        mMenuBar.setVisible(!mMenuBar.getVisible());
        dwrite("action view menubar");
    }
    void action_view_toolbar(void* simAction, void* varTarget, void* voidUserData)
    {
        mToolbar.setVisible(!mToolbar.getVisible());
        dwrite("action view toolbar");
    }
    void action_view_sidepane(void* simAction, void* varTarget, void* voidUserData)
    {
        mSidePane.setVisible(!mSidePane.getVisible());
        dwrite("action view sidepane");
    }
    void action_view_extrapane(void* simAction, void* varTarget, void* voidUserData)
    {
        mExtraPane.setVisible(!mExtraPane.getVisible());
        dwrite("action view extrapane");
    }
}
