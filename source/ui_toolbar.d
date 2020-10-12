module ui_toolbar;

import quore;
import ui;


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
    string[] buttonsOnBar = Config.GetArray("ui_toolbar", "buttons", ["preferences", "docnew","docopen","docsave","docclose","quit"]);
    buttonsOnBar.each!InsertToolButton();
    Log.Entry("\tToolbar Meshed");
}

void DisengageToolbar()
{
    Config.SetValue("ui_toolbar","visible",mToolbar.getVisible());
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
