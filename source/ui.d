module ui;

import std.conv;
import std.traits; 

import quore;
import config;


import ui_docbook;

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
	mApplication = new Application("dcomposer.com", GApplicationFlags.FLAGS_NONE);
	mApplication.register(new Cancellable());
	
	auto mBuilder = new Builder;
    mBuilder.addFromFile(config.findResource(Config.GetValue("ui", "ui_main_window", "glade/ui_main.glade"))); 
    

    mAccelGroup =  cast(AccelGroup)mBuilder.getObject("accel_group");
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
AccelGroup          mAccelGroup;
IconFactory 		mIconFactory;


SimpleAction mQuitAction;
void EngageMainWindow(Builder mBuilder)
{
	mMainWindow = cast(ApplicationWindow) mBuilder.getObject("main_window");
	mAccelGroup = cast(AccelGroup) mBuilder.getObject("accel_group");
	
    mApplication.addWindow(mMainWindow);
    
    
	
	mMainWindow.addOnDelete(delegate bool(Event Ev, Widget wdgt)
	{
    	if(Quit())mApplication.quit();
    	return true;
		
	});
	mMainWindow.showAll();

}

MenuBar mMenuBar;
Menu[string] mRootMenus;
void EngageMenuBar(Builder mBuilder)
{
    mMenuBar = cast(MenuBar)mBuilder.getObject("menu_bar");
    
    foreach(string rootname; EnumMembers!ROOT)
    {
        mRootMenus[rootname] = mMenuBar.append(rootname);
        mRootMenus[rootname].setAccelGroup(mAccelGroup);
        mRootMenus[rootname].setAccelPath("<dcomposer>/" ~ rootname);
    }
    
GtkShortcutsWindow scw;
        GtkShortcutsWindow * scwp;
    auto quitMenuItem = new MenuItem("Quit", delegate void (MenuItem mi)
    {
        import gtk.ShortcutsWindow;
        
        ShortcutsWindow helpoverlay = new ShortcutsWindow(swcp);
        
        mMainWindow.setHelpOverlay(helpoverlay);
        //helpoverlay = mMainWindow.getHelpOverlay();
        dwrite(helpoverlay);
        helpoverlay.present();
        if(Quit())
        {
            mApplication.quit();
        }
    }
    , "app.actQuit");
    auto accLabel = cast(AccelLabel)quitMenuItem.getChild();
    accLabel.setAccel('q', GdkModifierType.CONTROL_MASK);
    accLabel.setAccelWidget(cast(Widget)mApplication);


    mRootMenus[ROOT.SYSTEM].append(quitMenuItem); 

    quitMenuItem.addAccelerator("activate", mAccelGroup, 'q', GdkModifierType.CONTROL_MASK, GtkAccelFlags.VISIBLE);
    quitMenuItem.setAccelPath("<dcomposer>/System/Quit");
    quitMenuItem.setSensitive(true);


    
    dwrite(mApplication.listActionDescriptions());

    mMenuBar.showAll();
}

Toolbar mToolbar;
void EngageToolBar(Builder mBuilder)
{
	mToolbar = cast(Toolbar)mBuilder.getObject("tool_bar");
}


Notebook mSidePane;
void EngageSidePane(Builder mBuilder)
{
	mSidePane = cast(Notebook)mBuilder.getObject("side_pane");
	
	//view side pane stuff
	
}

Notebook mExtraPane;
void EngageExtraPane(Builder mBuilder)
{
	mExtraPane = cast(Notebook)mBuilder.getObject("extra_pane");
}

Box mStatusBox;
void EngageStatusBar(Builder mBuilder)
{
	mStatusBox = cast(Box)mBuilder.getObject("status_box");
}

UI_DOCBOOK mDocBook;
void EngageDocBook(Builder mBuilder)
{
	mDocBook = new UI_DOCBOOK;
	mDocBook.Engage(mBuilder);
}

bool Quit()
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
            case YES : break;//DocMan.SaveAll();break;
            case NO  : break;
            case OK  : //DocMan.CloseAll();
                       //if(!DocMan.Empty)
                       //{
	                   //    mQuitting = false;
	                   //    return;
                       //}
                       break;
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

