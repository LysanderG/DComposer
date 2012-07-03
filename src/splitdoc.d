// splitdoc.d
// 
// Copyright 2012 Anthony Goins <anthony@LinuxGen11>
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

module splitdoc;

import elements;
import ui;
import document;
import dcore;

import std.stdio;

import gtk.VPaned;
import gtk.HPaned;
import gtk.ScrolledWindow;
import gtk.Label;
import gtk.Action;
import gtk.Widget;

import gsv.SourceView;


class SPLIT_DOCUMENT : ELEMENT
{
	private:

	string		mName;
	string		mInfo;
	bool		mState;

	void UnSplit(DOCUMENT SplitDoc)
	{

		//get documents position so we can put it back all nice and neat
		auto PgIndex = dui.GetCenterPane.pageNum(SplitDoc.PageWidget());

		//remove the "page"
		dui.GetCenterPane.removePage(PgIndex);

		//rip our doc off the old page -- the pane and extradoc should now be discarded (are they??)
		SplitDoc.unparent();

		//create a new page widget(scrollwindow)
		auto NewPage = new ScrolledWindow;
		

		//put our doc on the page
		NewPage.add(SplitDoc);

		//let our doc store the page
		SplitDoc.SetPageWidget(NewPage);

		//let there be light
		NewPage.showAll();

		//stick new page where old page was
		dui.GetCenterPane.insertPageMenu(SplitDoc.PageWidget, SplitDoc.TabWidget, new Label(SplitDoc.ShortName), PgIndex);
		dui.GetCenterPane.setCurrentPage(PgIndex);
		SplitDoc.grabFocus();	
		
	}

	void VSplit()
	{
		
		auto mainDoc = dui.GetDocMan.Current;
		if(mainDoc.PageWidget.classinfo.name == "gtk.VPaned.VPaned") return UnSplit(mainDoc);

		auto extraDoc = new SourceView;		
		extraDoc.setBuffer(dui.GetDocMan.Current.getBuffer());

		//GtkRequisition HowBigYouAre;
		//dui.GetSidePane.sizeRequest(HowBigYouAre);

		GtkAllocation HowBigYouAre;
		HowBigYouAre = dui.GetCenterPane.getAllocation();
		
		auto PageIndex = dui.GetCenterPane.pageNum(mainDoc.PageWidget());
		mainDoc.unparent();				
		dui.GetCenterPane.removePage(PageIndex);
		
		auto ScrollTop = new ScrolledWindow();
		auto ScrollBottom = new ScrolledWindow();
		ScrollBottom.add(extraDoc);
		ScrollTop.add(mainDoc);

		auto VPane = new VPaned(ScrollTop, ScrollBottom);
		
		mainDoc.SetPageWidget(VPane);
		VPane.showAll();
				
		dui.GetCenterPane.insertPageMenu(mainDoc.PageWidget, mainDoc.TabWidget,new Label(mainDoc.ShortName), PageIndex);
		dui.GetCenterPane.setCurrentPage(PageIndex);
				
		VPane.setPosition(HowBigYouAre.height/2);		
		
		mainDoc.grabFocus();

	}

	void HSplit()
	{
		
		auto mainDoc = dui.GetDocMan.Current;
		if(mainDoc.PageWidget.classinfo.name == "gtk.HPaned.HPaned") return UnSplit(mainDoc);

		auto extraDoc = new SourceView;		
		extraDoc.setBuffer(dui.GetDocMan.Current.getBuffer());

		//GtkRequisition HowBigYouAre;
		//dui.GetSidePane.sizeRequest(HowBigYouAre);

		GtkAllocation HowBigYouAre;
		HowBigYouAre = dui.GetCenterPane.getAllocation();
		
		auto PageIndex = dui.GetCenterPane.pageNum(mainDoc.PageWidget());
		mainDoc.unparent();				
		dui.GetCenterPane.removePage(PageIndex);
		
		auto ScrollTop = new ScrolledWindow();
		auto ScrollBottom = new ScrolledWindow();
		ScrollBottom.add(extraDoc);
		ScrollTop.add(mainDoc);

		auto HPane = new HPaned(ScrollTop, ScrollBottom);
		
		mainDoc.SetPageWidget(HPane);
		HPane.showAll();
				
		dui.GetCenterPane.insertPageMenu(mainDoc.PageWidget, mainDoc.TabWidget,new Label(mainDoc.ShortName), PageIndex);
		dui.GetCenterPane.setCurrentPage(PageIndex);
				
		HPane.setPosition(HowBigYouAre.width/2);		
		
		mainDoc.grabFocus();
	}
	
		
	public:

    this()
    {
        mName = "DIR_VIEW";
        mInfo = "Simple File Browser";
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

    void Engage()
    {
		Action VSplitAction = new Action("VSplitAct", "_Vertical Split", "Create a second view", null);
		VSplitAction.setIconName("widget-gtk-vpaned");
		VSplitAction.addOnActivate( delegate void (Action x){VSplit();});
		VSplitAction.setAccelGroup(dui.GetAccel());
		dui.Actions().addActionWithAccel(VSplitAction, "<SHIFT><CONTROL>V");        
        VSplitAction.connectAccelerator();

        dui.AddMenuItem("_Documents", VSplitAction.createMenuItem(), 0);
		dui.AddToolBarItem(VSplitAction.createToolItem());
		dui.GetDocMan.AddContextMenuAction(VSplitAction);

		Action HSplitAction = new Action("HSplitAct", "_Horizontal Split", "Create a second view", null);
		HSplitAction.setIconName("widget-gtk-hpaned");
		HSplitAction.addOnActivate( delegate void (Action x){HSplit();});
		HSplitAction.setAccelGroup(dui.GetAccel());
		dui.Actions().addActionWithAccel(HSplitAction, "<SHIFT><CONTROL>H");        
        HSplitAction.connectAccelerator();

        dui.AddMenuItem("_Documents", HSplitAction.createMenuItem(), 0);
		dui.AddToolBarItem(HSplitAction.createToolItem());
		dui.GetDocMan.AddContextMenuAction(HSplitAction);
		
		Log.Entry("Engaged SPLIT_DOCUMENT element.");
	}

	void Disengage()
	{
		mState = false;
		Log.Entry("Disengaged SPLIT_DOCUMENT element.");
	}

	PREFERENCE_PAGE GetPreferenceObject()
	{
		return null;
	}
}
		
		


