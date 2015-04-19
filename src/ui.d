module ui;

import dcore;

public import ui_docbook;
public import ui_list;
public import ui_project;
public import ui_search;
public import ui_completion;
public import ui_elementmanager;
public import ui_preferences;
public import ui_contextmenu;

import document;

import std.stdio;
import std.algorithm;
import std.conv;


public import gtk.AccelGroup;
public import gtk.Action;
public import gtk.ActionGroup;
public import gtk.Box;
public import gtk.Builder;
public import gtk.Builder;
public import gtk.CheckButton;
public import gtk.CheckMenuItem;
public import gtk.Clipboard;
public import gtk.ColorButton;
public import gtk.Container;
public import gtk.Entry;
public import gtk.FontButton;
public import gtk.Grid;
public import gtk.IconFactory;
public import gtk.IconSet;
public import gtk.Image;
public import gtk.Label;
public import gtk.Main;
public import gtk.Menu;
public import gtk.MenuBar;
public import gtk.MenuItem;
public import gtk.MessageDialog;
public import gtk.Notebook;
public import gtk.Paned;
public import gtk.ScrolledWindow;
public import gtk.SeparatorMenuItem;
public import gtk.SpinButton;
public import gtk.Statusbar;
public import gtk.TextView;
public import gtk.ToggleAction;
public import gtk.ToggleToolButton;
public import gtk.ToolItem;
public import gtk.Toolbar;
public import gtk.Widget;
public import gtk.Window;
public import gtk.TreeStore;
public import gtk.Bin;
public import gtk.ComboBox;
public import gtk.ComboBoxText;
public import gtk.Button;
public import gtk.TreeView;
public import gtk.TreeViewColumn;
public import gtk.ListStore;
public import gtk.TreeModelIF;
public import gtk.SelectionData;
public import gtk.TargetEntry;


import gsv.SourceView;

public import gdk.Event;
public import gdk.Keysyms;
public import gdk.Atom;
public import gdk.RGBA;
public import gdk.Event;
public import gdk.Color;
public import gdk.RGBA;
public import gdk.Pixbuf;
public import gdk.Cursor;
public import gdk.Display;
public import gdk.DragContext;

public import gio.Icon;
public import gio.FileIcon;
public import gio.File;
public import gio.ContentType;

public import glib.Idle;
public import glib.ListG;


import vte.Terminal;



void Engage(string[] CmdLineArgs)
{
    Main.init(CmdLineArgs);

    mAccelGroup = new AccelGroup;

    mIconFactory = new IconFactory;
    mIconFactory.addDefault();

    mClipBoard = Clipboard.get(intern("CLIPBOARD",true));

    mBuilder = new Builder;
    mBuilder.addFromFile( SystemPath( Config.GetValue("ui", "ui_main_glade",  "glade/ui_main.glade")));
    mProjectTitle = cast(Label)mBuilder.getObject("label2");
    MainWindow = cast(Window)mBuilder.getObject("window1");
    MainWindow.addOnDelete(delegate bool(Event event, Widget widget){Quit();  return true;});

    MainWindow.addAccelGroup(mAccelGroup);

    auto tmp =  cast(Notebook)mBuilder.getObject("centerpane");

    mStatusbar = cast(Statusbar)mBuilder.getObject("statusbar1");

    DocBook = new UI_DOCBOOK(tmp);
    uiProject = new UI_PROJECT;
    uiSearch = new UI_SEARCH;
    uiCompletion = new UI_COMPLETION;
    uiContextMenu = new UI_CONTEXTMENU;

    EngageActions();
    EngageSidePane();
    EngageExtraPane();
    DocBook.Engage();
    uiProject.Engage();
    uiSearch.Engage();
    uiCompletion.Engage();
    ui_elementmanager.Engage();
    uiContextMenu.Engage();


    //AddSidePage(new TextView, "text");
    //AddSidePage(new SourceView, "src");
    ui.DocBook.prependPageMenu(uiProject.GetRootWidget(), cast(Widget)new Label("Project Options"), cast(Widget)new Label("Project Options"));

    MainWindow.setIconFromFile( SystemPath( Config.GetValue("icons", "main_icon", "resources/mushroom.png")));
    Log.Entry("Engaged");
}

