module ui;

import std.conv;
import std.traits; 

import quore;
import config;


import ui_docbook;
import ui_toolbar;

import gdk.Event;
import gio.ActionGroupIF;
import gio.ActionIF;
import gio.ActionMapIF;
import gio.Application : GApplication = Application;
import gio.Cancellable;
import gio.SimpleAction;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import glib.Variant;
import glib.VariantType;
import gtk.AccelGroup;
import gtk.AccelLabel;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Box;
import gtk.Builder;
import gtk.Button;
import gtk.CheckMenuItem;
import gtk.IconFactory;
import gtk.Main;
import gtk.Menu;
import gtk.MenuBar;
import gtk.MenuItem;
import gtk.MessageDialog;
import gtk.Notebook;
import gtk.Paned;
import gtk.Toolbar;
import gtk.Widget;
import gtk.Window;



void Engage(string[] args)
{
	mApplication = new Application("dcomposer.com", GApplicationFlags.NON_UNIQUE);
	mApplication.register(new Cancellable());
	
	auto mBuilder = new Builder;
    mBuilder.addFromFile(config.findResource(Config.GetValue("ui", "ui_main_window", "glade/ui_main.glade"))); 
    
    EngageMainWindow(mBuilder);
    EngageMenuBar(mBuilder);    	

    EngageToolbar(mBuilder);
    EngageSidePane(mBuilder);
    EngageExtraPane(mBuilder);
    EngageStatusbar(mBuilder);
    EngageDocBook(mBuilder);

	mApplication.addOnActivate(delegate void(GApplication app)
	{
    });


	
	Log.Entry("Engaged");
}

void Mesh()
{ 
    MeshMenubar();
    MeshToolbar();
    MeshSidePane();
    MeshExtraPane();
    Log.Entry("Meshed");
}

void Disengage()
{
 
    DisengageExtraPane();
    DisengageSidePane();
    DisengageToolbar();
    DisengageMenubar();
    
    Config.SetValue("ui","vertical_pane_pos", mVerticalPane.getPosition());
    Config.SetValue("ui","horizontal_pane_pos", mHorizontalPane.getPosition());
    
    int win_x_pos, win_y_pos;
    int win_x_len, win_y_len;
    
    mMainWindow.getPosition(win_x_pos, win_y_pos);
    mMainWindow.getSize(win_x_len, win_y_len);
    
    Config.SetValue("ui", "win_x_pos", win_x_pos);
    Config.SetValue("ui", "win_y_pos", win_y_pos);
    Config.SetValue("ui", "win_x_len", win_x_len);
    Config.SetValue("ui", "win_y_len", win_y_len);
    Log.Entry("Disengaged");
}

void run(string[] args)
{
	Log.Entry("++++++ Entering GTK Main Loop ++++++");
	mApplication.run(args);
	Log.Entry("------  Exiting GTK Main Loop ------");
	
}

Application GetApp(){return mApplication;}
ApplicationWindow GetWin(){return mMainWindow;}

//================================================================
private:
Application         mApplication;
ApplicationWindow 	mMainWindow;
MenuBar             mMenuBar;
CheckMenuItem       miViewMenubar;
CheckMenuItem       miViewSidepane;
CheckMenuItem       miViewExtrapane;
Notebook 			mSidePane;
Notebook 			mExtraPane;
Box                 mStatusBox;
UI_DOCBOOK 			mDocBook;
Paned               mVerticalPane;
Paned               mHorizontalPane;

void EngageMainWindow(Builder mBuilder)
{
	mMainWindow = cast(ApplicationWindow) mBuilder.getObject("main_window");
	
    mApplication.addWindow(mMainWindow);

	mMainWindow.addOnDelete(delegate bool(Event Ev, Widget wdgt)
	{
    	if(ConfirmQuit())mApplication.quit();
    	return true;
		
	});
	
    int win_x_pos = Config.GetValue("ui", "win_x_pos", 10);
	int win_y_pos = Config.GetValue("ui", "win_y_pos", 10);
	int win_x_len = Config.GetValue("ui", "win_x_len", 200);
	int win_y_len = Config.GetValue("ui", "win_y_len", 200);
	
	mMainWindow.getWindow().moveResize(win_x_pos,win_y_pos,win_x_len,win_y_len);
	
    mVerticalPane = cast(Paned)mBuilder.getObject("root_pane");
	mHorizontalPane = cast(Paned)mBuilder.getObject("secondary_pane");
	mVerticalPane.setPosition(Config.GetValue("ui", "vertical_pane_pos", 10));
	mHorizontalPane.setPosition(Config.GetValue("ui","horizontal_pane_pos", 10));
	Log.Entry("\tMain Window Engaged");

}

//menubar stuff
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
    AddToolObject("quit", "Quit", "Exit DComposer", Config.GetResource("system","quit_icon","resource","yin-yang.png"),"win.actionQuit");

//pref
    GActionEntry aePref = {"actionPreferences", &action_preferences, null, null, null};
    mMainWindow.addActionEntries([aePref], null);
    mApplication.setAccelsForAction("win.actionPreferences", ["<Control>p"]);
    AddToolObject("preferences","Preferences","Edit Preferences", Config.GetResource("system","preferences_icon", "resource", "gear.png"), "win.actionPreferences");
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
    mMenuBar.setVisible(Config.GetValue("ui_menubar", "visible",true));
    
    Log.Entry("\tMenubar Engaged");
}
void MeshMenubar()
{
	Log.Entry("\tMenubar Meshed");
}
void DisengageMenubar()
{
    Config.SetValue("ui_menubar", "visible", mMenuBar.getVisible());
    Log.Entry("\tMenubar Disengaged");
}

//side pane stuff
void EngageSidePane(Builder mBuilder)
{
	mSidePane = cast(Notebook)mBuilder.getObject("side_pane");
	mSidePane.setVisible(Config.GetValue("ui_sidepane","visible", true));
	
	Log.Entry("\tSidePane Engaged");
}
void MeshSidePane()
{
    Log.Entry("\tSidePane Meshed");
}
void DisengageSidePane()
{
    Config.SetValue("ui_sidepane", "visible", mSidePane.getVisible());
    Log.Entry("\tSidePane Disengaged");
}

//Extra Pane stuff
void EngageExtraPane(Builder mBuilder)
{
	mExtraPane = cast(Notebook)mBuilder.getObject("extra_pane");
	mExtraPane.setVisible(Config.GetValue("ui_extrapane","visible",true));
    Log.Entry("\tExtraPane Engaged");
}
void MeshExtraPane()
{
    Log.Entry("\tExtraPane Meshed");
}
void DisengageExtraPane()
{
    
    Config.SetValue("ui_extrapane", "visible", mExtraPane.getVisible());
    Log.Entry("\tExtraPane Disengaged");
}


void EngageStatusbar(Builder mBuilder)
{
	mStatusBox = cast(Box)mBuilder.getObject("status_box");
	Log.Entry("\tStatusbar Engaged");	
}
void MeshStatusbar()
{
    Log.Entry("\tStatusbar Meshed");
}
void DisengageStatusbar()
{
    Log.Entry("\tStatusbar Disengaged");
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
