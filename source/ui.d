module ui;

import std.conv;
import std.traits; 

import qore;
import config;


import ui_docbook;
import ui_toolbar;

import gdk.Event;
import gio.ActionGroupIF;
import gio.ActionIF;
import gio.ActionMapIF;
import gio.Application : GApplication = Application;
import gio.Cancellable;
import gio.Menu : GMenu = Menu;
import gio.MenuItem : GMenuItem = MenuItem;
import gio.MenuModel;
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



void Engage(ref string[] args)
{
	mApplication = new Application("dcomposer.com", GApplicationFlags.NON_UNIQUE);
	mApplication.register(new Cancellable());
	
	auto mBuilder = new Builder;
    mBuilder.addFromFile(config.findResource(Config.GetValue("ui", "ui_main_window", "glade/ui_main2.glade"))); 
    
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
    MeshDocBook();
    Log.Entry("Meshed");
}

void Disengage()
{
    DisengageDocBook();
    DisengageExtraPane();
    DisengageSidePane();
    DisengageToolbar();
    DisengageMenubar();
    
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

Application         mApplication;
ApplicationWindow 	mMainWindow;
UI_DOCBOOK 			mDocBook;
//================================================================
private:
MenuBar             mMenuBar;
GMenu               mMenubarModel;
CheckMenuItem       miViewMenubar;
CheckMenuItem       miViewSidepane;
CheckMenuItem       miViewExtrapane;
Notebook 			mSidePane;
Notebook 			mExtraPane;
Box                 mStatusBox;
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
	
    mVerticalPane = cast(Paned)mBuilder.getObject("root_pane");
	mHorizontalPane = cast(Paned)mBuilder.getObject("secondary_pane");
	
	mMainWindow.move(win_x_pos, win_y_pos);
	mMainWindow.resize(win_x_len, win_y_len);
	Log.Entry("\tMain Window Engaged");

}