void PostEngage()
{
    DocBook.PostEngage();
    uiProject.PostEngage();
    uiSearch.PostEngage();
    uiCompletion.PostEngage();
    ui_elementmanager.PostEngage();
    uiContextMenu.PostEngage();

    RestoreGui();

    Log.Entry("PostEngaged");
}

void RestoreGui()
{
    auto win_x_pos = Config.GetValue!int("ui", "win_x_pos", 1);
    auto win_y_pos = Config.GetValue!int("ui", "win_y_pos", 1);
    auto win_x_len = Config.GetValue!int("ui", "win_x_len", 1000);
    auto win_y_len = Config.GetValue!int("ui", "win_y_len", 750);


    MainWindow.move(win_x_pos, win_y_pos);
    MainWindow.setDefaultSize(win_x_len, win_y_len);



    RestoreSidePane();

    RestoreExtraPane();

    RestoreToolbar();

}



void Run()
{
    MainWindow.show();

    Log.Entry("++++++++++++++ Entering GTK Main Loop");
    Main.run();
    Log.Entry("-------------- Exiting GTK Main Loop");

    StoreGui();
}

void Disengage()
{
    uiContextMenu.Disengage();
    ui_elementmanager.Disengage();
    uiCompletion.Disengage();
    uiSearch.Disengage();
    uiProject.Disengage();
    Log.Entry("Disengaged");
}

void StoreGui()
{
    int xpos, ypos, xlen, ylen;
    MainWindow.getPosition(xpos, ypos);
    MainWindow.getSize(xlen, ylen);

    Config.SetValue("ui", "win_x_pos", xpos);
    Config.SetValue("ui", "win_y_pos", ypos);
    Config.SetValue("ui", "win_x_len", xlen);
    Config.SetValue("ui", "win_y_len", ylen);

    StoreExtraPane();
    StoreSidePane();
    StoreActions();
}


/////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////

private:


Builder     mBuilder;
MenuBar     mMenuBar;
Toolbar     mToolbar;
Notebook    mCenterPane;
Statusbar   mStatusbar;
IconFactory mIconFactory;
Paned       mPaneV;
Paned       mPaneH;
Clipboard   mClipBoard;
Label       mProjectTitle;




public:
Window      MainWindow;
UI_DOCBOOK  DocBook;
ActionGroup mActions;
AccelGroup  mAccelGroup;
UI_PROJECT  uiProject;
UI_SEARCH   uiSearch;
UI_COMPLETION uiCompletion;
Notebook    mExtraPane;
Notebook    mSidePane;


//////////////////////////////////////////////////////////////////////
////////////////////////// ui_actions -> menus and toolbar
string[] mRootMenuNames = ["_System", "_View", "_Edit", "_Document", "_Project", "_Tools", "E_lements", "_Help"] ;
Menu[string] mRootMenu;
string[] AllActions;
string[] ActionsOnToolbar;


