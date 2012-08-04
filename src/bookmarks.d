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
import glib.ListSG;


immutable int BOOKMARK_CATEGORY_PRIORITY = 5;
immutable (char[]) BOOKMARK_CATEGORY_NAME = "bookmark";


class MARK
{

	private:
	
	string 		mFileName;
	SourceMark 	mSrcMark;

	MARK		mPrev;
	MARK		mNext;

	public:
	this(string MarkId, string filename = null)
	{
		mSrcMark = new SourceMark(MarkId, BOOKMARK_CATEGORY_NAME);
		if(filename is null) filename = dui.GetDocMan.GetDocument.Name;
		mFileName = filename;

		mPrev = null;
		mNext = null;
	}

	void Add(MARK mark)
	{
		mark.mNext = mNext;
		mark.mPrev = this;
		
		mNext.mPrev = mark;
		mNext = mark;

		TextIter ti = new TextIter;

		dui.GetDocMan.GetDocument.getBuffer.getIterAtMark(ti, dui.GetDocMan.GetDocument.getBuffer.getInsert());
		
		dui.GetDocMan.GetDocument.getBuffer.addMark (mark.Mark, ti);
		
	}

	void Remove()
	{
		mNext.Prev = mPrev;
		mPrev.Next = mNext;

		writeln(mNext.Prev.Name, " ------ ", mPrev.Next.Name);
	}

	@property SourceMark Mark(){return mSrcMark;}
	@property MARK Next(){ return mNext;}
	@property MARK Prev(){ return mPrev;}

	@property void Next(MARK X){mNext = X;}
	@property void Prev(MARK X){mPrev = X;}
	
	@property string Name()
	{
		return mSrcMark.getName();
	}

	@property string FileName(){return mFileName;}

	@property int LineNumber()
	{
		TextIter ti = new TextIter;		
		mSrcMark.getBuffer.getIterAtMark(ti, mSrcMark);
		return ti.getLine();
	}		


}


class BOOKMARKS : ELEMENT
{
	private:

	string 			mName;
	string			mInfo;
	bool			mState;
	
	MARK 			mMarkRoot;
	MARK			mMarkLast;
	MARK			mMarkCurrent;

	Action			mCreateMarkAct;
	Action			mGotoPrevMarkAct;
	Action			mGotoNextMarkAct;

	string			mNameTracker;
	

	void WatchDocMan(string Event, DOCUMENT doc)
	{
		doc.setMarkCategoryIconFromStock (BOOKMARK_CATEGORY_NAME, "MARK_ICON");
		doc.setMarkCategoryPriority(BOOKMARK_CATEGORY_NAME, BOOKMARK_CATEGORY_PRIORITY);		
	}


	void Toggle(Action X)
	{
		//is there a book mark present
		//if yes goto remove
		//otherwise goto add
		//thats it
		int Iline = dui.GetDocMan.GetLineNo();
		ListSG ExistingMarksList = dui.GetDocMan.GetDocument.getBuffer. getSourceMarksAtLine (Iline, BOOKMARK_CATEGORY_NAME); 
		if(ExistingMarksList) Remove(ExistingMarksList);
		else Add();

		return;	
	}

	void Add()
	{
		MARK nuMark = new MARK(mNameTracker);		
		mNameTracker = mNameTracker.succ();
		if(mMarkCurrent is mMarkLast) mMarkRoot.Add(nuMark);
		else mMarkCurrent.Add(nuMark);
		mMarkCurrent = nuMark;
	}

