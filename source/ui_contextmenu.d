module ui_contextmenu;

import std.algorithm;

import gtk.Menu;
import gtk.MenuItem;


import ui;
import log;


void EngageContextMenu()
{

    Log.Entry("Engaged");
}

void MeshContextMenu()
{
    Log.Entry("Meshed");
}
void DisengageContextMenu()
{
    Log.Entry("Disengaged");
}





MENU_PARTS AddMenuPart(string label, MI_DLG miDlg, string action)
{
    MENU_PARTS mp = MENU_PARTS(label, miDlg, action);
    mItems ~= mp;
    return mp;
}

void RemoveMenuPart(MENU_PARTS mp)
{
    dwrite(mItems.length, " -- ", mItems);
    remove!(a=> a==mp)(mItems);
    MENU_PARTS[] nuItems;
    foreach(ref idem; mItems)
    {
        if(mp.mLabel != idem.mLabel)nuItems ~= idem;
    }
    mItems = nuItems;
    dwrite(mItems.length, " -- ", mItems);
}



MenuItem[] GetContextItems()
{
    dwrite(mItems);
    MenuItem[] rv;
    foreach(item; mItems)rv ~= item.Build();
    return rv;
}


MENU_PARTS[] mItems;

alias MI_DLG = void delegate (MenuItem);
struct MENU_PARTS
{
    string mLabel;
    MI_DLG mDelegate;
    string mAction;
    
    MenuItem Build()
    {
        return new MenuItem(mLabel, mDelegate, mAction);
    }
}
