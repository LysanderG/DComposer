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
import  std.path;
import  std.uri;
import  std.conv;
import 	std.algorithm;
import  std.string;
import  std.signals;

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
import  gtk.Frame;
import  gtk.Alignment;
import  gtk.VBox;
import  gtk.TreeView;
import  gtk.ListStore;
import  gtk.Button;
import  gtk.Entry;
import  gtk.Dialog;
import  gtk.TreeIter;
import  gtk.FileChooserDialog;
import  gtk.IconFactory;
import  gtk.IconSet;

import  gtk.DragAndDrop;
import	gdk.Pixbuf;



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

    IconFactory AllMyIcons;

    Menu[string] mSubMenus;
    DOCMAN      mDocMan;
    AUTO_POP_UPS mAutoPopUps;

    bool        mIsWindowMaximized;

    GtkTargetEntry FileDropTargets[];


	void DragCatcher(GdkDragContext* Cntxt, int x, int y, GtkSelectionData* SelData, uint info, uint time, Widget user_data)
    {
		//string[] SelectedFiles = splitLines(text(SelData.data));
		//writeln("hello ", SelectedFiles);

		//foreach(ref file; SelectedFiles) if(file.startsWith("file://")) file = std.uri.decode(file[7..$]); else

		string[] SelectedFiles;

		foreach(line; splitLines(text(SelData.data)))
		{
			if(line.startsWith("file://"))
			{
				SelectedFiles ~= std.uri.decode(line[7..$]);
			}
		}
		mDocMan.Open(SelectedFiles);

		DragAndDrop huh = new DragAndDrop(Cntxt);

		huh.finish(true, false, time);
	}

    public :

    void Engage(string[] CmdArgs)
    {

        Main.initMultiThread(CmdArgs);
        //Main.init(CmdArgs);

        EngageWidgets();

        AllMyIcons = new IconFactory;
		AllMyIcons.addDefault();


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

        Log().Entry("Entering GTK Main Loop\n++++++++++");
        Main.run();
        Log().Entry("----------\nExiting GTK Main Loop");

        StoreGuiState();
        mWindow.hide();
    }

    void EngageWidgets()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config().getString("UI", "ui_glade_file", "$(HOME_DIR)/glade/dcomui2.glade") );

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

		DragAndDrop.destSet (mWindow, GtkDestDefaults.ALL  , FileDropTargets.ptr, 4,  GdkDragAction.ACTION_COPY | GdkDragAction.ACTION_MOVE | GdkDragAction.ACTION_LINK | GdkDragAction.ACTION_ASK);

		mWindow.addOnDragDataReceived (&DragCatcher);

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
        //AddToolBarItem(new SeparatorToolItem);


        //view Actions

        auto ViewToolBarAct = new ToggleAction("ViewToolBarAct", "_Toolbar", "Show/Hide Toolbar", null);
        auto ViewSidePaneAct = new ToggleAction("ViewSidePaneAct", "_Side Pane", "Show/Hide Side Window", null);
        auto ViewExtraPaneAct = new ToggleAction("ViewExtraPaneAct", "_Extra Pane", "Show/Hide Extra Pane", null);
        auto ViewStatusBarAct = new ToggleAction("ViewStatusBarAct", "Status_bar","Show/Hide Statusbar", null);

        mActions.addAction(ViewToolBarAct);
        mActions.addAction(ViewSidePaneAct);
        mActions.addAction(ViewExtraPaneAct);
        mActions.addAction(ViewStatusBarAct);

        ViewToolBarAct.setActive(Config.getBoolean("UI","view_toolbar", true));
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

        AddMenuItem("_Help", new MenuItem(delegate void(MenuItem mi){ShowAboutDialog();}, "About"),17);


        Project.Event.connect(&WatchProjectName);
    }

    void AddIcon(string IconID, string IconFile)
    {
		IconSet tmpIconSet = new IconSet(new Pixbuf(IconFile));
		AllMyIcons.add(IconID, tmpIconSet);
	}


    bool ConfirmQuit(Event e, Widget w)
    {
		if(mDocMan.HasModifiedDocs)
		{

        ////this(Window parent, GtkDialogFlags flags, GtkMessageType type, GtkButtonsType buttons, bool markup, string messageFormat, string message = null);
			auto ConDi = new MessageDialog(mWindow, GtkDialogFlags.DESTROY_WITH_PARENT, GtkMessageType.INFO, GtkButtonsType.NONE, false, null);
			ConDi.addButtons(["Stay","Leave"],[cast(GtkResponseType)0,cast(GtkResponseType)1]);
			ConDi.setMarkup("There are unsaved changes to open documents... Do you wish to exit?");
			ConDi.setTitle("GoodBye??");
			bool rvQuit = cast(bool)ConDi.run();
			ConDi.destroy();

			if(!rvQuit) return true;
		}

        mDocMan.StoreOpenSessionFiles();
        mDocMan.CloseAll(true);
        Main.quit();
        return true;
    }

    void AddMenuItem(string MenuID, Widget Addition, int Position = -1)
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
            mMenuBar.insert(tmp, Position);
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


    void WatchProjectName(ProEvent EventType)
    {
        //if((EventType == "Name") || (EventType == "New")) mIndicator.setText("Project: " ~ Project.Name);
        mIndicator.setText("Project: " ~ Project.Name);
    }


    void ShowAboutDialog()
    {
        Builder AboutBuilder = new Builder;


        AboutBuilder.addFromFile(Config.getString("UI", "about_glade_file", "$(HOME_DIR)/glade/about.glade"));

        auto About = cast(AboutDialog) AboutBuilder.getObject("aboutdialog1");
		About.setVersion(config.DCOMPOSER_VERSION);
		About.setLogo(new Pixbuf(Config.getString("UI", "about_logo", "$(HOME_DIR)/glade/stolen2.png")));
        About.run();
        About.hide();
    }


    void StoreGuiState()
    {
        int xpos, xlen, ypos, ylen;

        Config.setBoolean("UI", "store_gui_window_maxed", mIsWindowMaximized);

        mWindow.getPosition(xpos, ypos);
        mWindow.getSize(xlen, ylen);

        Config.setInteger("UI", "store_gui_window_xpos", xpos);
        Config.setInteger("UI", "store_gui_window_ypos", ypos);
        Config.setInteger("UI", "store_gui_window_xlen", xlen);
        Config.setInteger("UI", "store_gui_window_ylen", ylen);

        int hpanePos = mHPaned.getPosition;
        int vpanePos = mVPaned.getPosition;

        Config.setInteger("UI", "store_gui_hpaned_pos", hpanePos);
        Config.setInteger("UI", "store_gui_vpaned_pos", vpanePos);

        emit(UI_EVENT.STORE_GUI);


    }

    void ReStoreGuiState()
    {
        int xpos, ypos, xlen, ylen;

        bool Maxed = Config.getBoolean("UI", "store_gui_window_maxed", false);

        xpos = Config.getInteger("UI", "store_gui_window_xpos", 1);
        ypos = Config.getInteger("UI", "store_gui_window_ypos", 1);
        xlen = Config.getInteger("UI", "store_gui_window_xlen", 1000);
        ylen = Config.getInteger("UI", "store_gui_window_ylen", 750);

        mWindow.move(xpos, ypos);
        mWindow.setDefaultSize(xlen,ylen);
        //mWindow.resize(xlen, ylen);
        if(Maxed) mWindow.maximize();

        mWindow.show();

        int vpanePos = Config.getInteger("UI", "store_gui_vpaned_pos", 450);
        int hpanePos = Config.getInteger("UI", "store_gui_hpaned_pos", 200);


        mHPaned.setPosition(hpanePos);
        mVPaned.setPosition(vpanePos);

        emit(UI_EVENT.RESTORE_GUI);

        Log.Entry("GUI State restored");

    }

    this()
    {
		FileDropTargets.length = 4;

		FileDropTargets[0].target = "STRING".dup.ptr;
		FileDropTargets[0].flags  = 0;
		FileDropTargets[0].info   = 0;

		FileDropTargets[1].target = "UTF8_STRING".dup.ptr;
		FileDropTargets[1].flags  = 0;
		FileDropTargets[1].info   = 0;

		FileDropTargets[2].target = "text/plain".dup.ptr;
		FileDropTargets[2].flags  = 0;
		FileDropTargets[2].info   = 0;

		FileDropTargets[3].target = "text/uri-list".dup.ptr;
		FileDropTargets[3].flags  = 0;
		FileDropTargets[3].info   = 0;

	}

	mixin Signal!(UI_EVENT);


}

