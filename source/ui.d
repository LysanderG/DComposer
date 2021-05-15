module ui;

import core.thread;
import std.algorithm;
import std.array;
import std.datetime;
import std.conv;
import std.traits; 
import std.algorithm;
import std.format;
import std.file;

import qore;
import config;
import docman;

import ui_docbook;
import ui_preferences;
import ui_project;
import ui_toolbar;


public import gtk.FileFilter;
public import gdk.Display;
public import gdk.Event;
public import gdk.Pixbuf;
public import gio.ActionGroupIF;
public import gio.ActionIF;
public import gio.ActionMapIF;
public import gio.Application : GApplication = Application;
public import gio.Cancellable;
public import gio.FileIF;
public import gio.Menu : GMenu = Menu;
public import gio.MenuItem : GMenuItem = MenuItem;
public import gio.MenuModel;
public import gio.SimpleAction;
public import gio.SimpleActionGroup;
public import glib.Timeout;
public import glib.Variant;
public import glib.VariantType;
public import gobject.ParamSpec;
public import gobject.Value;
public import gsv.SourceStyle;
public import gsv.SourceStyleScheme;
public import gsv.SourceStyleSchemeManager;
public import gsv.SourceUndoManagerIF;
public import gtk.AccelGroup;
public import gtk.AccelLabel;
public import gtk.Adjustment;
public import gtk.Application;
public import gtk.ApplicationWindow;
public import gtk.Bin;
public import gtk.Box;
public import gtk.Builder;
public import gtk.Button;
public import gtk.ButtonBox;
public import gtk.CellEditableIF;
public import gtk.CellRenderer;
public import gtk.CellRendererPixbuf;
public import gtk.CellRendererText;
public import gtk.CellRendererText;
public import gtk.CellRendererToggle;
public import gtk.CheckButton;
public import gtk.CheckMenuItem;
public import gtk.Clipboard;
public import gtk.ComboBox;
public import gtk.Dialog;
public import gtk.EditableIF;
public import gtk.Entry;
public import gtk.FileChooserButton;
public import gtk.FileChooserDialog;
public import gtk.FileChooserIF;
public import gtk.FileChooserWidget;
public import gtk.FontButton;
public import gtk.Frame;
public import gtk.IconFactory;
public import gtk.EventBox;
public import gtk.Image;
public import gtk.Label;
public import gtk.ListBox;
public import gtk.ListStore;
public import gtk.Main;
public import gtk.Menu;
public import gtk.MenuBar;
public import gtk.MenuItem;
public import gtk.MessageDialog;
public import gtk.Notebook;
public import gtk.Paned;
public import gtk.ScrolledWindow;
public import gtk.Separator;
public import gtk.SpinButton;
public import gtk.Switch;
public import gtk.TextBuffer;
public import gtk.TextIter;
public import gtk.TextView;
public import gtk.ToggleButton;
public import gtk.ToggleToolButton;
public import gtk.Toolbar;
public import gtk.TreeIter;
public import gtk.TreeModelIF;
public import gtk.TreePath;
public import gtk.TreeView;
public import gtk.TreeViewColumn;
public import gtk.Widget;
public import gtk.Window;



void Engage(ref string[] args)
{    
	mApplication = new Application("dcomposer.com", GApplicationFlags.NON_UNIQUE);
	mApplication.register(new Cancellable());
	
	auto mBuilder = new Builder;
    //mBuilder.addFromFile(config.findResource(Config.GetValue("ui", "ui_main_window", "glade/ui_main2.glade"))); 
    mBuilder.addFromFile(Config.GetResource("ui", "ui_main_window", "glade", "ui_main2.glade"));
    
    EngageMainWindow(mBuilder);
    EngageMenuBar(mBuilder);    	

    EngageToolbar(mBuilder);
    EngageSidePane(mBuilder);
    EngageExtraPane(mBuilder);
    EngageStatusbar(mBuilder);
    EngageDocBook(mBuilder);
    EngageProject();

	mApplication.addOnActivate(delegate void(GApplication app)
	{        
    });
    
    EngagePreferences();

    
	Log.Entry("Engaged");
}

void Mesh()
{ 
	MeshMainWidown();
    MeshMenubar();
    MeshToolbar();
    MeshSidePane();
    MeshExtraPane();
    MeshDocBook();
    MeshProject();
    Log.Entry("Meshed");
}

void Disengage()
{
    DisengageProject();
    DisengageDocBook();
    DisengageStatusbar();
    DisengageExtraPane();
    DisengageSidePane();
    DisengageToolbar();
    DisengageMenubar();
    DisengageMainWindow();
    
    Log.Entry("Disengaged");
}

