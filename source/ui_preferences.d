module ui_preferences;

import gtk.Box;
import gtk.Dialog;
import gtk.Notebook;
import gtk.Widget;

import ui;
import qore;

private Widget[][string] sectionWidgets;
//void AddAppPreferenceWidget(string Page, Widget[] rowComponents ...)
void AppPreferenceAddWidget(string Page, Widget[] rowComponents ...)
{
	if(rowComponents.length == 1)
	{
		sectionWidgets[Page] ~= rowComponents[0];
		rowComponents[0].hideOnDelete;
		return;
    }
    auto listRow = new Box(Orientation.HORIZONTAL,4);
    listRow.setHomogeneous(true);
    foreach(component; rowComponents) listRow.packStart(component, false, false, 24);
    listRow.hideOnDelete();
    sectionWidgets[Page] ~= listRow;
}

void AppPreferenceAdjustWidget(string Page, int row, Widget item, bool expand, bool fill, int padding)
{
    Box box = cast(Box)sectionWidgets[Page][row];
    box.setChildPacking(item, expand, fill, padding, PackType.START);
}

void AppPreferencesShow()
{
    Transmit.PreferencesUpdateUI.emit();
    auto prefs = AppPreferencesBuild();
    prefs.run();
    prefs.hide();
    foreach(page; sectionWidgets)foreach(wiget; page)wiget.unparent();
}   
Dialog AppPreferencesBuild()
{
    auto rv = new Dialog("DCOMPOSER PREFERENCES", mMainWindow, DialogFlags.MODAL, ["Finished"], [ResponseType.CLOSE]);
    auto content = rv.getContentArea();    
    auto pageBook = new Notebook();
    pageBook.setVexpand(true);
    content.add(pageBook);
    
    foreach(string label, page; sectionWidgets)
    {
        auto vbox = new Box(Orientation.VERTICAL, 10);
        pageBook.appendPage(vbox, label);
        foreach(sect; page) 
        {
            vbox.packStart(sect, false, true, 1);   
        }
    }
    pageBook.setCurrentPage(0);
    rv.showAll();
    
    return rv;
}  