enum UI_EVENT { RESTORE_GUI, STORE_GUI}


//popdoc types??
enum :int { TYPE_NONE, TYPE_CALLTIP, TYPE_SCOPELIST, TYPE_SYMCOM}


// --- menu
//system        view        Document        edit        search      project     tools       elements        help
//      qu    it  w



//base class (probably should be abstract) for all gui preference widgets
//any module/element with user changeable options will implement a child of this class
//it must return a page/section gui
//must connect to Config.ShowConfig to reset values to keyfile values
//must connect to Config.ReConfig to apply changes to keyfile
//then modules/elements will reconfigure themselves from the keyfile.

/**
 * Any element or other object which needs a GUI preference page must create a subclass of PREFERENCE_PAGE.
 * For elements the mFrame will automatically be added to the Elements preference page.  NonElements must add mFrame manually
 * as a new page or a frame in another page.
 * The Config.ShowConfig signal will be sent when the 'keyfile' has changed and the gui must be updated.
 * The Config.ReConfig signal will issue when changes to the GUI need to be 'Applied'.
 * (after some testing I've decided I don't like the 'APPLY' button,
 * at some point I'll do away with it and make changes to the gui take place immediately.)
 * */
abstract class PREFERENCE_PAGE
{
    string      mPageName;		///