void run(string[] args)
{

	Log.Entry("++++++ Entering GTK Main Loop ++++++");
	mApplication.run(args);
	Log.Entry("------  Exiting GTK Main Loop ------");
	
}

void AddSubMenu(int pos, string label, GMenu menu)
{
    GMenu xMenu = new GMenu();
    mMenubarModel.insertSubmenu(pos, label, menu);
}

void ShowMessage(string Title, string Message)
{
    auto x = new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.OTHER, ButtonsType.NONE, "");
    x.addButtons(["DONE"],[ResponseType.OK]);
    x.setTitle(Title);
    x.setMarkup(Message);
    x.run();
    x.hide();
    x.destroy();
}
int ShowMessage(string Title, string Message, string[] Buttons ...)
{
    auto dialog = new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.INFO, ButtonsType.NONE, "");
    dialog.setTitle(Title);
    dialog.setMarkup(Message);
    foreach(indx, string btn;Buttons)
    {
        dialog.addButton(btn, cast(int)indx);
    }

    auto response = dialog.run();
    dialog.hide();
    return response;
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
		
    mVerticalPane = cast(Paned)mBuilder.getObject("root_pane");
	mHorizontalPane = cast(Paned)mBuilder.getObject("secondary_pane");
	
	
    mApplication.addWindow(mMainWindow);

	mMainWindow.addOnDelete(delegate bool(Event Ev, Widget wdgt)
	{
    	if(ConfirmQuit())
    	{
    	    StoreGui();
            mApplication.removeWindow(mMainWindow);
    	}
    	return false;
		
	});

	Log.Entry("\tMain Window Engaged");

}

void MeshMainWidown()
{
	
    int win_x_pos = Config.GetValue("ui", "win_x_pos", 10);
	int win_y_pos = Config.GetValue("ui", "win_y_pos", 10);
	int win_x_len = Config.GetValue("ui", "win_x_len", 200);
	int win_y_len = Config.GetValue("ui", "win_y_len", 200);

	mMainWindow.move(win_x_pos, win_y_pos);
	mMainWindow.resize(win_x_len, win_y_len);
	Log.Entry("\tMain Window Meshed");
}

void DisengageMainWindow()
{
	Log.Entry("\tMain Window Disengaged");
}



