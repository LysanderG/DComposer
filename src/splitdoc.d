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
import gtk.SeparatorMenuItem;
import gtk.SeparatorToolItem;

import gsv.SourceView;


class SPLIT_DOCUMENT : ELEMENT
{
	private:

	string		mName;
	string		mInfo;
	bool		mState;

	bool msetAutoIndent;
	bool msetIndentOnTab;
	bool msetInsertSpacesInsteadOfTabs;
	bool msetHighlightCurrentLine;
	bool msetShowLineNumbers;
	bool msetShowRightMargin;
	int  msetRightMarginPosition;
	int  msetIndentWidth;
	int  msetTabWidth;
	string mmodifyFont;
	SourceSmartHomeEndType msetSmartHomeEnd;
	

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
		if(mainDoc is null)return;
		if(mainDoc.PageWidget.classinfo.name == "gtk.VPaned.VPaned") return UnSplit(mainDoc);

		auto extraDoc = new SourceView;		
		extraDoc.setBuffer(dui.GetDocMan.Current.getBuffer());
		ConfigExtraDoc(extraDoc);

		GtkAllocation HowBigYouAre;
		HowBigYouAre = dui.GetCenterPane.getAllocation();
		
		auto ScrollTop = new ScrolledWindow();
		auto ScrollBottom = new ScrolledWindow();
		ScrollBottom.add(extraDoc);


		auto VPane = new VPaned(ScrollTop, ScrollBottom);
		
		auto PageIndex = dui.GetCenterPane.pageNum(mainDoc.PageWidget());
		mainDoc.reparent(ScrollTop);				
		dui.GetCenterPane.removePage(PageIndex);
		
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
		if(mainDoc is null) return;
		if(mainDoc.PageWidget.classinfo.name == "gtk.HPaned.HPaned") return UnSplit(mainDoc);

		auto extraDoc = new SourceView;		
		extraDoc.setBuffer(dui.GetDocMan.Current.getBuffer());
		ConfigExtraDoc(extraDoc);

		GtkAllocation HowBigYouAre;
		HowBigYouAre = dui.GetCenterPane.getAllocation();
				
		auto ScrollTop = new ScrolledWindow();
		auto ScrollBottom = new ScrolledWindow();
		ScrollBottom.add(extraDoc);


		auto HPane = new HPaned(ScrollTop, ScrollBottom);

		auto PageIndex = dui.GetCenterPane.pageNum(mainDoc.PageWidget());

		mainDoc.reparent(ScrollTop);				

		dui.GetCenterPane.removePage(PageIndex);
		mainDoc.SetPageWidget(HPane);
		HPane.showAll();
				
		dui.GetCenterPane.insertPageMenu(mainDoc.PageWidget, mainDoc.TabWidget,new Label(mainDoc.ShortName), PageIndex);
		dui.GetCenterPane.setCurrentPage(PageIndex);
				
		HPane.setPosition(HowBigYouAre.width/2);		
		
		mainDoc.grabFocus();
	}

	void ConfigExtraDoc(SourceView ExtraDoc)
	{

		ExtraDoc.setAutoIndent(msetAutoIndent);
        ExtraDoc.setIndentOnTab(msetIndentOnTab);
        ExtraDoc.setInsertSpacesInsteadOfTabs(msetInsertSpacesInsteadOfTabs);

		if(Config.getBoolean("DOCMAN", "smart_home_end", true))ExtraDoc.setSmartHomeEnd(msetSmartHomeEnd);
        else ExtraDoc.setSmartHomeEnd(msetSmartHomeEnd);

		ExtraDoc.setHighlightCurrentLine(msetHighlightCurrentLine);
        ExtraDoc.setShowLineNumbers(msetShowLineNumbers);
        ExtraDoc.setShowRightMargin(msetShowRightMargin);
        ExtraDoc.setRightMarginPosition(msetRightMarginPosition);
        ExtraDoc.setIndentWidth(msetIndentWidth);
        ExtraDoc.setTabWidth(msetTabWidth);

        ExtraDoc.modifyFont(pango.PgFontDescription.PgFontDescription.fromString(mmodifyFont));

	}
	
		
	public:

    this()
    {
        mName = "SPLIT_DOCUMENT";
        mInfo = "Split Documents into 2 views";
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

		dui.AddIcon("split-horizontal", Config.getString("ICONS", "split_horizontal", "$(HOME_DIR)/glade/layout-split.png"));
		dui.AddIcon("split-vertical", Config.getString("ICONS", "split_vertical", "$(HOME_DIR)/glade/layout-split-vertical.png"));
		
		Action VSplitAction = new Action("VSplitAct", "_Vertical Split", "Create a second view", "split-vertical");
		
		VSplitAction.addOnActivate( delegate void (Action x){VSplit();});
		VSplitAction.setAccelGroup(dui.GetAccel());
		dui.Actions().addActionWithAccel(VSplitAction, "<SHIFT><CONTROL>V");        
        VSplitAction.connectAccelerator();

		dui.AddMenuItem("_Documents",new SeparatorMenuItem()    );
		
        dui.AddMenuItem("_Documents", VSplitAction.createMenuItem());
		dui.AddToolBarItem(VSplitAction.createToolItem());
		dui.GetDocMan.AddContextMenuAction(VSplitAction);

		Action HSplitAction = new Action("HSplitAct", "_Horizontal Split", "Create a second view", "split-horizontal");
		
		HSplitAction.addOnActivate( delegate void (Action x){HSplit();});
		HSplitAction.setAccelGroup(dui.GetAccel());
		dui.Actions().addActionWithAccel(HSplitAction, "<SHIFT><CONTROL>H");        
        HSplitAction.connectAccelerator();

        dui.AddMenuItem("_Documents", HSplitAction.createMenuItem());
		dui.AddToolBarItem(HSplitAction.createToolItem());
		dui.GetDocMan.AddContextMenuAction(HSplitAction);
		dui.AddToolBarItem(new SeparatorToolItem);

		Config.Reconfig.connect(&Configure);
		Configure();
		
		Log.Entry("Engaged "~Name()~"\t\telement.");
	}

	void Disengage()
	{
		mState = false;
		Log.Entry("Disengaged "~Name()~"\telement.");
	}

	PREFERENCE_PAGE GetPreferenceObject()
	{
		return null;
	}


	void Configure()
	{
		
		msetAutoIndent = Config.getBoolean("DOCMAN", "auto_indent", true);
        msetIndentOnTab = Config.getBoolean("DOCMAN", "indent_on_tab", true);
        msetInsertSpacesInsteadOfTabs = Config.getBoolean("DOCMAN","spaces_for_tabs", true);

		if(Config.getBoolean("DOCMAN", "smart_home_end", true))  msetSmartHomeEnd = SourceSmartHomeEndType.AFTER;
        else msetSmartHomeEnd = SourceSmartHomeEndType.DISABLED;

		msetHighlightCurrentLine = Config.getBoolean("DOCMAN", "hilite_current_line", false);
        msetShowLineNumbers = Config.getBoolean("DOCMAN", "show_line_numbers",true);
        msetShowRightMargin = Config.getBoolean("DOCMAN", "show_right_margin", true);

        msetRightMarginPosition = Config.getInteger("DOCMAN", "right_margin", 120);
        msetIndentWidth = Config.getInteger("DOCMAN", "indention_width", 8);
        msetTabWidth = Config.getInteger("DOCMAN", "tab_width", 4);

        mmodifyFont = Config.getString("DOCMAN", "font", "mono 18");
		
	}
		
}
		
		