    Builder     mBuilder;
    Frame       mFrame;
    Alignment   mFrameKid;
    VBox        mVBox;

    this(string PageName, string gladefile)
    {
        mPageName = PageName;  											///Page to add mVbox to (actually PREFERENCE_PAGE should be PREFERENCE_FRAME or SECTION

        mBuilder = new Builder;
        mBuilder.addFromFile(gladefile);

        mFrame = cast(Frame)mBuilder.getObject("frame");

        mFrameKid = cast(Alignment)mBuilder.getObject("alignment1");
        mVBox = cast(VBox)mBuilder.getObject("vbox1");

        Config.ShowConfig.connect(&PrepGui);

    }

	/**
	 * The root widget of the class.  Used to add to the preference dialog.
	 * Subclasses are completely resposonsible for items in this widget.
	 *
	 * Returns:
	 * A Frame containing all preference items.
	 * */
    Frame GetPrefWidget()
    {
        return mFrame;
    }

    /**
     * The name of the page (from PREFERENCES_UI.mBook) where mFrame is located.
     * */
    string PageName()
    {
        return mPageName;
    }

	/**
	 * Add a widget item to this 'PAGE'
	 * Kind of superfluous if mVBox is not going to be private.
	 * */
    void Add(Widget Addition)
    {
        mVBox.add(Addition);
    }

	/**
	 * If 'PAGE' should expand to fill extra space.
	 * Usually should not. But if more space is needed to display 'PAGE'
	 * then this function can be overriden to return true;
	 * */
	bool Expand() {return false;}
	/**
	 * Applies changes made to the GUI.  Actually saves changes to the Config.keyfile. And then Config applies changes.
	 * This strategy needs to be disgarded.  It is very unresponsive, annoying having to press apply instead of seeing instant changes.
	 * */
    abstract void Apply();
    abstract void PrepGui();
}


enum ListType {FILES, PATHS, IDENTIFIERS};

