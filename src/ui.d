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
import docpop;

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

    Menu[string] mSubMenus;
    DOCMAN      mDocMan;
    DOC_POP     mDocPop;



    public :

    void Engage(string[] CmdArgs)
    {

        
        Main.initMultiThread (CmdArgs);

        EngageWidgets();
        
        mDocPop = new DOC_POP;
        mDocPop.Engage();
        
        mDocMan     = new DOCMAN; 
        mDocMan.Engage();



        mWindow.show();
        Log().Entry("testing logui", "Debug");
        Log().Entry("Engaged UI");
    }

    void Disengage()
    {
        mDocPop.Disengage();
        mDocMan.Disengage();
        
        Log().Entry("Disengaged UI");
    }


    void Run()
    {
        Log().Entry("Entering GTK Main Loop\n");
        Main.run();
        Log().Entry("Exiting GTK Main Loop");
    }
    
    void EngageWidgets()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config().getString("UI", "ui_glade_file"));

        mWindow     = cast(Window)      mBuilder.getObject("window1");
        mMenuBar    = cast(MenuBar)     mBuilder.getObject("menubar");
        mToolBar    = cast(Toolbar)     mBuilder.getObject("toolbar");
        mCenterPane = cast(Notebook)    mBuilder.getObject("mainpane");
        mSidePane   = cast(Notebook)    mBuilder.getObject("sidepane");
        mExtraPane  = cast(Notebook)    mBuilder.getObject("extrapane");
        mStatusBar  = cast(Statusbar)   mBuilder.getObject("statusbar");
        mIndicator  = cast(Label)       mBuilder.getObject("label1");
        mActions    = new ActionGroup("global");
        mAccelerators=new AccelGroup();

        mWindow.addAccelGroup(mAccelerators);
        mWindow.addOnDelete(&ConfirmQuit);
        mWindow.addOnDestroy(&ConfirmQuit);
        auto QuitAction = new Action("UI_QUIT", "_Quit", "Exit DComposer", StockID.QUIT);
        QuitAction.addOnActivate(delegate void(Action x){ConfirmQuit(null,null);});
        QuitAction.setAccelGroup(mAccelerators);
        mActions.addActionWithAccel(QuitAction, null);
        AddMenuItem("System", QuitAction.createMenuItem());
        AddToolBarItem(QuitAction.createToolItem(), -1);
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
        (ViewExtraPaneAct.getActive())?mExtraPane.show() : mExtraPane.hide();
        (ViewStatusBarAct.getActive())?mStatusBar.show() : mStatusBar.hide();

        ViewToolBarAct.addOnToggled(delegate void(ToggleAction x){(x.getActive)?mToolBar.show() : mToolBar.hide(); Config.setBoolean("UI","view_toolbar", cast(bool)x.getActive());});
        ViewSidePaneAct.addOnToggled(delegate void(ToggleAction x){(x.getActive)?mSidePane.show() : mSidePane.hide();Config.setBoolean("UI","view_sidepane",cast(bool)x.getActive());});
        ViewExtraPaneAct.addOnToggled(delegate void(ToggleAction x){(x.getActive)?mExtraPane.show() : mExtraPane.hide();Config.setBoolean("UI","view_extrapane",cast(bool)x.getActive());});
        ViewStatusBarAct.addOnToggled(delegate void(ToggleAction x){(x.getActive)?mStatusBar.show() : mStatusBar.hide();Config.setBoolean("UI","view_statusbar",cast(bool)x.getActive());});
        
        AddMenuItem("_View", ViewToolBarAct.createMenuItem());
        AddMenuItem("_View", ViewSidePaneAct.createMenuItem());
        AddMenuItem("_View", ViewExtraPaneAct.createMenuItem());
        AddMenuItem("_View", ViewStatusBarAct.createMenuItem());

        writeln(mIndicator, Project());
        Project().NameChanged.connect(&WatchProjectName);
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

        //mDocMan.CloseAllDocs(true);
        Main.quit();
        return false;
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
    ActionGroup     GetActions() {return mActions;}
    MenuBar         GetMenuBar(){return mMenuBar;}
    AccelGroup      GetAccel(){return mAccelerators;}

    DOCMAN          GetDocMan(){return mDocMan;}
    DOC_POP         GetDocPop(){return mDocPop;}

        
    void WatchProjectName(string nuname){mIndicator.setText("Project :" ~ nuname);}
}

enum :int { TYPE_NONE, TYPE_CALLTIP, TYPE_SCOPELIST, TYPE_SYMCOM}
// --- menu
//system        view        Document        edit        search      project     tools       elements        help
//      qu    it  w         
