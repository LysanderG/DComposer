import ui;
import quore;
import config;


import ui_docbook;

import gio.Cancellable;
import gio.Application;
import gdk.Event;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import gtk.AccelGroup;
import gtk.Box;
import gtk.Builder;
import gtk.Button;
import gtk.IconFactory;
import gtk.Main;
import gtk.Menu;
import gtk.MenuBar;
import gtk.MenuItem;
import gtk.Notebook;
import gtk.Toolbar;
import gtk.Widget;
import gtk.Window;
import gtk.ApplicationWindow;
import glib.VariantType;
import glib.Variant;


void Engage(string[] args)
{
	Main.init(args);

	mApplication = new Application("dcomposer.com", GApplicationFlags.REPLACE);
	mApplication.register(new Cancellable());
	dwrite (mApplication);
	dwrite (mApplication.getApplicationId());
	auto mBuilder = new Builder;
	dwrite(mBuilder);
	dwrite(mBuilder.addFromFile(config.findResource(Config.GetValue("ui", "ui_main_window", "glade/ui_main.glade")))); 
	
	dwrite(mBuilder, "hi");
	EngageMainWindow(mBuilder);
	dwrite("here0");
	
	EngageMenuBar(mBuilder);
	EngageToolBar(mBuilder);
	EngageSidePane(mBuilder);
	EngageExtraPane(mBuilder);
	EngageStatusBar(mBuilder);
	EngageDocBook(mBuilder);
	//EngageContextMenu(mBuilder);
	//EngageProject(mBuilder);
	//EngageCompletion(mBuilder);
	dwrite("here");
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
gio.Application.Application         mApplication;
ApplicationWindow 	mMainWindow;
AccelGroup 			mAccelGroup;
IconFactory 		mIconFactory;
SimpleActionGroup 	mActionGroup;

void EngageMainWindow(Builder mBuilder)
{
	mMainWindow = cast(ApplicationWindow) mBuilder.getObject("main_window");
	dwrite(mMainWindow);
	//mMainWindow.insertActionGroup("win",mActionGroup);
	
	//auto quitaction = new SimpleAction("myquit", new VariantType("i"),new Variant(454));
    //quitaction.addOnActivate(delegate void (Variant v, SimpleAction sa)
    //{
	//    dwrite(v.getInt32());
	//	Quit();	
	//});
	//quitaction.setEnabled(true);
	//quitaction.setState(new Variant(2));
	
	//mActionGroup.insert(quitaction);
	
	mMainWindow.addOnDelete(delegate bool(Event ev, Widget wdgt)
	{
		dwrite("quit!!");
		return true;
	});
	mMainWindow.showAll();
}



MenuBar mMenuBar;
Menu[string] mRootMenus;

void EngageMenuBar(Builder mBuilder)
{
	mMenuBar = cast(MenuBar)mBuilder.getObject("menu_bar");
	mRootMenus["_System"] = mMenuBar.append("_System");
	mRootMenus["_View"] = mMenuBar.append("_View");
	mRootMenus["_Edit"] = mMenuBar.append("_Edit");
	mRootMenus["_Document"] = mMenuBar.append("_Document");
	mRootMenus["_Project"] = mMenuBar.append("_Project");
	mRootMenus["E_lements"] = mMenuBar.append("E_lements");
	mRootMenus["_Help"] = mMenuBar.append("_Help");

	//auto quit = new MenuItem("Quit");
	//quit.addOnActivate(delegate void(MenuItem mi){Quit();});
	//quit.setAccelPath("<Control>q");
	
	auto quit = new MenuItem("Quit");
	quit.setActionName("win.myquit");
	quit.setActionTargetValue(new Variant(545));
	quit.setSensitive(true);
	
	
	
	mRootMenus["_System"].append( quit);
	//dwrite(quit.getAccelPath());
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






void Quit()
{
	 //if docs are modded
	 //then dialog -> save and quit
	 		//	   -> discard and quit
    //               -> choose files to save or discard
	 		//	   -> do not quit , return
	 		
	dwrite(mMainWindow.listActionPrefixes());
	dwrite("=>",mMainWindow.listActions());
    Main.quit();
}


