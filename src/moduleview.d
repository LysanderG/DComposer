// untitled.d
//
// Copyright 2012 Anthony Goins <neontotem@gmail.com>
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
// MA 02110-1301, USA.


module moduleview;


import elements;
import dcore;
import ui;

import gtk.Builder;
import gtk.VBox;
import gtk.TreeView;
import gtk.Label;
import gtk.Notebook;
import gtk.Widget;
import gtk.Container;


class MODULE_VIEW :ELEMENT
{
	private:

	string 		mName;
	string		mInfo;
	bool		mState;

	Builder		mBuilder;
	VBox		mRootWidget;
	TreeView	mObjectsView;
	TreeView	mMembersView;
	Label		mModuleLabel;

	void UpdateModule()
	{
		auto doc = dui.GetDocMan.Current;
		if(doc is null) mModuleLabel.setText("No module");
		else mModuleLabel.setText(doc.ShortName);
	}

	void SetPagePosition(UI_EVENT uie)
	{
		switch (uie)
		{
			case UI_EVENT.RESTORE_GUI :
			{
				dui.GetSidePane.reorderChild(mRootWidget, Config.getInteger("MODULE_VIEW", "page_position"));
				break;
			}
			case UI_EVENT.STORE_GUI :
			{
				Config.setInteger("MODULE_VIEW", "page_position", dui.GetSidePane.pageNum(mRootWidget));
				break;
			}
			default :break;
		}
	}

	public:

	this()
    {
        mName = "MODULE_VIEW";
        mInfo = "Browse current modules symbols";
        mState = false;

        PREFERENCE_PAGE mPrefPage = null;
    }

    @property string Name() {return mName;}
    @property string Information(){return mInfo;}
    @property bool   State() {return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        if(mState) Engage();
        else Disengage();

    }
    PREFERENCE_PAGE GetPreferenceObject()
	{
		return null;
	}

	void Engage()
	{
		mBuilder = new Builder;

		mBuilder.addFromFile(Config.getString("MODULE_VIEW", "glade_file", "$(HOME_DIR)/glade/moduleview.glade"));

		mRootWidget = cast(VBox)mBuilder.getObject("rootwidget");
		mModuleLabel = cast(Label)mBuilder.getObject("label1");

		dui.GetSidePane.appendPage(mRootWidget, "Module");
		dui.connect(&SetPagePosition);
		dui.GetSidePane.setTabReorderable ( mRootWidget, true);

		dui.GetCenterPane(). addOnSetFocusChild (delegate void(Widget w, Container c){UpdateModule();});

		Log.Entry("Engaged "~Name()~"\t\t\telement.");
	}

	void Disengage()
	{
		Log.Entry("Disengaged "~Name()~"\t\telement.");
	}

}

