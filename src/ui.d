//      ui.d
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


module ui;

import dcore;
import docman;
import autopopups;

import  std.stdio;

import  gtk.Main;
import  gtk.Builder;
import  gtk.Window;
import  gtk.MenuBar;
import  gtk.Menu;
import  gtk.MenuItem;
import  gtk.SeparatorMenuItem;
import  gtk.Toolbar;
import  gtk.ToolItem;
import  gtk.SeparatorToolItem;
import  gtk.Label;
import  gtk.Notebook;
import  gtk.Statusbar;
import  gtk.ActionGroup;
import  gtk.AccelGroup;
import  gtk.Action;
import  gtk.Widget;
import  gtk.MessageDialog;
import  gdk.Event;
import  gtk.ToggleAction;
import  gtk.AboutDialog;
import  gtk.VPaned;
import  gtk.HPaned;

MAIN_UI dui;

static this()
{
    dui = new MAIN_UI;
}

class MAIN_UI
{

    private :

    Builder		mBuilder;

    Window 		mWindow;
    MenuBar		mMenuBar;
    Toolbar		mToolBar;
    Notebook	mCenterPane;
    Notebook	mSidePane;
    Notebook	mExtraPane;
    Statusbar	mStatusBar;
    ActionGroup	mActions;
    AccelGroup  mAccelerators;
    Label       mIndicator;
    HPaned      mHPaned;
    VPaned      mVPaned;
    

    Menu[string] mSubMenus;
    DOCMAN      mDocMan;
    AUTO_POP_UPS mAutoPopUps;

    bool        mIsWindowMaximized;

    public :

    void Engage(string[] CmdArgs)
    {

        Main.initMultiThread (CmdArgs);

        EngageWidgets();

        
        mDocMan     = new DOCMAN; 
        mDocMan.Engage();
        
        mAutoPopUps = new AUTO_POP_UPS;
        mAutoPopUps.Engage();
                
        Log().Entry("Engaged UI");
    }

    void Disengage()
    {
        Project.Event.disconnect(&WatchProjectName);
        mAutoPopUps.Disengage();
        mDocMan.Disengage();        
        Log().Entry("Disengaged UI");
    }

    void Run()
    {
        GetDocMan.OpenInitialDocs();
        Project.OpenLastSession();
        ReStoreGuiState();

        mWindow.show();

        Log().Entry("Entering GTK Main Loop\n");
        Main.run();
        Log().Entry("Exiting GTK Main Loop");

        StoreGuiState();
        mWindow.hide();
    }
    