	void Remove(ListSG OldMarks)
	{
		SourceMark tmpMark;
		while(OldMarks !is null)
		{
			
			auto structptr = cast(GtkSourceMark*)OldMarks.data();
			tmpMark = new SourceMark(structptr);				
			dui.GetDocMan.GetDocument.getBuffer.deleteMarkByName(tmpMark.getName());

			mMarkCurrent = mMarkRoot.Next;

			while(mMarkCurrent !is mMarkLast)
			{
				if( mMarkCurrent.Name == tmpMark.getName())
				{
					writeln( mMarkCurrent.Name, " " , tmpMark.getName());
					mMarkCurrent.Remove(); //still alive and prev and next valid
					mMarkCurrent = mMarkCurrent.Next();
					if(mMarkCurrent is mMarkLast) mMarkCurrent = mMarkLast.Prev;
					break;
				}
				mMarkCurrent = mMarkCurrent.Next();
			}
			OldMarks = OldMarks.next();
		}
		return;			
	}

	void Next(Action X)
	{
		bool FixForClosedFiles = false;
		assert (mMarkCurrent !is null);
		if(mMarkCurrent is mMarkLast) return; //no bookmarks
		if(mMarkCurrent is mMarkRoot) return; //no bookmarks
		mMarkCurrent = mMarkCurrent.Next();
		if(mMarkCurrent is mMarkLast) mMarkCurrent = mMarkRoot.Next;
		if(!dui.GetDocMan.IsOpen(mMarkCurrent.FileName)) FixForClosedFiles = true;
		dui.GetDocMan.Open(mMarkCurrent.FileName, mMarkCurrent.LineNumber);
		if(FixForClosedFiles)
		{
			writeln( "--",mMarkCurrent.Mark.getCategory);
			writeln(mMarkCurrent.Mark.getBuffer());
			mMarkCurrent.Mark.getBuffer.deleteMark(mMarkCurrent.Mark);
			TextIter ti = new TextIter;
			dui.GetDocMan.GetDocument.getBuffer.getIterAtMark(ti, dui.GetDocMan.GetDocument.getBuffer.getInsert());		
			dui.GetDocMan.GetDocument.getBuffer.addMark (mMarkCurrent.Mark, ti);
		}
	}

	void Prev(Action X)
	{
		bool FixForClosedFiles;
		assert (mMarkCurrent !is null);
		if(mMarkCurrent is mMarkLast) return; //no bookmarks
		if(mMarkCurrent is mMarkRoot) return; //no bookmarks
		mMarkCurrent = mMarkCurrent.Prev();
		if(mMarkCurrent is mMarkRoot) mMarkCurrent = mMarkLast.Prev;
		if(!dui.GetDocMan.IsOpen(mMarkCurrent.FileName))FixForClosedFiles = true;
		dui.GetDocMan.Open(mMarkCurrent.FileName, mMarkCurrent.LineNumber);
		if(FixForClosedFiles)
		{
			writeln( "--",mMarkCurrent.Mark.getCategory);
			writeln(mMarkCurrent.Mark.getBuffer());
			mMarkCurrent.Mark.getBuffer.deleteMark(mMarkCurrent.Mark);
			TextIter ti = new TextIter;
			dui.GetDocMan.GetDocument.getBuffer.getIterAtMark(ti, dui.GetDocMan.GetDocument.getBuffer.getInsert());		
			dui.GetDocMan.GetDocument.getBuffer.addMark (mMarkCurrent.Mark, ti);
		}
	}

	void Save()
	{
	}

	void Load()
	{
	}

	void Clear()
	{
		mMarkRoot = null;
		mMarkCurrent = mMarkRoot;
		//could do gc collection here... ??
	}


	public:
	this()
    {
        mName = "BOOKMARKS";
        mInfo = "Manage and navigate bookmarks.";

        mMarkRoot = new MARK("root_anchor", "anchor");
        mMarkLast = new MARK("tail_anchor", "anchor");

        mMarkRoot.Prev = mMarkLast;
        mMarkRoot.Next = mMarkLast;
        mMarkLast.Next = mMarkRoot;
        mMarkLast.Prev = mMarkRoot;

        mMarkCurrent = mMarkLast;
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
		mNameTracker = "bookmark_aaaa";
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
		mGotoPrevMarkAct.addOnActivate(&Prev);

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
    {}

    PREFERENCE_PAGE GetPreferenceObject()
    {
		return null;
	}


}
	
