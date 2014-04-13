module ui_contextmenu;


import dcore;
import ui;
import document;

import gobject.ObjectG;
import gtk.Misc;

extern (C) GtkWidget * gtk_widget_new();

UI_CONTEXTMENU uiContextMenu;

class UI_CONTEXTMENU //class just so I can use signals!
{
	void Engage()
	{
		DocMan.Event.connect(&WatchForNewDocuments);

		Log.Entry("Engaged");
	}
	void PostEngage()
	{
		Log.Entry("Post Engaged");
	}
	void Disengage()
	{
		DocMan.Event.disconnect(&WatchForNewDocuments);
		Log.Entry("Disengaged");
	}

	void AddAction(string ActionName)
	{

		if(GetAction(ActionName) is null) return;
		ContextMenuItems ~= ActionName;

	}
	void AddSubMenu(string Title, string[] ActionNames)
	{}

	private:

	string[] ContextMenuItems;
	void WatchForNewDocuments(string EventName, DOC_IF Doc)
	{
		if((EventName == "Create") || (EventName == "Open"))
		{
			auto xDoc = cast(DOCUMENT) Doc;
			xDoc.addOnPopulatePopup(delegate void(Widget BasicWidget, TextView tv)
			{
				auto xptr = BasicWidget.getWidgetStruct();
				Menu x2 = new Menu(cast(GtkMenu*)xptr);
				auto sep1 = new SeparatorMenuItem;
				//sep1.setLabel("");
				x2.append(sep1);

				foreach(item; ContextMenuItems)
				{
					x2.append(GetAction(item).createMenuItem);
				}
				x2.append(new SeparatorMenuItem);
				x2.showAll();
			});
		}
	}
}