    void EngageWidgets()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config().getString("UI", "ui_glade_file", "~/.neontotem/dcomposer/dcomui2.glade") );

        mWindow     = cast(Window)      mBuilder.getObject("window1");
        mMenuBar    = cast(MenuBar)     mBuilder.getObject("menubar");
        mToolBar    = cast(Toolbar)     mBuilder.getObject("toolbar");
        mCenterPane = cast(Notebook)    mBuilder.getObject("mainpane");
        mSidePane   = cast(Notebook)    mBuilder.getObject("sidepane");
        mExtraPane  = cast(Notebook)    mBuilder.getObject("extrapane");
        mStatusBar  = cast(Statusbar)   mBuilder.getObject("statusbar");
        mIndicator  = cast(Label)       mBuilder.getObject("label1");
        mHPaned     = cast(HPaned)      mBuilder.getObject("hpaned1");
        mVPaned     = cast(VPaned)      mBuilder.getObject("vpaned1");
        
        mActions    = new ActionGroup("global");
        mAccelerators=new AccelGroup();

        mWindow.addOnWindowState(delegate bool(GdkEventWindowState* WS, Widget Windough)
        {
            mIsWindowMaximized = (WS.newWindowState == WindowState.MAXIMIZED);
            return false;
        }); 

        //setup menubar
        mSubMenus["_System"] = new Menu;
        MenuItem tmp = new MenuItem("_System");
        tmp.setSubmenu(mSubMenus["_System"]);
        //mSubMenus[MenuID].insert(Addition, Position);
        mMenuBar.append(tmp);

        mSubMenus["_View"] = new Menu;
        tmp = new MenuItem("_View");
        tmp.setSubmenu(mSubMenus["_View"]);
        //mSubMenus[MenuID].insert(Addition, Position);
        mMenuBar.append(tmp);

        mSubMenus["_Edit"] = new Menu;
        tmp = new MenuItem("_Edit");
        tmp.setSubmenu(mSubMenus["_Edit"]);
        //mSubMenus[MenuID].insert(Addition, Position);
        mMenuBar.append(tmp);

        mSubMenus["_Documents"] = new Menu;
        tmp = new MenuItem("_Documents");
        tmp.setSubmenu(mSubMenus["_Documents"]);
        //mSubMenus[MenuID].insert(Addition, Position);
        mMenuBar.append(tmp);

        mSubMenus["_Project"] = new Menu;
        tmp = new MenuItem("_Project");
        tmp.setSubmenu(mSubMenus["_Project"]);
        //mSubMenus[MenuID].insert(Addition, Position);
        mMenuBar.append(tmp);

        


        mWindow.addAccelGroup(mAccelerators);
        mWindow.addOnDelete(&ConfirmQuit);
        mWindow.addOnDestroy(&ConfirmQuit);
        auto QuitAction = new Action("UI_QUIT", "_Quit", "Exit DComposer", StockID.QUIT);
        QuitAction.addOnActivate(delegate void(Action x){ConfirmQuit(null,null);});
        QuitAction.setAccelGroup(mAccelerators);
        mActions.addActionWithAccel(QuitAction, null);
        AddMenuItem("_System", QuitAction.createMenuItem());
        AddToolBarItem(QuitAction.createToolItem());
        AddToolBarItem(new SeparatorToolItem);


        //view Actions

        auto ViewToolBarAct = new ToggleAction("ViewToolBarAct", "_Toolbar", "Show/Hide Toolbar", null);
        auto ViewSidePaneAct = new ToggleAction("ViewSidePaneAct", "_Side Pane", "Show/Hide Side Window", null);
        auto ViewExtraPaneAct = new ToggleAction("ViewExtraPaneAct", "_Extra Pane", "Show/Hide Extra Pane", null);
        auto ViewStatusBarAct = new ToggleAction("ViewStatusBarAct", "Status_bar","Show/Hide Statusbar", null);

        mActions.addAction(ViewToolBarAct);
        mActions.addAction(ViewSidePaneAct);
        mActions.addAction(ViewExtraPaneAct);
        mActions.addAction(ViewStatusBarAct);

        ViewToolBarAct.setActive(Config.getBoolean("UI","view_toolbar", false));
        ViewSidePaneAct.setActive(Config.getBoolean("UI", "view_sidepane", true));
        ViewExtraPaneAct.setActive(Config.getBoolean("UI", "view_extrapane", true));
        ViewStatusBarAct.setActive(Config.getBoolean("UI", "view_statusbar", false));
        (ViewToolBarAct.getActive())?mToolBar.show() : mToolBar.hide();
        (ViewSidePaneAct.getActive())?mSidePane.show() : mSidePane.hide();
        (ViewExtraPaneAct.getActive())?mExtraPane.getParent.show() : mExtraPane.getParent.hide();
        (ViewStatusBarAct.getActive())?mStatusBar.show() : mStatusBar.hide();

        ViewToolBarAct.addOnToggled(delegate void(ToggleAction x){(x.getActive)?mToolBar.show() : mToolBar.hide(); Config.setBoolean("UI","view_toolbar", cast(bool)x.getActive());});
        ViewSidePaneAct.addOnToggled(delegate void(ToggleAction x){(x.getActive)?mSidePane.show() : mSidePane.hide();Config.setBoolean("UI","view_sidepane",cast(bool)x.getActive());});
        ViewExtraPaneAct.addOnToggled(delegate void(ToggleAction x){(x.getActive)?mExtraPane.getParent.show() : mExtraPane.getParent.hide();Config.setBoolean("UI","view_extrapane",cast(bool)x.getActive());});
        ViewStatusBarAct.addOnToggled(delegate void(ToggleAction x){(x.getActive)?mStatusBar.show() : mStatusBar.hide();Config.setBoolean("UI","view_statusbar",cast(bool)x.getActive());});
        
        AddMenuItem("_View", ViewToolBarAct.createMenuItem());
        AddMenuItem("_View", ViewSidePaneAct.createMenuItem());
        AddMenuItem("_View", ViewExtraPaneAct.createMenuItem());
        AddMenuItem("_View", ViewStatusBarAct.createMenuItem());

        AddMenuItem("_Help", new MenuItem(delegate void(MenuItem mi){ShowAboutDialog();}, "About"));

        Project.Event.connect(&WatchProjectName);
    }
    

    
    bool ConfirmQuit(Event e, Widget w)
    {
        ////this(Window parent, GtkDialogFlags flags, GtkMessageType type, GtkButtonsType buttons, bool markup, string messageFormat, string message = null);
        //auto ConDi = new MessageDialog(mWindow, GtkDialogFlags.DESTROY_WITH_PARENT, GtkMessageType.INFO, GtkButtonsType.NONE, false, null);
        //ConDi.addButtons(["Stay","Leave"],[cast(GtkResponseType)1,cast(GtkResponseType)0]);
        //ConDi.setMarkup("Are we really going to part ways for the time being??");
        //ConDi.setTitle("GoodBye??");
        //bool rv = cast(bool)ConDi.run();
        //ConDi.destroy();
//
        //if(!rv)Main.quit();
        //return rv;

        //mDocMan.CloseAllDocs(true); if close all docs here nothing will be saved to config (ie "files_last_session" will be null)
        Main.quit();
        return true;
    }

    void AddMenuItem(string MenuID, Widget Addition, int Position =-1)
    {        
        if(MenuID in mSubMenus)
        {
            mSubMenus[MenuID].insert(Addition, Position);
        }
        else
        {
            mSubMenus[MenuID] = new Menu;
            MenuItem tmp = new MenuItem(MenuID);
            tmp.setSubmenu(mSubMenus[MenuID]);
            mSubMenus[MenuID].insert(Addition, Position);
            mMenuBar.append(tmp);
        }
        mMenuBar.showAll();
    }

    void AddToolBarItem(ToolItem NuItem, int Position = -2)
    {
        NuItem.show();

        if(Position == -2)
        {
            if(mToolBar.getNItems() > 0) Position = mToolBar.getNItems() - 1;
            else Position = -1;
        }
            
        mToolBar.insert(NuItem, Position);
    }
    void PerformAction(string ActionName)
    {
        auto tmp = mActions.getAction(ActionName);
        if(tmp is null) Log.Entry("Attempt to perform invalid Action "~ActionName, "Error");
        else tmp.activate();
    }

    Window          GetWindow(){return mWindow;}
    Notebook        GetCenterPane(){return mCenterPane;}
    Notebook        GetSidePane(){return mSidePane;}
    Notebook        GetExtraPane() { return mExtraPane;}
    ActionGroup     Actions() {return mActions;}
    MenuBar         GetMenuBar(){return mMenuBar;}
    AccelGroup      GetAccel(){return mAccelerators;}
    Statusbar       Status(){return mStatusBar;}

    DOCMAN          GetDocMan(){return mDocMan;}
    AUTO_POP_UPS    GetAutoPopUps(){return mAutoPopUps;}

        
    void WatchProjectName(string EventType)
    {
        if(EventType == "Name") mIndicator.setText("Project: " ~ Project.Name);
    }


    void ShowAboutDialog()
    {
        Builder AboutBuilder = new Builder;
        AboutBuilder.addFromFile(Config.getString("UI", "about_glade_file", "~/.neontotem/dcomposer/about.glade"));

        auto About = cast(AboutDialog) AboutBuilder.getObject("aboutdialog1");

        About.run();
        About.hide();
    }


    void StoreGuiState()
    {
        int xdata, ydata;

        //vertical pane pos
        ydata = mVPaned.getPosition();
        Config.setInteger("UI", "save_state_vpaned", ydata);
        
        //horizontal pane pos
        xdata = mHPaned.getPosition();
        Config.setInteger("UI", "save_state_hpaned", xdata);
                writeln(xdata, " panes ", ydata);


        //are we maximized?  Not going to store if minimized
        Config.setBoolean("UI", "save_state_window_maximized", mIsWindowMaximized);
        
        //window xy pos
        mWindow.getPosition(xdata, ydata);
        writeln(xdata, " ", ydata);
        Config.setInteger("UI", "save_state_window_x", xdata);
        Config.setInteger("UI", "save_state_window_y", ydata);
        
        

        //window xy len
        mWindow.getSize(xdata, ydata);
        Config.setInteger("UI", "save_state_window_xlen", xdata);
        Config.setInteger("UI", "save_state_window_ylen", ydata);
        
        
        
        
    }

    void ReStoreGuiState()
    {
        int xdata, ydata;

        mIsWindowMaximized = Config.getBoolean("UI", "save_state_window_maximized", false);
        if(mIsWindowMaximized) mWindow.maximize();
        else
        {
            xdata = Config.getInteger("UI", "save_state_window_x", 64);
            ydata = Config.getInteger("UI", "save_state_window_y", 48);
            mWindow.move(xdata, ydata);

            xdata = Config.getInteger("UI", "save_state_window_xlen", 640);
            ydata = Config.getInteger("UI", "save_state_window_ylen", 480);
            mWindow.resize(xdata, ydata);
        }
        
        ydata = Config.getInteger("UI", "save_state_vpaned", 10);
        xdata = Config.getInteger("UI", "save_state_hpaned", 10);
        mVPaned.setPosition(ydata);
        mHPaned.setPosition(xdata);         

       
    }

            
            
        
        

}


//popdoc types??
enum :int { TYPE_NONE, TYPE_CALLTIP, TYPE_SCOPELIST, TYPE_SYMCOM}


// --- menu
//system        view        Document        edit        search      project     tools       elements        help
//      qu    it  w         
