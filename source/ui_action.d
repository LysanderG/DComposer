module ui_action;

import gtk.MenuItem;
import gtk.ToolItem;
import gtk.ToolButton;
import gio.SimpleAction;
import gio.ActionIF;
import gtk.AccelGroup;
import glib.VariantType;
import glib.Variant;
import gtk.AccelMap;

struct UI_ACTION
{
	SimpleAction 	mAction;
	string 			mName;
	string 			mLabel;
	string 			mTooltip;
	string 			mStatus;
	bool   			mEnabled;
	bool   			mState;
	AccelGroup		mAccGroup;
	char 			mAccKey;
	GdkModifierType mAccModifier;		
	AccelMap        mAccelMap;
	
	this(string ID_Name, string Label, string Tooltip, char AcceleratorKey, GdkModifierType AcceleratorModifier)
	{
		mName = ID_Name;
		mLabel = Label;
		mTooltip = Tooltip;
		mAccKey = AcceleratorKey;
		mAccModifier = AcceleratorModifier;
		mStatus = Label;
		mState = true;
		
		mAction = new SimpleAction(ID_Name, new VariantType("i"), new Variant(100));
		AccelMap.addEntry("win", AcceleratorKey, AcceleratorModifier);
		
    }
	

	void delegate(MenuItem mi) mMenuDlg;

	MenuItem CreateMenuItem()
	{
		return new MenuItem(mMenuDlg, mLabel, mName, true, mAccGroup, mAccKey, mAccModifier, cast(GtkAccelFlags)1);
    }
	ToolButton CreateToolButton()
	{
		return new ToolButton(mName);
	}	
	
}