//menubar stuff
void EngageMenuBar(Builder mBuilder)
{
    mMenubarModel = new GMenu();
    
    mMenuBar = cast(MenuBar)mBuilder.getObject("menu_bar");
    GMenu menuSystem = new GMenu();
    GMenu menuViews = new GMenu();
    
    //miViewMenubar = cast(CheckMenuItem)mBuilder.getObject("view_menubar");
    //miViewSidepane = cast(CheckMenuItem)mBuilder.getObject("view_sidepane");
    //miViewExtrapane = cast(CheckMenuItem)mBuilder.getObject("view_extrapane");

//==> System Menu
//quit
    GActionEntry[] ag = [{"actionQuit", &action_quit,null, null, null}];
    mMainWindow.addActionEntries(ag, null);
    mApplication.setAccelsForAction("win.actionQuit",["<Control>q"]);
    AddToolObject("quit", "Quit", "Exit DComposer", Config.GetResource("icon","quit","resource","yin-yang.png"),"win.actionQuit");
    GMenuItem menuQuit = new GMenuItem("Quit", "actionQuit");
//pref
    GActionEntry aePref = {"actionPreferences", &action_preferences, null, null, null};
    mMainWindow.addActionEntries([aePref], null);
    mApplication.setAccelsForAction("win.actionPreferences", ["<Control>p"]);
    AddToolObject("preferences","Preferences","Edit Preferences", Config.GetResource("icon","preferences", "resource", "gear.png"), "win.actionPreferences");
    GMenuItem menuPref = new GMenuItem("Preferences", "actionPreferences");
    
    mMenubarModel.insertSubmenu(0,"System",menuSystem);
    menuSystem.appendItem(menuQuit); 
    menuSystem.appendItem(menuPref);   

    

//views
    GActionEntry[] aevViews =[
        {"actionViewMenubar",   &action_view_menubar,   "b", "true", null},
        {"actionViewToolbar",   &action_view_toolbar,   "b", "true", null},
        {"actionViewSidepane",  &action_view_sidepane,  "b", "true", null},
        {"actionViewExtrapane", &action_view_extrapane, "b", "true", null}
        ];
    mMainWindow.addActionEntries(aevViews, null);
    mApplication.setAccelsForAction("win.actionViewMenubar(true)", ["<Control><Shift>m"]);
    mApplication.setAccelsForAction("win.actionViewToolbar(true)", ["<Control><Shift>t"]);
    mApplication.setAccelsForAction("win.actionViewSidepane(true)", ["<Control><Shift>s"]);
    mApplication.setAccelsForAction("win.actionViewExtrapane(true)",["<Control><Shift>x"]);
    
    
    mMenubarModel.insertSubmenu(1, "Views", menuViews);
    menuViews.appendItem(new GMenuItem("Menubar","actionViewMenubar(true)"));
    menuViews.appendItem(new GMenuItem("Toolbar","actionViewToolbar(true)"));
    menuViews.appendItem(new GMenuItem("Sidepane","actionViewSidepane(true)"));
    menuViews.appendItem(new GMenuItem("Extrapane","actionViewExtrapane(true)"));
    mMenuBar.showAll();
    mMenuBar.setVisible(Config.GetValue("ui_menubar", "visible",true));
    
    Log.Entry("\tMenubar Engaged");
}
void MeshMenubar()
{
    mMenuBar.bindModel(mMenubarModel, "win", true);
    //mMainWindow.setShowMenubar(true);
	Log.Entry("\tMenubar Meshed");
}
void DisengageMenubar()
{
    //Config.SetValue("ui_menubar", "visible", mMenuBar.getVisible());
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
	mVerticalPane.setPosition(Config.GetValue("ui", "sidepane_pos", 10));
    Log.Entry("\tSidePane Meshed");
}
void DisengageSidePane()
{
    Config.SetValue("ui","sidepane_pos", mVerticalPane.getPosition());
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
	mHorizontalPane.setPosition(Config.GetValue("ui","extrapane_pos", 10));
    Log.Entry("\tExtraPane Meshed");
}
void DisengageExtraPane()
{
    
    Config.SetValue("ui_extrapane", "visible", mExtraPane.getVisible());
    Config.SetValue("ui","extrapane_pos",mHorizontalPane.getPosition());
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
void MeshDocBook()
{
    mDocBook.Mesh();
}
void DisengageDocBook()
{
    mDocBook.Disengage();
}
bool ConfirmQuit()
{
	bool mQuitting = true;
    auto ModdedDocs = docman.GetModifiedDocs();
    dwrite(docman.GetModifiedDocs());
    //DocMan.SaveSessionDocuments();
    if(!ModdedDocs.empty) with (ResponseType)
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
            case YES : mDocBook.SaveAll();break;
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
       if(ConfirmQuit())mApplication.quit;
    }
    
    void action_preferences(void* simAction, void* varTarget, void* voidUserData)
    {
        auto x = new MessageDialog(mMainWindow, GtkDialogFlags.MODAL,GtkMessageType.INFO, GtkButtonsType.CLOSE,"Preferences",null);
        x.run();
        dwrite("preferences menu activated");
        x.close();
        x.destroy();
    }
    
    void action_view_menubar(GSimpleAction* simAction, GVariant* varTarget, void* voidUserData)
    { 
        SimpleAction sa = new SimpleAction(simAction);
        Variant v = new Variant(varTarget);
        mMenuBar.setVisible(!mMenuBar.getVisible());
        sa.setState(new Variant(mMenuBar.getVisible()));
        dwrite("action view menubar");
    }
    void action_view_toolbar(GSimpleAction* simAction, GVariant* varTarget, void* voidUserData)
    {
        SimpleAction sa = new SimpleAction(simAction);
        Variant v = new Variant(varTarget);
        mToolbar.setVisible(!mToolbar.getVisible());
        sa.setState(new Variant(mToolbar.getVisible()));
        dwrite("action view toolpane");
    }
    void action_view_sidepane(GSimpleAction* simAction, GVariant* varTarget, void* voidUserData)
    {
        SimpleAction sa = new SimpleAction(simAction);
        Variant v = new Variant(varTarget);
        mSidePane.setVisible(!mSidePane.getVisible());
        sa.setState(new Variant(mSidePane.getVisible()));
        dwrite("action view sidepane");
    }
    void action_view_extrapane(GSimpleAction* simAction, GVariant* varTarget, void* voidUserData)
    {
        SimpleAction sa = new SimpleAction(simAction);
        Variant v = new Variant(varTarget);
        mExtraPane.setVisible(!mExtraPane.getVisible());
        sa.setState(new Variant(mExtraPane.getVisible()));
        dwrite("action view extra");
    }
}
