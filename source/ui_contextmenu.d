module ui_contextmenu;

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





void AddMenuPart(string label, MI_DLG miDlg, string action)
{
    MENU_PARTS mp = MENU_PARTS(label, miDlg, action);
    mItems ~= mp;
}


MenuItem[] GetContextItems()
{
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