void EngageActions()
{
    mActions = new ActionGroup("dcomposer");
    mMenuBar = cast(MenuBar)mBuilder.getObject("menubar1");
    mToolbar = cast(Toolbar)mBuilder.getObject("toolbar1");


    AddIcon("dcmp-quit", SystemPath(Config.GetValue("icons","app-quit","resources/yin-yang.png")));
    AddIcon("dcmp-view-toolbar", SystemPath(Config.GetValue("icons","toolbar-view","resources/yin-yang.png")));
    AddIcon("dcmp-toolbar-separator", SystemPath(Config.GetValue("icons", "toolbar-seperator", "resources/ui-separator-vertical.png")));
    AddIcon("dcmp-toolbar-configure", SystemPath(Config.GetValue("icons", "toolbar-configure", "resources/ui-toolbar-configure.png")));


    AddToggleAction("ActViewToolbar", "viewtoolbar", "show/hide toolbar", "dcmp-view-toolbar", "",
        delegate void(Action a){auto y = cast(ToggleAction)a;mToolbar.setVisible(y.getActive());});
    AddAction("ActQuit", "quit", "exit dcomposer", "dcmp-quit", "<Control>q", delegate void(Action a){Quit();});
    AddAction("ActConfigureToolbar", "Edit Toolbar", "customize toolbar buttons", "dcmp-toolbar-configure", "",
        delegate void (Action a){ConfigureToolBar();});
    foreach(name; mRootMenuNames) mRootMenu[name] = mMenuBar.append(name);


    AddToMenuBar("-", mRootMenuNames[0]);
    AddToMenuBar("ActQuit",mRootMenuNames[0]);
    AddToMenuBar("ActViewToolbar", mRootMenuNames[1]);
    AddToMenuBar("ActConfigureToolbar", mRootMenuNames[0], 0);

    //"ActQuit".AddToToolBar();
    mMenuBar.showAll();
    mToolbar.showAll();

}

void RestoreActions()
{


    //ClearToolbar();
    auto ActionNames = Config.GetArray("toolbar", "actions", ["ActViewToolbar","ActQuit"]);
    foreach(name; ActionNames) {mToolbar.insert(mActions.getAction(name).createToolItem(),1);}

    bool ToolbarVisible = Config.GetValue("ui", "visible_toolbar", true);
    mToolbar.setVisible(ToolbarVisible);
    auto tact = cast(ToggleAction)GetAction("ActViewToolbar");
    tact.setActive(ToolbarVisible);
    ConfigureToolBar();
}

void StoreActions()
{
    Config.SetValue("ui", "visible_toolbar", mToolbar.getVisible());
}

void AddIcon(string name, string icon_file)
{
    mIconFactory.add(name, new IconSet(new Pixbuf(icon_file)));
}

Action AddAction(string name, string label, string tooltip, string stock_id, string accel, void delegate(Action) dlg)
{
        auto NuAction = new Action (name, label, tooltip, stock_id);
        NuAction.addOnActivate(dlg);
        NuAction.setAccelGroup(mAccelGroup);
        if(accel.length == 0) mActions.addAction(NuAction);
        else mActions.addActionWithAccel(NuAction, accel);
        return NuAction;
}
void AddToggleAction(string name, string label, string tooltip, string stock_id, string accel, void delegate(Action) dlg)
{
        auto NuAction = new ToggleAction (name, label, tooltip, stock_id);
        NuAction.addOnActivate(dlg);
        NuAction.setAccelGroup(mAccelGroup);
        if(accel.length == 0) mActions.addAction(NuAction);
        else mActions.addActionWithAccel(NuAction, accel);
}


void AddToMenuBar(string ActionName, string TopMenu, int Position = -1)
{
    if(ActionName == "-")
    {
        auto sep = new SeparatorMenuItem;
        sep.show();
        mRootMenu[TopMenu].append(sep);
        return;
    }
    if(Position == -1)mRootMenu[TopMenu].append(mActions.getAction(ActionName).createMenuItem());
    else mRootMenu[TopMenu].insert(mActions.getAction(ActionName).createMenuItem(), Position);
}

Menu AddMenuToMenuBar(string label, string TopMenu)
{
    auto t = mRootMenu[TopMenu].appendSubmenu(label);
    t.showAll();
    return t;
}
void AddItemToMenuBar(MenuItem mi, string TopMenu)
{
    mi.show();
    mRootMenu[TopMenu].append(mi);
}