//menubar stuff
void EngageMenuBar(Builder mBuilder)
{
    mMenubarModel = new GMenu();
    
    mMenuBar = cast(MenuBar)mBuilder.getObject("menu_bar");
    GMenu menuSystem = new GMenu();
    GMenu menuViews = new GMenu();
    

//==> System Menu
//quit
    GActionEntry[] ag = [{"actionQuit", &action_quit,null, null, null}];
    mMainWindow.addActionEntries(ag, null);
    mApplication.setAccelsForAction("win.actionQuit",["<Control>q"]);
    AddToolObject("quit", "Quit", "Exit DComposer", Config.GetResource("icons","quit","resources","yin-yang.png"),"win.actionQuit");
    GMenuItem menuQuit = new GMenuItem("Quit", "actionQuit");
//pref
    GActionEntry aePref = {"actionPreferences", &action_preferences, null, null, null};
    mMainWindow.addActionEntries([aePref], null);
    mApplication.setAccelsForAction("win.actionPreferences", ["<Control>p"]);
    AddToolObject("preferences","Preferences","Edit Preferences", Config.GetResource("icons","preferences", "resources", "gear.png"), "win.actionPreferences");
    GMenuItem menuPref = new GMenuItem("Preferences", "actionPreferences");
    
    mMenubarModel.insertSubmenu(0,"System",menuSystem);
    menuSystem.appendItem(menuPref); 
    menuSystem.appendItem(menuQuit);   

    

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
    
    AddToolObject("ToggleViewMenubar", "Menubar", "Show/hide menubar", 
     Config.GetResource("icons", "viewmenubar","resources", "ui-address-bar.png"),"win.actionViewMenubar(true)");
    AddToolObject("ToggleViewToolbar", "Toolbar", "Show/hide toolbar", 
     Config.GetResource("icons", "viewtoolbar","resources", "ui-address-bar.png"),"win.actionViewToolbar(true)");
    AddToolObject("ToggleViewSidepane", "Sidepane", "Show/hide sidepane", 
     Config.GetResource("icons", "viewsidepane","resources", "ui-address-bar.png"),"win.actionViewSidepane(true)");
    AddToolObject("ToggleViewExtrapane", "Extrapane", "Show/hide extrapane", 
     Config.GetResource("icons", "viewextrapane","resources", "ui-address-bar.png"),"win.actionViewExtrapane(true)");
   
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
void StoreMenubar()
{
    Config.SetValue("ui", "menubar_visible", mMenuBar.getVisible());
}
void DisengageMenubar()
{
    
    Log.Entry("\tMenubar Disengaged");
}

//side pane stuff
void EngageSidePane(Builder mBuilder)
{
	mSidePane = cast(Notebook)mBuilder.getObject("side_pane");
	mSidePane.getParent.getParent.setVisible(Config.GetValue("ui","sidepane_visible", true));
	
	Log.Entry("\tSidePane Engaged");
}
void MeshSidePane()
{
	mVerticalPane.setPosition(Config.GetValue("ui", "sidepane_pos", 10));
    Log.Entry("\tSidePane Meshed");
}
void StoreSidePane()
{
    Config.SetValue("ui", "sidepane_pos",     mVerticalPane.getPosition());
    Config.SetValue("ui", "sidepane_visible", mSidePane.getVisible());    
}
void DisengageSidePane()
{
    Log.Entry("\tSidePane Disengaged");
}

//Extra Pane stuff
void EngageExtraPane(Builder mBuilder)
{
	mExtraPane = cast(Notebook)mBuilder.getObject("extra_pane");
	mExtraPane.setVisible(Config.GetValue("ui","extrapane_visible",true));
	mExtraPane.getParent.getParent.setVisible(Config.GetValue("ui","extrapane_visible",true));
    Log.Entry("\tExtraPane Engaged");
}
void MeshExtraPane()
{
	mHorizontalPane.setPosition(Config.GetValue("ui","extrapane_pos", 10));
    Log.Entry("\tExtraPane Meshed");
}
void StoreExtraPane()
{
    Config.SetValue("ui", "extrapane_visible", mExtraPane.getVisible());
    Config.SetValue("ui", "extrapane_pos",     mHorizontalPane.getPosition());    
}
void DisengageExtraPane()
{
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
void EngageProject()
{
    ui_project.Engage();
}
void MeshProject()
{
    ui_project.Mesh();
}
void DisengageProject()
{
    ui_project.Disengage();
}

bool ConfirmQuit()
{
	bool mQuitting = true;
    auto ModdedDocs = docman.GetModifiedDocs();
    docman.SaveSessionDocuments();
    if(!ModdedDocs.empty) with (ResponseType)
    {
        //confirm quit or return
        auto ConfQuit = new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, false, "");
        ConfQuit.setTitle("Quit DComposer?");
        ConfQuit.setMarkup("Do you really wish to quit with " ~ ModdedDocs.length.to!string ~ " modified documents?");
        ConfQuit.addButtons(["Save all & quit", "Discard all & quit", "Pick & choose", "Oops, don't quit!!"], [YES, NO,OK,CANCEL]);
        auto response = ConfQuit.run();
        ConfQuit.destroy();
        switch (response)
        {
            //saveall & quit
            case YES : 
                mDocBook.SaveAll();
                break;
            //discard changes & quit
            case NO  : 
                break;
            //pick & choose & quit (or do not quit if modified docs haven't been closed)
            case OK  : 
                mDocBook.CloseAll();
                if(!mDocBook.Empty()) mQuitting = false;
                break;
            //any other response do nothing return to editting
            default  : 
        			   mQuitting = false;
        }

    }
    return mQuitting;
}

void StoreGui()
{
    mDocBook.StoreDocBook();
    StoreExtraPane();
    StoreSidePane();
    StoreToolbar();
    StoreMenubar();
    
    int win_x_pos, win_y_pos;
    int win_x_len, win_y_len;
    
    auto win = mMainWindow.getWindow();
    win.getOrigin(win_x_pos, win_y_pos);
    win_x_len = win.getWidth();
    win_y_len = win.getHeight();

    
    Config.SetValue("ui", "win_x_pos", win_x_pos);
    Config.SetValue("ui", "win_y_pos", win_y_pos);
    Config.SetValue("ui", "win_x_len", win_x_len);
    Config.SetValue("ui", "win_y_len", win_y_len);
}


void EngagePreferences()
{
    LogPreferences();
    ConfigPreferences();
    ToolbarPreferences();    
 
}

void LogPreferences()
{    
    //---------------------log
    //logfile

    auto prefLogFileLabel = new Label("Default Log File :");   
    auto prefLogFileEntry = new Entry(Log.GetLogFileName);
    auto prefLogFileDialog = new FileChooserDialog("Choose Log File", mMainWindow, FileChooserAction.SAVE);
    prefLogFileEntry.setPosition(-1);
    prefLogFileEntry.addOnIconPress(delegate void(GtkEntryIconPosition pos, Event event, Entry entry)
    {
        prefLogFileDialog.setFilename(entry.getText());
        prefLogFileDialog.run();
        prefLogFileDialog.hide();
        entry.setText(prefLogFileDialog.getFilename());
        entry.editingDone();
    });
    prefLogFileEntry.addOnEditingDone(delegate void(CellEditableIF ce)
    {
        Log.ChangeLogFileName(prefLogFileEntry.getText());
    });
    
    prefLogFileEntry.setIconFromPixbuf(EntryIconPosition.SECONDARY, new Pixbuf(Config.GetResource("preferences","logfile", "resources", "folder-open-document-text.png")));

    AppPreferenceAddWidget("General", prefLogFileLabel, prefLogFileEntry);

    //log echo stdout
    auto prefLogEchoLabel = new Label("Echo Log Entries to Std Out:");
    auto prefLogEchoSwitch = new Switch();
    AppPreferenceAddWidget("General", prefLogEchoLabel, prefLogEchoSwitch);
    prefLogEchoSwitch.setState(Log.GetEchoStdOut());
    prefLogEchoSwitch.addOnStateSet(delegate bool(bool status, Switch sw)
    {
	    Log.SetEchoStdOut(status);
	    Config.SetValue("log", "comment", "no configuration exist before log is started!");
	    Config.SetValue("log", "echo", status);
	    return false;
    });
    auto sep = new Separator(Orientation.VERTICAL);

    AppPreferenceAddWidget("General", sep );
}

void ConfigPreferences()
{
    //folder info
    string info = format(`<span font_weight = "bold">App path :</span>
    %s
<span font_weight = "bold">User configuration :</span>
    %s
<span font_weight = "bold">Resource search paths</span> :
    %s`,thisExePath, userDirectory, resourceDirectories.join("\n    "));   
       
    auto configDirPrefInfo = new Label(info);
    configDirPrefInfo.setMarkup(info);
    configDirPrefInfo.setUseMarkup(true);
    auto configDirPrefFrame = new Frame(configDirPrefInfo, "Dcomposer Paths (info only):");
    configDirPrefFrame.setLabelAlign(0.0, 1.0);
    configDirPrefInfo.setAlignment(0.0, 0.0);
    //configDirPrefUI.packStart(configDirPrefFrame, true, true, 1);
    //configDirPrefUI.packStart(configDirPrefInfo, true, true, 1);
    ui_preferences.AppPreferenceAddWidget("General", configDirPrefFrame);
}

//action callbacks from gtk ... so extern c
extern (C)
{
    void action_quit(void* sa, void* v, void * vptr)
    {
       if(ConfirmQuit())
       {
           StoreGui();
           mApplication.quit;
       }
    }
    
    void action_preferences(void* simAction, void* varTarget, void* voidUserData)
    {
        //ui_preferences.BuildAppPreferences();
        ui_preferences.AppPreferencesShow();
        
    }
    
    void action_view_menubar(GSimpleAction* simAction, GVariant* varTarget, void* voidUserData)
    { 
        SimpleAction sa = new SimpleAction(simAction);
        Variant v = new Variant(varTarget);
        mMenuBar.setVisible(!mMenuBar.getVisible());
        sa.setState(new Variant(mMenuBar.getVisible()));
    }
    void action_view_toolbar(GSimpleAction* simAction, GVariant* varTarget, void* voidUserData)
    {
        SimpleAction sa = new SimpleAction(simAction);
        Variant v = new Variant(varTarget);
        mToolbar.setVisible(!mToolbar.getVisible());
        sa.setState(new Variant(mToolbar.getVisible()));
    }
    void action_view_sidepane(GSimpleAction* simAction, GVariant* varTarget, void* voidUserData)
    {
        SimpleAction sa = new SimpleAction(simAction);
        Variant v = new Variant(varTarget);
        bool tmpbool = mSidePane.getVisible();
        mSidePane.getParent.getParent.setVisible(!tmpbool);
        mSidePane.setVisible(!tmpbool);
        sa.setState(new Variant(mSidePane.getVisible()));
    }
    void action_view_extrapane(GSimpleAction* simAction, GVariant* varTarget, void* voidUserData)
    {
        SimpleAction sa = new SimpleAction(simAction);
        Variant v = new Variant(varTarget);
        bool tmpbool = mExtraPane.getVisible();
        mExtraPane.getParent.getParent.setVisible(!tmpbool);
        mExtraPane.setVisible(!tmpbool);
        sa.setState(new Variant(mExtraPane.getVisible()));
    }
}