/**
 *	Basically a simple "widget" to present a list (files, paths, or simple strings).
 *
 *  It provides methods for adding new items (through apropriate dialogs), deleting individual items,
 *  and clearing all items.
 *  Simple reusable utility.  Nothing special.
 *	A note... this class attempts to display the basename of any added item (non path strings basename should be the string itself)
 * 	the actual item originally given will be displayed as a tooltip
 *
 *
 * */
class LISTUI
{

	Builder		mBuilder;

	VBox		mVBox;
	Label		mFrameLabel;
	TreeView	mListView;
	ListStore	mListStore;
	Button		mAddButton;
	Button		mRemoveButton;
	Button		mClearButton;
	Dialog 		mAddItemDialog;
	Entry		mAddItemEntry;

    /**
    Creates a new LISTUI

    Params:
    ListTitle = Frame Label, identifies list for user.
    Type = list can be  a file (filechooser) path(filechooser flagged for folder selection) or string(text entry)
    GladeFile = The glade file that defines this "widget"
    */
	this(string ListTitle, ListType Type, string GladeFile )
	{
        scope(failure) Log.Entry("Failed to instantiate LISTUI!!", "Debug");

		mBuilder = new Builder;
		mBuilder.addFromFile(GladeFile);

		mVBox 			= cast(VBox)mBuilder.getObject("vbox1");
		mFrameLabel 	= cast(Label)mBuilder.getObject("label1");
		mListView 		= cast(TreeView)mBuilder.getObject("treeview");
		mListStore		= cast(ListStore)mBuilder.getObject("thestore");
		mAddButton 		= cast(Button)mBuilder.getObject("buttonadd");
		mRemoveButton 	= cast(Button)mBuilder.getObject("buttonremove");
		mClearButton 	= cast(Button)mBuilder.getObject("buttonclear");

		mAddItemDialog = cast(Dialog)mBuilder.getObject("dialog1");
		mAddItemEntry 	= cast(Entry)mBuilder.getObject("entry");

		if(Type == ListType.FILES) mAddButton.addOnClicked(&AddFiles);
		if(Type == ListType.PATHS) mAddButton.addOnClicked(&AddPaths);
		if(Type == ListType.IDENTIFIERS) mAddButton.addOnClicked(&AddItem);

		mRemoveButton.addOnClicked(&RemoveItems);
		mClearButton.addOnClicked(&ClearItems);

		mFrameLabel.setText(ListTitle);

		mListView.getSelection().setMode(GtkSelectionMode.MULTIPLE);
		mListView.setRubberBanding(false);
		mListView.setReorderable(true);

		mVBox.showAll();
	}

	/**
	 *Clears all items in the list and sets a new list of items
	 * Params:
	 * Items = Sets list items to this array of strings.  If strings are file paths the base names will be displayed and
	 * the full string will show as a tooltip.
	 * */
	void SetItems(string[] Items)
	{
		TreeIter ti = new TreeIter;
		mListStore.clear();
		foreach (index, i; Items)
		{
			mListStore.insert(ti, 0);
			mListStore.setValue(ti, 0, baseName(i));
			//mListStore.setValue(ti, 1, relativePath(i));
            mListStore.setValue(ti, 1, i);
		}
		mListView.setModel(mListStore);
	}

	/**
	 * Retrieves the array of items.
	 *
	 * Params:
	 * col = if 0 (the default) the returned array will be the basename/displayed items.  If 1 the originals/fullnames will be returned. At this time other values will cause DComposer to explode ... hmmm that's not good.
	 *
	 * Returns:
	 * Either an array of basename/display items. Or an array of the original/fullname items.
	 *
	 * */
	string[] GetShortItems(int col = 0)
	{
		if((col < 0) || (col > 1)) col = 0;
		string[] rval;
		TreeIter ti = new TreeIter;

		if (!mListStore.getIterFirst(ti)) return rval;

		rval ~= mListStore.getValueString(ti,col);
		while(mListStore.iterNext(ti)) rval ~= mListStore.getValueString(ti,col);

		return rval;
	}
	/**
	 * Actully calls GetShortItems with the col parameter of 1.
	 *
	 * This is actually a silly kind of trick to reuse a very simple function.  Probably would be better, clearer to avoid calling another function (or fix the name.)
	 *
	 * Returns:
	 * An array of the items fullname
	 * */
	string[] GetFullItems()
	{
		return GetShortItems(1);
	}