@disable void AddToToolBar(string ActionName, int Position = 0)
{
    auto actnames = Config.GetArray!string("toolbar", "actions");

    if(actnames.canFind(ActionName))return;

    if(Position < 1) actnames = ActionName ~ actnames;
    else if(Position >= actnames.length) actnames ~= ActionName;
    else actnames = actnames[0..Position] ~ ActionName ~ actnames[Position .. $];

    Config.SetValue("toolbar", "actions", actnames);
}

@disable void AddItemToToolBar(ToolItem item, int pos = 0)
{
    mToolbar.insert(item, pos);
}


@disable void RemoveFromToolBar(string ActionName)
{
    string[] nunames;
    auto toolnames = Config.GetArray!string("toolbar","actions");
    foreach(name; toolnames) if(name != ActionName) nunames ~= name;
    Config.SetValue("toolbar", "actions", nunames);
    RestoreActions();
}


Action GetAction(string name)
{
    return mActions.getAction(name);
}

string[] ListActions()
{
    string[] rv;
    auto actnode = mActions.listActions();
    Action x;

    while(actnode !is null)
    {
        x  = new Action(cast(GtkAction*)actnode.data());
        rv ~= x.getName();
        actnode = actnode.next();
    }
    return rv;
}

void AddStatus(string Context, string StatusMessage)
{
    if(mStatusbar is null) return;
    auto tmp = mStatusbar.getContextId(Context);
    mStatusbar.push(tmp, StatusMessage);
}




///////////////////////////////////////////////////////////////////////
////////////////////////// ui_panes

void EngageSidePane()
{
    mPaneH = cast(Paned)mBuilder.getObject("paned2");
    mSidePane = cast(Notebook)mBuilder.getObject("sidepane");
    mSidePane.showAll();

    AddIcon("dcmp_view_side_pane", SystemPath(Config.GetValue("icons","side-pane-view","resources/ui-split-panel.png")));
    AddToggleAction("ActViewSidePane","Side Pane","show/hide left side pane","dcmp_view_side_pane","",
        delegate void (Action x){auto y = cast(ToggleAction)x;mSidePane.setVisible(y.getActive());});
    "ActViewSidePane".AddToMenuBar("_View");

}

void AddSidePage(Container page, string tab_text)
{
    mSidePane.appendPage(page, tab_text);
    mSidePane.setTabReorderable(page, 1);

}
void RemoveSidePage(Container page)
{
    mSidePane.remove(page);
}
void StoreSidePane()
{
    Config.SetValue("ui", "side_pane_position", mPaneH.getPosition());
    Config.SetValue("ui", "side_pane_visible", mSidePane.getVisible());
    foreach(int i; 0 .. (mSidePane.getNPages()))
    {
        auto pageWidget = mSidePane.getNthPage(i);
        auto pageTitle = mSidePane.getTabLabelText(pageWidget);
        if(pageTitle.length > 0) Config.SetValue("ui_side_pane_page_positions", pageTitle, i);

    }

}
void RestoreSidePane()
{
    mPaneH.setPosition(Config.GetValue!int("ui", "side_pane_position", 120));

    bool SidePaneVisible = Config.GetValue("ui", "side_pane_visible", true);
    mSidePane.setVisible(SidePaneVisible);
    auto tact = cast(ToggleAction)GetAction("ActViewSidePane");
    tact.setActive(SidePaneVisible);

    int[Widget] NewPage;

    foreach(int i; 0..mSidePane.getNPages())
    {
        auto tmpwidget = mSidePane.getNthPage(i);
        string pageTitle = mSidePane.getTabLabelText(tmpwidget);
        NewPage[tmpwidget] = Config.GetValue!int("ui_side_pane_page_positions", pageTitle);
        auto pageWidget = mSidePane.getNthPage(i);
    }
    foreach(keywidget, indx; NewPage)
    {
        mSidePane.reorderChild(keywidget, indx);
    }
    mSidePane.setCurrentPage(0);
}


