// bookmarks.d
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

module bookmarks;

import dcore;
import ui;
import elements;
import document;

import std.stdio;
import std.string;

import gtk.Action;
import gtk.TextIter;

import gsv.SourceMark;


immutable int BOOKMARK_CATEGORY_PRIORITY = 5;


struct MARK
{
	string 		mFile;
	string  	mMarkName;
	SourceMark 	mSrcMark;

	static string mName = "BookMark_aaaa";

	this(DOCUMENT Doc, string MarkName)
	{
		mFile = Doc.Name;
		mMarkName = MarkName;

		TextIter ti = new TextIter;

		Doc.getBuffer.getIterAtMark(ti, Doc.getBuffer.getInsert());
		
		mSrcMark = Doc.getBuffer. createSourceMark (mMarkName,"bookmark", ti);
	}
}


class BOOKMARKS : ELEMENT
{

	private:
	
	string 			mName;
	string			mInfo;
	bool			mState;

	MARK[string]	mMarks;

	Action			mCreateMarkAct;
	Action			mGotoPrevMarkAct;
	Action			mGotoNextMarkAct;

	string			mMarkNames;
	string[]		mMarkNamesInOrder;
	int				mOrderIndex;

	
	void WatchDocMan(string Event, DOCUMENT doc)
	{
		doc.setMarkCategoryIconFromStock ("bookmark", "MARK_ICON");
		doc.setMarkCategoryPriority("bookmark", BOOKMARK_CATEGORY_PRIORITY);		
	}

	void Toggle(Action x)
	{
		SourceMark tmpMark;
		auto line = dui.GetDocMan.GetLineNo;
		if(line < 1)return;

		auto MarksAtLine = dui.GetDocMan.GetDocument.getBuffer.getSourceMarksAtLine(dui.GetDocMan.GetLineNo(), "bookmark");
		if(MarksAtLine !is null)
		{
			while(MarksAtLine !is null)
			{
				
				auto structptr = cast(GtkSourceMark*)MarksAtLine.data();
				tmpMark = new SourceMark(structptr);
				writeln(tmpMark);
				//mMarks.remove(tmpMark.getName());
				writeln(tmpMark);
				dui.GetDocMan.GetDocument.getBuffer.deleteMarkByName(tmpMark.getName());
				writeln(tmpMark);
				MarksAtLine = MarksAtLine.next();
				writeln(tmpMark);
			}
			writeln(mMarks);
			return;	
		}
		else
		{
			MARK nuMark = MARK(dui.GetDocMan.GetDocument(), mMarkNames);
			mMarks[mMarkNames] = nuMark;
			mMarkNamesInOrder ~= mMarkNames;
			mOrderIndex++;
			mMarkNames = mMarkNames.succ();
		}
	}

	void Next(Action x)
	{
		if(mMarks.length < 1) return;
		auto startingIndex = mOrderIndex;
		mOrderIndex++;
		if(mOrderIndex >= mMarkNamesInOrder.length) mOrderIndex = 0;

		writeln(mMarks, mOrderIndex, mMarkNamesInOrder[mOrderIndex]);
		while(mMarks[mMarkNamesInOrder[mOrderIndex]].mSrcMark.getDeleted is true)
		{
			mOrderIndex++;
			if(mOrderIndex > mMarkNamesInOrder.length) mOrderIndex = 0;
			if(mOrderIndex == startingIndex) return;
		}

		TextIter ti = new TextIter;
		string file = mMarks[mMarkNamesInOrder[mOrderIndex]].mFile;
		mMarks[mMarkNamesInOrder[mOrderIndex]].mSrcMark.getBuffer.getIterAtMark(ti, mMarks[mMarkNamesInOrder[mOrderIndex]].mSrcMark);
		int	line = ti.getLine();

		dui.GetDocMan.Open(file, line);	
		
	}
		
		

	
	public:
	this()
    {
        mName = "BOOKMARKS";
        mInfo = "Set and jump to the important parts of a document.";

        mMarkNames = "dogear_aaaa";
        mOrderIndex = -1;
    }
    
    @property string Name(){ return mName;}
    @property string Information(){return mInfo;}
    @property bool   State(){ return mState;}
    @property void   State(bool nuState)
    {
        mState = nuState;
        
        if(mState)  Engage();
        else        Disengage();
    }

    void Engage()
    {
		dui.GetDocMan.Event.connect(&WatchDocMan);

		dui.AddIcon("MARK_CREATE",		Config.getString("ICONS", "mark_create", "$(HOME_DIR)/glade/book-open-bookmark.png"));
		dui.AddIcon("MARK_NEXT",		Config.getString("ICONS", "mark_next"  , "$(HOME_DIR)/glade/book-open-next.png"));
		dui.AddIcon("MARK_PREV",		Config.getString("ICONS", "mark_prev"  , "$(HOME_DIR)/glade/book-open-previous.png")); 
		dui.AddIcon("MARK_ICON",		Config.getString("ICONS", "mark_icon"  , "$(HOME_DIR)/glade/bookmark.png"));
		
		mCreateMarkAct		= new Action("MarkCreateAct"	, "_Book Mark"  , "Toggle Bookmark"	, "MARK_CREATE");
		mGotoNextMarkAct	= new Action("MarkNextAct"  	, "_Next" , "goto next bookmark"	, "MARK_NEXT");
		mGotoPrevMarkAct	= new Action("MarkPrevAct"  	, "_Prev" , "goto previous bookmark"	, "MARK_PREV");

		mCreateMarkAct	.addOnActivate(&Toggle);
		mGotoNextMarkAct.addOnActivate(&Next);
		//mGotoPrevMarkAct.addOnActivate(&Prev);

		mCreateMarkAct	.setAccelGroup(dui.GetAccel());
		mGotoNextMarkAct.setAccelGroup(dui.GetAccel());
		mGotoPrevMarkAct.setAccelGroup(dui.GetAccel());

		dui.Actions().addActionWithAccel(mCreateMarkAct	, "<Ctrl>M");
        dui.Actions().addActionWithAccel(mGotoNextMarkAct, "<Ctrl>,");
        dui.Actions().addActionWithAccel(mGotoPrevMarkAct, "<Ctrl>.");

        dui.AddMenuItem("_Navigate", mCreateMarkAct	.createMenuItem());
        dui.AddMenuItem("_Navigate", mGotoNextMarkAct.createMenuItem());
        dui.AddMenuItem("_Navigate", mGotoPrevMarkAct.createMenuItem());

        dui.AddToolBarItem(mCreateMarkAct  .createToolItem());
        dui.AddToolBarItem(mGotoNextMarkAct.createToolItem());
        dui.AddToolBarItem(mGotoPrevMarkAct.createToolItem());

		

		Log.Entry("Engaged BOOKMARKS");		
	}

    void Disengage()
    {
		dui.GetDocMan.Event.disconnect(&WatchDocMan);
	}

    PREFERENCE_PAGE GetPreferenceObject()
    {
		return null;
	}

}
