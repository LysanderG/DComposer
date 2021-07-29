module ui_toolbar;


import std.stdio;
import std.algorithm;

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
void RemoveToolObject(string id)
{
    mToolObjects.remove("id");
}

void InsertToolButton(string Id, int pos = -1)
{
    if(Id.startsWith("Toggle"))
    {
        InsertToggleButton(Id);
        return;
    }
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

void InsertToggleButton(string Id, int pos = -1)
{
    auto toptr = (Id in mToolObjects);
    if(toptr is null) return;
    TOOL_OBJECT to = *toptr;       
    auto icon = new Image(to.mIconResource);
    ToggleToolButton button = new ToggleToolButton();
    button.setIconWidget(icon);
    button.setLabel(to.mName);
    button.setDetailedActionName(to.mActionName);
    button.setActive(true);
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
    
    void LoadUsedStore()
    {
        foreach(button; Config.GetArray!string("ui_toolbar", "buttons"))
        {
            if(button !in mToolObjects)continue;
            auto tool = mToolObjects[button];     
            auto ti = new TreeIter;
            UsedStore.append(ti);
            UsedStore.setValue(ti, 0, new Value(new Pixbuf(tool.mIconResource)));
            UsedStore.setValue(ti, 1, tool.mName);
            UsedStore.setValue(ti, 2, button);
            UsedStore.setValue(ti, 3, tool.mTooltip);
        }
    }  
    void LoadConfig()
    {
	    auto iter =  new TreeIter;
	    string[] holdingArray;
	    UsedStore.getIterFirst(iter);
	    while(UsedStore.iterIsValid(iter))
	    {
		    holdingArray ~= UsedStore.getValueString(iter, 2);
		    UsedStore.iterNext(iter);
        }
        Config.SetArray("ui_toolbar", "buttons", holdingArray);
   	}

    auto AvailScroll = new ScrolledWindow();
    auto AvailStore = new ListStore([GType.OBJECT, GType.STRING,GType.STRING,GType.STRING]);
    auto prefAvailIcons = new TreeView(AvailStore);
    auto prefCellIcon = new CellRendererPixbuf;
    auto prefCellText = new CellRendererText;
    auto prefColIcon = new TreeViewColumn("icon", prefCellIcon, "pixbuf", 0);
    auto prefColText = new TreeViewColumn("action", prefCellText, "text", 1);
    prefAvailIcons.appendColumn(prefColIcon);
    prefAvailIcons.appendColumn(prefColText);
    prefAvailIcons.setTooltipColumn(3);
    prefAvailIcons.getSelection.setMode(SelectionMode.BROWSE);
    AvailStore.setSortColumnId(1,GtkSortType.ASCENDING); 
    
    
    
    //populate available store    
    foreach(key, tool; mToolObjects)
    {
        auto ti = new TreeIter;
        AvailStore.append(ti);
        AvailStore.setValue(ti, 0, new Value(new Pixbuf(tool.mIconResource)));
        AvailStore.setValue(ti, 1, new Value(tool.mName));
        AvailStore.setValue(ti, 2, new Value(key));
        AvailStore.setValue(ti, 3, new Value(tool.mTooltip));
    }
        
    UsedStore = new ListStore([GType.OBJECT, GType.STRING, GType.STRING, GType.STRING]);
    auto prefUsedIcons = new TreeView(UsedStore);
    auto UsedScroll = new ScrolledWindow();
    prefCellIcon = new CellRendererPixbuf;
    prefCellText = new CellRendererText;
    prefColIcon = new TreeViewColumn("icon", prefCellIcon, "pixbuf", 0);
    prefColText = new TreeViewColumn("action", prefCellText, "text", 1);
    prefUsedIcons.appendColumn(prefColIcon);
    prefUsedIcons.appendColumn(prefColText);
    prefUsedIcons.setTooltipColumn(3);
    prefUsedIcons.getSelection.setMode(SelectionMode.BROWSE);
    prefUsedIcons.setReorderable(true);
    prefUsedIcons.addOnShow(delegate void(Widget w)
    {
        LoadUsedStore();
    });
    prefUsedIcons.addOnCursorChanged(delegate void(TreeView self)
    {
        LoadConfig();
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
        if(selIter is null) UsedStore.append(destIter);
        else UsedStore.insertAfter(destIter, selIter);
        UsedStore.setValue(destIter, 0, new Pixbuf(mToolObjects[AddedTool].mIconResource));
        UsedStore.setValue(destIter, 1, mToolObjects[AddedTool].mName);
        UsedStore.setValue(destIter, 2, AddedTool);
        LoadConfig();        
        UpdateToolbar();
    });
    
    delBtn.addOnClicked(delegate void(Button btn)
    {
	    auto selIter = new TreeIter;
	    selIter = prefUsedIcons.getSelectedIter();
	    UsedStore.remove(selIter);
	    LoadConfig();
	    UpdateToolbar();
    });
    
    clearBtn.addOnClicked(delegate void(Button)
    {
	    UsedStore.clear();
	    LoadConfig();
	    UpdateToolbar();
    });

    buttons.packStart(addBtn, false, false, 4);
    buttons.packStart(delBtn, false, false, 4);
    buttons.packStart(clearBtn, false, false, 4);
    AppPreferenceAddWidget("Toolbar", new Label("Configure Toolbar"));
    AppPreferenceAddWidget("Toolbar", new Separator(Orientation.HORIZONTAL));

    AvailScroll.add(prefAvailIcons);
    AvailScroll.setVexpand(true);
    UsedScroll.add(prefUsedIcons);
    UsedScroll.setVexpand(true);
    AppPreferenceAddWidget("Toolbar", AvailScroll, buttonFrame, UsedScroll);
    
    AppPreferenceAdjustWidget("Toolbar",2, AvailScroll, true, true, 1);
    AppPreferenceAdjustWidget("Toolbar",2, UsedScroll, true, true, 1);

}