void EngageExtraPane()
{
    mPaneV = cast(Paned)mBuilder.getObject("paned1");
    mExtraPane = cast(Notebook)mBuilder.getObject("extrapane");

    AddIcon("dcmp_view_extra_pane", SystemPath(Config.GetValue("icons", "extra-pane-view", "resources/ui-split-panel-vertical.png")));
    AddToggleAction("ActViewExtraPane","Extra Pane","show/hide Extra pane","dcmp_view_extra_pane","",
        delegate void (Action x){auto y = cast(ToggleAction)x;mExtraPane.getParent.setVisible(y.getActive());});
    "ActViewExtraPane".AddToMenuBar("_View");
    mExtraPane.setCurrentPage(0);
    mExtraPane.showAll();
}
void AddExtraPage(Container subject, string tab_text)
{
    mExtraPane.appendPage(subject, tab_text);
    mExtraPane.setTabReorderable(subject, 1);

}
void RemoveExtraPage(Container page)
{
    mExtraPane.remove(page);
}
void StoreExtraPane()
{
    Config.SetValue("ui", "extra_pane_position", mPaneV.getPosition());
    Config.SetValue("ui", "extra_pane_visible", mExtraPane.getParent().getVisible());

    foreach(int i; 0 .. (mExtraPane.getNPages()))
    {
        auto pageWidget = mExtraPane.getNthPage(i);
        auto pageTitle = mExtraPane.getTabLabelText(pageWidget);
        if(pageTitle.length > 0) Config.SetValue("ui_extra_pane_page_positions", pageTitle, i);

    }

}
void RestoreExtraPane()
{
    mPaneV.setPosition(Config.GetValue!int("ui", "extra_pane_position", 120));

    bool ExtraPaneVisible = Config.GetValue("ui", "extra_pane_visible", true);
    mExtraPane.getParent().setVisible(ExtraPaneVisible);
    auto tact = cast(ToggleAction)GetAction("ActViewExtraPane");
    tact.setActive(ExtraPaneVisible);

    int[Widget] NewPage;

    foreach(int i; 0..mExtraPane.getNPages())
    {
        auto tmpwidget = mExtraPane.getNthPage(i);
        string pageTitle = mExtraPane.getTabLabelText(tmpwidget);
        NewPage[tmpwidget] = Config.GetValue!int("ui_extra_pane_page_positions", pageTitle);
        auto pageWidget = mExtraPane.getNthPage(i);
    }
    foreach(keywidget, indx; NewPage)
    {
        mExtraPane.reorderChild(keywidget, indx);
    }
    mExtraPane.setCurrentPage(0);
}


//this really needs a button parameter or its useless!
void ShowMessage(string Title, string Message)
{
    auto x = new MessageDialog(MainWindow, DialogFlags.MODAL, MessageType.OTHER, ButtonsType.NONE, "");
    x.addButtons(["DONE"],[ResponseType.OK]);
    x.setTitle(Title);
    x.setMarkup(Message);
    x.run();
    x.hide();
    x.destroy();
}

int ShowMessage(string Title, string Message, string[] Buttons ...)
{
    auto dialog = new MessageDialog(MainWindow, DialogFlags.MODAL, MessageType.INFO, ButtonsType.NONE, "");
    dialog.setTitle(Title);
    dialog.setMarkup(Message);
    foreach(int indx, string btn;Buttons)
    {
        dialog.addButton(btn, indx);
    }

    auto response = dialog.run();
    dialog.destroy();
    return response;
}


