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
import std.conv;
import std.algorithm;

import gtk.Action;
import gtk.TextIter;
import gtk.SeparatorToolItem;

import gsv.SourceMark;
import glib.ListSG;


immutable int BOOKMARK_CATEGORY_PRIORITY = 5;
immutable (char[]) BOOKMARK_CATEGORY_NAME = "bookmark";


class BOOKMARKS : ELEMENT
{
	private:

	string 			mName;
	string			mInfo;
	bool			mState;

	DOG_EAR			mMarkRoot;
	DOG_EAR			mMarkLast;
	DOG_EAR			mMarkCurrent;

	Action			mCreateMarkAct;
	Action			mGotoPrevMarkAct;
	Action			mGotoNextMarkAct;

	string			mNameTracker;


	void WatchDocMan(string Event, DOCUMENT doc)
	{
		if(Event == "AppendDocument")
		{
			doc.setMarkCategoryIconFromStock (BOOKMARK_CATEGORY_NAME, "MARK_ICON");
			doc.setMarkCategoryPriority(BOOKMARK_CATEGORY_NAME, BOOKMARK_CATEGORY_PRIORITY);
		}
		if(Event == "CloseDocument")
		{
			foreach(x;mMarkRoot)x.Update();
			TextIter tistart = new TextIter;
			TextIter tiend = new TextIter;
			doc.getBuffer.getStartIter(tistart);
			doc.getBuffer.getEndIter(tiend);
			doc.getBuffer.removeSourceMarks(tistart, tiend, BOOKMARK_CATEGORY_NAME);
		}
	}


	void Toggle(Action X)
	{
		//is there a book mark present
		//if yes goto remove
		//otherwise goto add
		//thats it
		bool TogglingOff = false;
		int Iline = dui.GetDocMan.GetLineNo();
		if(Iline < 0) return;
		foreach(x; mMarkRoot)
		{
			if(x.GetLine == Iline)
			{
				TogglingOff = true;
				x.Remove();
			}
		}
		if(TogglingOff)
		{
			mMarkCurrent = mMarkRoot;
			return;
		}

		Add();
	}

	void Add()
	{
		DOG_EAR nuMark = new DOG_EAR(NameTracker, dui.GetDocMan.GetName(), dui.GetDocMan.GetLineNo());
		nuMark.Attach(dui.GetDocMan.GetDocument());
		if(mMarkCurrent is mMarkLast) mMarkRoot.InsertAfter(nuMark);
		else mMarkCurrent.InsertAfter(nuMark);
		mMarkCurrent = nuMark;
	}



	void Next(Action X)
	{
		assert(mMarkCurrent !is null);
		if(mMarkRoot.mNext == mMarkLast)return;
		mMarkCurrent = mMarkCurrent.Increment();
		mMarkCurrent.Goto();

	}

	void Prev(Action X)
	{
		assert (mMarkCurrent !is null);
		if(mMarkRoot.mNext == mMarkLast)return;
		mMarkCurrent = mMarkCurrent.Decrement();
		mMarkCurrent.Goto();
	}

	void Save()
	{
		if(Project.Target == TARGET.NULL) return;

		string[] results;

		foreach(x; mMarkRoot)
		{
			if(canFind(Project[SRCFILES], x.GetFileName) || canFind(Project[RELFILES], x.GetFileName))results ~= format("%s:%s",x.GetFileName, x.GetLine);
		}
		Project[BOOKMARK_CATEGORY_NAME] = results;
	}

	void Load()
	{
		scope(failure)
		{
			Clear();
			Log.Entry("BOOKMARKS.Load:Failed to load project bookmarks");
			return;
		}
		string[] results = Project[BOOKMARK_CATEGORY_NAME];

		DOG_EAR PlaceHolder;

		Clear();
		mMarkCurrent = mMarkRoot;
		foreach(r; results)
		{
			auto  rsplit = r.findSplit(":");
			PlaceHolder = new DOG_EAR(NameTracker, rsplit[0], to!int(rsplit[2]));
			mMarkCurrent.InsertAfter(PlaceHolder);
			mMarkCurrent = PlaceHolder;
		}
	}

	void Clear()
	{
		if(mMarkRoot !is null)foreach (x; mMarkRoot)x.Remove();
		mMarkRoot = new DOG_EAR("root_anchor", "anchor", 0);
        mMarkLast = new DOG_EAR("tail_anchor", "anchor", 0);

        mMarkRoot.mPrev = mMarkLast;
        mMarkRoot.mNext = mMarkLast;
        mMarkLast.mNext = mMarkRoot;
        mMarkLast.mPrev = mMarkRoot;

        mMarkCurrent = mMarkRoot;
	}

	void WatchProject(ProEvent event)
	{
		if(event == ProEvent.Saving)Save();
		if(event == ProEvent.Opened)Load();
		if(event == ProEvent.Creating)Clear();
		if(event == ProEvent.Closed)Clear();
		//hmm... what to do with all the extra bookmarks ater opening multiple projects?
	}


