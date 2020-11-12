module ui_toolbar;

import qore;
import ui;
import ui_preferences;


import gtk.Application;
import gtk.Builder;
import gtk.Image;
import gtk.Toolbar;
import gtk.ToolButton;
import gtk.ToolItem;
import gtk.Widget;
import gtk.Misc;


import std.stdio;
import std.algorithm;


Toolbar             mToolbar;
TOOL_OBJECT[string] mToolObjects;



void EngageToolbar(Builder mBuilder)
{
    mToolbar = cast(Toolbar)mBuilder.getObject("tool_bar");
    mToolbar.setVisible(Config.GetValue("ui_toolbar", "visible", true));
    Log.Entry("\tToolbar Engaged");
}

void MeshToolbar()
{
    auto buttonsOnBar = Config.GetArray("ui_toolbar", "buttons", ["preferences", "docnew","docopen","docsave","docsaveall","docsaveas","docclose","doccloseall","quit"]);
    buttonsOnBar.each!InsertToolButton();
    Log.Entry("\tToolbar Meshed");
}

void StoreToolbar()
{
    Config.SetValue("ui_toolbar","visible",mToolbar.getVisible());
}

void DisengageToolbar()
{   
    Log.Entry("\tToolbar Disengaged");
}

void AddToolObject(string id, string name, string tooltip, string iconresource, string actionname)
{
    auto to = new TOOL_OBJECT;
    to.mName = name;
    to.mTooltip = tooltip;
    to.mIconResource = iconresource;
    to.mActionName = actionname;
    
    mToolObjects[id] = to;
}

void InsertToolButton(string Id, int pos = -1)
{
    auto toptr = (Id in mToolObjects);
    if(toptr is null) return;
    TOOL_OBJECT to = *toptr;   
    
    auto icon = new Image(to.mIconResource);
    
    ToolButton button = new ToolButton(icon, to.mName);
    button.setActionName(to.mActionName);
    button.setTooltipText(to.mTooltip);
    button.showAll();
    mToolbar.insert(button, pos);
}

class TOOL_OBJECT
{
    string      mName;
    string      mTooltip;
    string      mIconResource;
    string      mActionName;
    
}

void UpdateToolbar()
{
    mToolbar.removeAll();
    auto buttonsOnBar = Config.GetArray("ui_toolbar", "buttons", ["preferences", "docnew","docopen","docsave","docsaveall","docsaveas","docclose","doccloseall","quit"]);
    buttonsOnBar.each!InsertToolButton();   
}

void ToolbarPreferences()
{    
    ListStore UsedStore;
    
    void PrefLoadUsedButtons()
    {
        foreach(button; Config.GetArray!string("ui_toolbar", "buttons"))
        {
            if(button !in mToolObjects)continue;
            auto tool = mToolObjects[button];     
            auto ti = new TreeIter;
            UsedStore.append(ti);
            UsedStore.setValue(ti, 0, new Value(new Pixbuf(tool.mIconResource)));
            UsedStore.setValue(ti, 1, new Value(tool.mName));
            UsedStore.setValue(ti, 2, new Value(button));
        }
    }  

    auto AvailStore = new ListStore([GType.OBJECT, GType.STRING,GType.STRING]);
    auto prefAvailIcons = new TreeView(AvailStore);
    auto prefCellIcon = new CellRendererPixbuf;
    auto prefCellText = new CellRendererText;
    auto prefColIcon = new TreeViewColumn("icon", prefCellIcon, "pixbuf", 0);
    auto prefColText = new TreeViewColumn("action", prefCellText, "text", 1);
    prefAvailIcons.appendColumn(prefColIcon);
    prefAvailIcons.appendColumn(prefColText);
    prefAvailIcons.getSelection.setMode(SelectionMode.BROWSE);
    
    //populate available store    
    foreach(key, tool; mToolObjects)
    {
        auto ti = new TreeIter;
        AvailStore.append(ti);
        AvailStore.setValue(ti, 0, new Value(new Pixbuf(tool.mIconResource)));
        AvailStore.setValue(ti, 1, new Value(tool.mName));
        AvailStore.setValue(ti, 2, new Value(key));
    }
        
    UsedStore = new ListStore([GType.OBJECT, GType.STRING, GType.STRING]);
    auto prefUsedIcons = new TreeView(UsedStore);
    prefCellIcon = new CellRendererPixbuf;
    prefCellText = new CellRendererText;
    prefColIcon = new TreeViewColumn("icon", prefCellIcon, "pixbuf", 0);
    prefColText = new TreeViewColumn("action", prefCellText, "text", 1);
    prefUsedIcons.appendColumn(prefColIcon);
    prefUsedIcons.appendColumn(prefColText);
    prefUsedIcons.getSelection.setMode(SelectionMode.BROWSE);
    prefUsedIcons.setReorderable(true);
    prefUsedIcons.addOnShow(delegate void(Widget w)
    {
        PrefLoadUsedButtons();
    });
    prefUsedIcons.addOnCursorChanged(delegate void(TreeView self)
    {
        string[] toolNames;
        TreeIter Usedti = new TreeIter;
        
        UsedStore.getIterFirst(Usedti);
        while(UsedStore.iterIsValid(Usedti))
        {
            toolNames ~= UsedStore.getValueString(Usedti, 2);
            UsedStore.iterNext(Usedti);
        }
        Config.SetArray("ui_toolbar","buttons",toolNames);
        UpdateToolbar();
    });
    
    auto buttons = new ButtonBox(Orientation.VERTICAL);
    auto buttonFrame = new Frame(buttons,"");
    buttons.setLayout(GtkButtonBoxStyle.SPREAD);
    auto addBtn = new Button("Add >>");
    auto delBtn = new Button("Remove XX");
    auto clearBtn = new Button("Clear Toolbar");
    
    addBtn.addOnClicked(delegate void(Button btn)
    {
        auto sourceIter = new TreeIter;
        sourceIter = prefAvailIcons.getSelectedIter();
        if(sourceIter is null) return;
        string AddedTool = AvailStore.getValueString(sourceIter, 2);
        auto selIter = new TreeIter;
        auto destIter = new TreeIter;
        selIter = prefUsedIcons.getSelectedIter();
        if(selIter is null) return;
        UsedStore.insertAfter(destIter, selIter);
        UsedStore.setValue(destIter, 0, new Value(new Pixbuf(mToolObjects[AddedTool].mIconResource)));
        UsedStore.setValue(destIter, 1, new Value(mToolObjects[AddedTool].mName));
        UsedStore.setValue(destIter, 2, new Value(AddedTool));
        string[] toolNames;
        TreeIter Usedti = new TreeIter;        
        UsedStore.getIterFirst(Usedti);
        while(UsedStore.iterIsValid(Usedti))
        {
            toolNames ~= UsedStore.getValueString(Usedti, 2);
            UsedStore.iterNext(Usedti);
        }
        Config.SetArray("ui_toolbar","buttons",toolNames);        
        UpdateToolbar();
        
    });

    buttons.packStart(addBtn, false, false, 4);
    buttons.packStart(delBtn, false, false, 4);
    buttons.packStart(clearBtn, false, false, 4);
    AddAppPreferenceWidget("Toolbar", new Label("Configure Toolbar"));
    AddAppPreferenceWidget("Toolbar", prefAvailIcons, buttonFrame, prefUsedIcons);

}