void Quit()
{
    auto ModdedDocs = DocMan.Modified();
    if(ModdedDocs) with (ResponseType)
    {
        //confirm quit or return
        auto ConfQuit = new MessageDialog(MainWindow, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, false, "");
        ConfQuit.setTitle("Quit DComposer?");
        ConfQuit.setMarkup("Do you really wish to quit with " ~ to!string(ModdedDocs) ~ " modified documents?");
        ConfQuit.addButtons(["Save all & quit", "Discard all & quit", "Pick & choose", "Oops, don't quit!!"], [YES, NO,OK,CANCEL]);
        auto response = ConfQuit.run();
        ConfQuit.destroy();
        switch (response)
        {
            case YES : DocMan.SaveAll();break;
            case NO  : break;
            case OK  : DocMan.CloseAll();
                       if(!DocMan.Empty)return;
                       break;
            default  : return;
        }

    }

    //mWindow.hide();
    Main.quit();
}


void SetProjectTitle(string nuTitle)
{
    mProjectTitle.setText("Project: "~nuTitle);
}

//======================================================================================================================
//======================================================================================================================
//======================================================================================================================
//toolbar configuration
//======================================================================================================================

import gtk.IconView;
import gtk.ListStore;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.Dialog;
import gtk.SeparatorToolItem;

import gobject.Value;

struct IconRowData
{
    string mName;
    string mLabel;
    string mTip;
    string mID;
    string mPath;
}