	public:
	this()
    {
        mName = "BOOKMARKS";
        mInfo = "Manage and navigate bookmarks.";

        Clear();

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
		Project.Event.connect(&WatchProject);

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
        dui.Actions().addActionWithAccel(mGotoNextMarkAct, "<Ctrl>comma");
        dui.Actions().addActionWithAccel(mGotoPrevMarkAct, "<Ctrl>period");

        dui.AddMenuItem("_Navigate", mCreateMarkAct	.createMenuItem(), 5);
        dui.AddMenuItem("_Navigate", mGotoNextMarkAct.createMenuItem());
        dui.AddMenuItem("_Navigate", mGotoPrevMarkAct.createMenuItem());

        dui.AddToolBarItem(mCreateMarkAct  .createToolItem());
        dui.AddToolBarItem(mGotoNextMarkAct.createToolItem());
        dui.AddToolBarItem(mGotoPrevMarkAct.createToolItem());
        dui.AddToolBarItem(new SeparatorToolItem);



		Log.Entry("Engaged "~Name()~"\t\telement.");
	}

    void Disengage()
    {
		Save();
		Clear();
		dui.GetDocMan.Event.disconnect(&WatchDocMan);
		Project.Event.disconnect(&WatchProject);
		Log.Entry("Disengaged "~Name()~"\t\telement.");
	}

    PREFERENCE_PAGE GetPreferenceObject()
    {
		return null;
	}

	string NameTracker()
	{
		string rv = mNameTracker;
		mNameTracker = mNameTracker.succ();
		return rv;
	}


}


class DOG_EAR
{
	private:

	string 		mID;
	string		mFileName;
	int			mLine;


	SourceMark	mSrcMark;

	DOG_EAR		mNext;
	DOG_EAR		mPrev;
	DOG_EAR		mFront;

	public:

	this(string MarkId, string FileName, int Line)
	{
		mID = MarkId;
		mFileName = FileName;
		mLine = Line;

		mSrcMark = null;
		mNext = null;
		mPrev = null;
		mFront = this;
	}

	void Attach(DOCUMENT Doc)
	{

		TextIter ti = new TextIter;

		Doc.getBuffer.getIterAtMark(ti, Doc.getBuffer.getInsert());

		if(mSrcMark is null)mSrcMark = Doc.getBuffer.createSourceMark(mID, BOOKMARK_CATEGORY_NAME, ti);
		else
		{
			Doc.getBuffer.deleteMarkByName(mSrcMark.getName);
			Doc.getBuffer.addMark(mSrcMark, ti);
		}
	}

	void InsertAfter(DOG_EAR mark)
	{

		mark.mNext = mNext;
		mark.mPrev = this;

		mNext.mPrev = mark;
		mNext = mark;
	}

	void Remove()
	{
		mNext.mPrev = mPrev;
		mPrev.mNext = mNext;
		scope(failure)return;
		if(mSrcMark !is null)
		{
			if(mSrcMark.getBuffer !is null)
			{
				 mSrcMark.getBuffer.deleteMarkByName(mSrcMark.getName());
			}
		}

	}

	void Goto()
	{
		if(mSrcMark is null)
		{
			dui.GetDocMan.Open(mFileName, mLine);
			Attach(dui.GetDocMan.GetDocument);
			return;
		}
		if(mSrcMark.getDeleted())
		{
			dui.GetDocMan.Open(mFileName, mLine);
			Attach(dui.GetDocMan.GetDocument);
			return;
		}

		if(mID == "root_anchor") return;
		if(mID == "tail_anchor") return;
		TextIter ti = new TextIter;
		mSrcMark.getBuffer.getIterAtMark(ti, mSrcMark);
		dui.GetDocMan.Open(mFileName, ti.getLine());
		Attach(dui.GetDocMan.GetDocument);
	}


	int GetLine()
	{
		if(mSrcMark is null) return mLine;
		if(mSrcMark.getBuffer is null) return mLine;
		TextIter ti = new TextIter;
		mSrcMark.getBuffer.getIterAtMark(ti, mSrcMark);
		return ti.getLine();
	}
	void Update()
	{
		mLine = GetLine();
	}

	string GetFileName(){return mFileName;}

	SourceMark GetMark(){return mSrcMark;}



	@property bool empty()
	{

		if((mFront.mID == "root_anchor") && (mFront.mNext.mID == "tail_anchor")) return true;
		if(mFront.mID == "tail_anchor")
		{
			mFront = this; //should be root_anchor
			return true;
		}
		return false;
	}

	@property ref DOG_EAR front()
	{
		if(mFront.mID == "root_anchor")mFront = mFront.mNext;
		return  mFront;
	}

	void popFront()
	{
		mFront = mFront.mNext;
	}


	DOG_EAR Increment()
	{
		auto rv = this.mNext;
		if(rv.mID == "tail_anchor") rv = rv.mNext;
		if(rv.mID == "root_anchor") rv = rv.mNext;
		return rv;
	}

	DOG_EAR Decrement()
	{
		auto rv = this.mPrev;

		if(rv.mID == "root_anchor") rv = rv.mPrev;
		if(rv.mID == "tail_anchor") rv = rv.mPrev;
		return rv;
	}
}