	/**
	 * Initiates a dialog to add file(s) to items.
	 *
	 * This method is called from mAddButton signal when list type is FILES.
	 * Note... Type is not stored in this class, it is discard after ctor
	 * */
	void AddFiles(Button btn)
	{
		string afile;
		TreeIter ti = new TreeIter;

		auto FileDialog = new FileChooserDialog("Select Files", dui.GetWindow(), FileChooserAction.OPEN);
		FileDialog.setSelectMultiple(true);

		auto DialogResponse = FileDialog.run();
		FileDialog.hide();

		if(DialogResponse != ResponseType.GTK_RESPONSE_OK)return;

		auto SelFiles = FileDialog.getFilenames();
		while(SelFiles !is null)
		{
			afile = toImpl!(string, char *)(cast(char *)SelFiles.data());
			//disallow duplicates
			if (GetFullItems.canFind(afile))
			{
				SelFiles = SelFiles.next();
				continue;
			}
			mListStore.append(ti);
			mListStore.setValue(ti, 0, baseName(afile));
			mListStore.setValue(ti, 1, afile);
			SelFiles = SelFiles.next();
		}
		mListView.setModel(mListStore);
	}
	/**
	 * Initiates a dialog to add path(s) to items.
	 *
	 * This method is called from mAddButton signal when list type is PATHS.
	 * Note... Type is not stored in this class, it is discard after ctor
	 * */
	void AddPaths(Button btn)
	{
		string afile;
		TreeIter ti = new TreeIter;

		auto FileDialog = new FileChooserDialog("Select Files", dui.GetWindow(), FileChooserAction.SELECT_FOLDER);
		FileDialog.setSelectMultiple(true);

		auto DialogResponse = FileDialog.run();
		FileDialog.hide();

		if(DialogResponse != ResponseType.GTK_RESPONSE_OK)return;

		auto SelFiles = FileDialog.getFilenames();
		while(SelFiles !is null)
		{
			afile = toImpl!(string, char *)(cast(char *)SelFiles.data());
			//disallow duplicates
			if (GetFullItems.canFind(afile))
			{
				SelFiles = SelFiles.next();
				continue;
			}
			mListStore.append(ti);
			mListStore.setValue(ti, 0, baseName(afile));
			mListStore.setValue(ti, 1, afile);
			SelFiles = SelFiles.next();
		}
		mListView.setModel(mListStore);
	}
	/**
	 * Initiates a dialog to add string(s) to items.
	 *
	 * This method is called from mAddButton signal when list type is IDENTIFIERS.
	 * Note... Type is not stored in this class, it is discard after ctor
	 * */
	void AddItem(Button btn)
	{
		TreeIter ti = new TreeIter;
		auto rv = mAddItemDialog.run();
		mAddItemDialog.hide();
		if(rv == 0) return;

		string x = mAddItemEntry.getText();

		if (x.length < 1) return;
		mListStore.append(ti);
		mListStore.setValue(ti, 0, x);
		mListStore.setValue(ti, 1, x);
		mListView.setModel(mListStore);
	}

	/**
	 *Removes the currently selected item(s) from the list, if any.
	 * */
	void RemoveItems(Button btn)
	{
		TreeIter[] xs = mListView.getSelectedIters();

		foreach(x; xs)
		{
			mListStore.remove(x);
		}
		mListView.setModel(mListStore);
	}
	/**
	 *Removes all items from the list, obviously, leaving an empty list.
	 * */
	void ClearItems(Button btn)
	{
		mListStore.clear();
		mListView.setModel(mListStore);
	}

	/**
	 * Returns the root widget of the LISTUI a VBox.
	 *
	 * Good candidate for an alias this.
	 * */
	Widget GetWidget() { return mVBox;}

}



//;