void ConfigureToolBar()
{
    //variables
    static IconRowData mIconRowData;

    auto tbBuilder = new Builder;
    tbBuilder.addFromFile( SystemPath( Config.GetValue("toolbar", "toolbar_glade", "glade/ui_toolbar.glade")));
    auto tbWin = cast(Dialog)tbBuilder.getObject("dialog1");
    auto tbAvailIcons = cast(IconView)tbBuilder.getObject("iconview1");
    auto tbAvailList = cast(ListStore)tbBuilder.getObject("liststore1");
    auto tbCurrentIcons = cast(IconView)tbBuilder.getObject("iconview2");
    auto tbCurrentList = cast(ListStore)tbBuilder.getObject("liststore2");

    auto ti = new TreeIter;

    //first add separator icon which is not an action
    tbAvailList.append(ti);
    tbAvailList.setValue(ti, 0, "Separator");
    tbAvailList.setValue(ti, 1, "Separator");
    tbAvailList.setValue(ti, 2, "Separator");
    tbAvailList.setValue(ti, 3, "dcmp-toolbar-separator");


    //fill in all available toolbar actions
    foreach(actid; ListActions())
    {
        auto workingAction = GetAction(actid);

        Value StockIdValue = new Value;
        StockIdValue.init(GType.STRING);

        string thelabel;
        foreach(ch; workingAction.getLabel())if(ch != '_')thelabel ~= ch;
        workingAction.getProperty("stock-id", StockIdValue);
        tbAvailList.append(ti);
        tbAvailList.setValue(ti, 0, workingAction.getName());
        tbAvailList.setValue(ti, 1, thelabel);
        tbAvailList.setValue(ti, 2, workingAction.getTooltip());
        tbAvailList.setValue(ti, 3, StockIdValue.getString());
    }

    //fill in icons on toolbar
    string[] currentToolbarActions = Config.GetArray!(string)("toolbar", "configured_actions", ["ActQuit"]);

    foreach(toolaction; currentToolbarActions)
    {
        if(toolaction.length < 1) continue;

        auto iter = new TreeIter;
        tbCurrentList.append(iter);

        if(toolaction == "Separator")
        {
            tbCurrentList.setValue(iter, 0, "Separator");
            tbCurrentList.setValue(iter, 1, "Separator");
            tbCurrentList.setValue(iter, 2, "Separator");
            tbCurrentList.setValue(iter, 3, "dcmp-toolbar-separator");
        }
        else
        {


            auto workingAction = GetAction(toolaction);
            if(workingAction is null) continue;

            Value StockIdValue = new Value;
            StockIdValue.init(GType.STRING);

            string thelabel;
            foreach(ch; workingAction.getLabel())if(ch != '_')thelabel ~= ch;
            workingAction.getProperty("stock-id", StockIdValue);
            tbCurrentList.setValue(iter, 0, workingAction.getName());
            tbCurrentList.setValue(iter, 1, thelabel);
            tbCurrentList.setValue(iter, 2, workingAction.getTooltip());
            tbCurrentList.setValue(iter, 3, StockIdValue.getString());
        }
    }

    //set up both icon views
    tbAvailList. setSortColumnId (1, SortType.ASCENDING);

    tbCurrentIcons.setReorderable(0);

    GtkTargetEntry tgtCopy = GtkTargetEntry("myCopy".dup.ptr, TargetFlags.SAME_APP, 0);
    GtkTargetEntry tgtMove = GtkTargetEntry("myMove".dup.ptr, TargetFlags.SAME_WIDGET, 1);

    TargetEntry targetCopyEntry = new TargetEntry(&tgtCopy);
    TargetEntry targetMoveEntry = new TargetEntry(&tgtMove);

    tbAvailIcons.enableModelDragSource(cast(GdkModifierType)0, [targetCopyEntry], DragAction.COPY);
    tbCurrentIcons.enableModelDragSource(cast(GdkModifierType)0, [targetMoveEntry], DragAction.MOVE);
    tbCurrentIcons.enableModelDragDest([targetMoveEntry, targetCopyEntry], DragAction.MOVE | DragAction.COPY);


    // call back funtions
    void GetDragData(DragContext dc, SelectionData sd, uint info, uint timestamp, Widget w)
    {

        IconView iView = cast(IconView)w;
        auto ti = new TreeIter;

        auto Selector = iView.getSelectedItems();
        GtkTreePath * gtp = cast(GtkTreePath *)(Selector.data);


        auto tp = new TreePath(gtp);

        iView.getModel().getIter(ti, tp);
        mIconRowData.mName = ti.getValueString(0);
        mIconRowData.mLabel = ti.getValueString(1);
        mIconRowData.mTip = ti.getValueString(2);
        mIconRowData.mID = ti.getValueString(3);
        mIconRowData.mPath = tp.toString();

    }
    void ReceivedDragData(DragContext dc, int x, int y, SelectionData sd, uint info, uint tstamp, Widget w)
    {
        //scope(exit)dc.dropFinish(1, tstamp);
        if(mIconRowData.mName == "nullData")return;

        auto xadjuster = tbCurrentIcons.getHadjustment();

        x += cast(int)xadjuster.getValue();

        auto tpx = new TreePath(true);

        tpx = tbCurrentIcons.getPathAtPos(x, y);

        auto tiAtPath = new TreeIter;
        auto tiInsert = new TreeIter;

        tbCurrentList.getIter(tiAtPath, tpx);
        if(tbCurrentList.iterIsValid(tiAtPath))tbCurrentList.insertBefore(tiInsert, tiAtPath);
        else(tbCurrentList.append(tiInsert));
        if(!tbCurrentList.iterIsValid(tiInsert))
        {
            mIconRowData.mName = "nullData";
            return;
        }
        tbCurrentList.setValue(tiInsert, 0, mIconRowData.mName);
        tbCurrentList.setValue(tiInsert, 1, mIconRowData.mLabel);
        tbCurrentList.setValue(tiInsert, 2, mIconRowData.mTip);
        tbCurrentList.setValue(tiInsert, 3, mIconRowData.mID);

        mIconRowData.mName = "nullData";

        //deleting
        if(dc.getActions == DragAction.MOVE)
        {
            auto delTPath = new TreePath(mIconRowData.mPath);
            if(delTPath.compare(tpx) > 0) delTPath.next();
            tbCurrentList.dragDataDelete(delTPath);
        }
    }
    bool FailedDrag(DragContext dc, GtkDragResult dr, Widget w)
    {
        auto ti = new TreeIter;

        auto Selector = tbCurrentIcons.getSelectedItems();
        GtkTreePath * gtp = cast(GtkTreePath *)(Selector.data);

        auto tp = new TreePath(gtp);

        tbCurrentList.dragDataDelete(tp);

        return true;
    }


    // connect call back functions
    tbAvailIcons.addOnDragDataGet(&GetDragData);
    tbCurrentIcons.addOnDragDataGet(&GetDragData);
    tbCurrentIcons.addOnDragDataReceived(&ReceivedDragData);
    tbCurrentIcons.addOnDragFailed(&FailedDrag);



    //manipulate everything

    void AddToolbarAction(TreePath tp, IconView availView)
    {

        //get the source  iter to add from
        auto srcTi = new TreeIter;
        tbAvailList.getIter(srcTi, tp);

        //get the dest iter to add to
        auto destTi = new TreeIter;
        tbCurrentList.append(destTi);

        tbCurrentList.setValue(destTi, 0, tbAvailList.getValueString(srcTi, 0));
        tbCurrentList.setValue(destTi, 1, tbAvailList.getValueString(srcTi, 1));
        tbCurrentList.setValue(destTi, 2, tbAvailList.getValueString(srcTi, 2));
        tbCurrentList.setValue(destTi, 3, tbAvailList.getValueString(srcTi, 3));
    }
    void RemoveToolbarAction(TreePath tp, IconView currIcons)
    {
        auto deleteIter = new TreeIter;
        tbCurrentList.getIter(deleteIter, tp);

        tbCurrentList.remove(deleteIter);
    }

    tbAvailIcons.addOnItemActivated (&AddToolbarAction);//void delegate(TreePath, IconView)
    tbCurrentIcons.addOnItemActivated (&RemoveToolbarAction);//void delegate(TreePath, IconView)


    //show it modal baby
    auto x = tbWin.run();
    tbWin.destroy;
    if(x < 0) //canceled so just bail?
    {
        return;
    }

    //now save actions!!
    string[] ActsToSave;
    auto treeiter = new TreeIter;
    int iterValid = tbCurrentList.getIterFirst(treeiter);
    while(iterValid)
    {
        ActsToSave ~= tbCurrentList.getValueString(treeiter, 0);
        iterValid = tbCurrentList.iterNext(treeiter);
    }
    Config.SetArray("toolbar", "configured_actions", ActsToSave);
    Config.Save();
    RestoreToolbar();

}


void RestoreToolbar()
{
    ClearToolbar();
    foreach(string toolaction; Config.GetArray!string("toolbar", "configured_actions"))
    {
        if(toolaction == "Separator")
        {
            auto sep = new SeparatorToolItem();
            //sep.setDraw(1);
            sep.showAll();
            mToolbar.insert(sep);
        }
        else
        {
            //important note!!
            //an action in the cfg file may be missing if its "element"
            //has been unloaded/disabled.
            if(toolaction.length < 1)continue;
            auto theAction = GetAction(toolaction);
            if(theAction !is null)mToolbar.insert(theAction.createToolItem());
        }
    }
    bool ToolbarVisible = Config.GetValue("ui", "visible_toolbar", true);
    mToolbar.setVisible(ToolbarVisible);

    Action actnott = GetAction("ActViewToolbar");
    actnott.setProperty("active", ToolbarVisible);

}

void ClearToolbar()
{
    extern (C) void cback(GtkWidget * gtkWidget, void * somedata)
    {
        auto oldthingy = new Widget(gtkWidget);
        mToolbar.remove(oldthingy);
    }
    mToolbar.foreac(&cback, cast(void *)null);
}


//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////


void SetBusyCursor(bool value)
{
    if(!MainWindow.isVisible())return;
    if(value is false)
    {
        MainWindow.getWindow().setCursor(null);
        Display.getDefault.flush();
    }
    else
    {
        auto busyMouse = new Cursor(GdkCursorType.WATCH);
        MainWindow.getWindow().setCursor(busyMouse);
        Display.getDefault.flush();
        busyMouse.unref();
    }
}

