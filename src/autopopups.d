// untitled.d
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


module autopopups;

import ui;
import docman;
import document;

import dcore;

import symbols;

import std.stdio;
import std.algorithm;
import std.xml;
import std.signals;
import std.string;


import gtk.Builder;
import gtk.TreeView;
import gtk.TreeIter;
import gtk.TextIter;
import gtk.Window;
import gtk.ListStore;
import gtk.TextView;
import gtk.TextIter;
import gtk.Widget;
import gtk.TreePath;
import gtk.TreeViewColumn;
import gtk.TreeModelIF;

import gdk.Rectangle;
import gdk.Keysyms;

import glib.SimpleXML;


enum :int {POP_TYPE_TIP, POP_TYPE_SCOPE, POP_TYPE_COMPLETION}
enum :int {STATUS_OFF, STATUS_COMPLETION, STATUS_SCOPE}

immutable uint MAX_TIP_DEPTH = 24;


private struct DATA_STORE
{
    private     ListStore   mStore;
    private     TreeIter    mIter;

    private 	GtkListStore * GtkStore;

    DSYMBOL[]   mMatches;

    long        mXPos;
    long        mYPos;
    long 		mYLen;

    this(DSYMBOL[] nuPossibles, long Xpos, long Ypos, long Ylen, bool tip = false)
    {
		mMatches = nuPossibles;

        mXPos = Xpos;
        mYPos = Ypos;
        mYLen = Ylen;


        mStore = new ListStore([GType.STRING, GType.STRING, GType.STRING]);
        GtkStore = mStore.getListStoreStruct();
        mIter = new TreeIter;

        sort!("a.Name < b.Name")(mMatches);
        if(tip) //this is a call tip needs to show the call signature
        {

            foreach(match; mMatches)
            {
                if(!((match.Kind == SymKind.FUNCTION) || (match.Kind == SymKind.CONSTRUCTOR))) continue;
                mStore.append(mIter);

                //string signature = match.FullType[0..x] ~" "~ match.Name ~" "~ match.FullType[x..$];
                string signature = match.Signature;
                mStore.setValue(mIter, 0,  match.Icon ~ std.xml.encode(signature));
                mStore.setValue(mIter, 1, std.xml.encode(match.Path));
                //mStore.setValue(mIter, 2, std.xml.decode(match.Comment));

            }
            return;
        }
        foreach(match; uniq!("a.Name == b.Name")(mMatches))
        {
			match.Name = encode(match.Name);
            mStore.append(mIter);
            mStore.setValue(mIter, 0, match.Icon ~ std.xml.encode( match.Name));
            mStore.setValue(mIter, 1, std.xml.encode(match.Path));
            //mStore.setValue(mIter, 2, std.xml.decode(match.Comment));
        }
    }

    ListStore GetModel() {return mStore;}
}



class AUTO_POP_UPS
{

    private:

    Builder     mCompletionBuilder;
    Builder     mTipsBuilder;

    int         mWinXlen;
    int         mWinYlen;
    double      mWinOpacity;

    Window      mCompletionWin;
    DATA_STORE  mCompletionStore;
    int         mCompletionStatus;
    TreeView    mCompletionView;

    Window                      mTipsWin;
    DATA_STORE[MAX_TIP_DEPTH]   mTipsStore;
    int 	                    mTipsIndex;
    TreeView                    mTipsView;



	immutable int padding = 3;

    void WatchForNewDocuments(string EventType, DOCUMENT DocXIf)
    {
        auto DocX = cast(DOCUMENT)DocXIf;
        if(EventType != "AppendDocument") return;

        DocX.addOnFocusOut(delegate bool (GdkEventFocus* EvntFocus, Widget wydjit) {Kill();return false;});
        DocX.addOnKeyPress(&CaptureDocumentKeys);
        //DocX.addOnKeyRelease(&CaptureDocumentKeys);
        DocX.addOnButtonPress(&CaptureDocumentButtons);
    }

    bool CaptureDocumentKeys(GdkEventKey * EvntKey, Widget Wydjit)
    {
        if (!PopUpVisible()) return false;
        //if (EvntKey.type == EventType.KEY_RELEASE) return true;

        DOCUMENT docX = cast(DOCUMENT) Wydjit;


        switch (EvntKey.keyval)
        {
			case GdkKeysyms.GDK_Left		:
			case GdkKeysyms.GDK_KP_Left		:
			case GdkKeysyms.GDK_Right		:
			case GdkKeysyms.GDK_KP_Right	:
            case GdkKeysyms.GDK_Escape      :   Kill(); return true;

            case GdkKeysyms.GDK_Up          :
            case GdkKeysyms.GDK_KP_Up       :   MoveSelectionUp(Wydjit);return true;

            case GdkKeysyms.GDK_Down        :
            case GdkKeysyms.GDK_KP_Down     :   MoveSelectionDown(Wydjit);return true;

            case GdkKeysyms.GDK_Tab         :   (EvntKey.state & GdkModifierType.SHIFT_MASK) ? MoveSelectionUp(Wydjit) : MoveSelectionDown(Wydjit); return true;
            case GdkKeysyms.GDK_ISO_Left_Tab:   MoveSelectionUp(Wydjit); return true;

            case GdkKeysyms.GDK_Return      :
            case GdkKeysyms.GDK_KP_Enter    :
            {
                if(mCompletionStatus != STATUS_OFF) CompleteText(Wydjit);
                else Kill();
                return true;
            }
            default : return false;
        }
        //return false;
    }

    bool CaptureDocumentButtons(GdkEventButton * EvntKey, Widget Wydjit)
    {
        Kill();
        return false;
    }

    bool PopUpVisible()
    {
        if ((mCompletionWin.getVisible() ) || (mTipsWin.getVisible())) return true;
        return false;
    }

    /*void MoveSelectionDown(Widget Wydjit)
    {
        TreeView LocalView;
        if(mCompletionStatus == STATUS_OFF) LocalView = mTipsView;
        else LocalView =  mCompletionView;

        TreePath tp = new TreePath;
        TreeViewColumn tvc = new TreeViewColumn;

        LocalView.getCursor(tp, tvc);
        if(tp is null)
        {
            tp = new TreePath(true);
            LocalView.setCursor(tp, null, 0);
            return;
        }
        tp.next();
        LocalView.setCursor(tp, null, 0);
        tp.free();
        LocalView.getCursor(tp, tvc);
        if(tp is null)
        {
            tp = new TreePath(true);
            LocalView.setCursor(tp, null, 0);
            return;
        }
        tp.free();
    }*/

    void MoveSelectionDown(Widget Wydjit)
    {
		TreeView LocalView;
		if(mCompletionStatus == STATUS_OFF) LocalView = mTipsView;
        else LocalView =  mCompletionView;

        TreePath tp = new TreePath;
        TreeViewColumn tvc = new TreeViewColumn;

		LocalView.getCursor(tp, tvc);
		if(tp is null) tp = new TreePath(true);
		else tp.next();
		LocalView.setCursorOnCell(tp, tvc, null, 0);
		tp.free();
		LocalView.getCursor(tp, tvc);
		if(tp.getTreePathStruct() is null)
		{
			tp = new TreePath(true);
			LocalView.setCursorOnCell(tp, tvc, null, 0);
		}
		tp.free();
	}



    void MoveSelectionUp(Widget Wydjit)
    {
        TreeView LocalView;
        if(mCompletionStatus == STATUS_OFF) LocalView = mTipsView;
        else LocalView =  mCompletionView;

        TreePath tp = new TreePath;
        TreeViewColumn tvc = new TreeViewColumn;

        LocalView.getCursor(tp, tvc);
        if(tp is null)
        {
            tp = new TreePath(true);
            LocalView.setCursor(tp, null, 0);
            return;
        }

        if(tp.prev()) LocalView.setCursor(tp, null, 0);
    }

    void CompleteText(Widget OriginDoc)
    {

        if(!mCompletionWin.getVisible()) return;

        DOCUMENT DocX = cast(DOCUMENT) OriginDoc;

        mCompletionStore.mIter = mCompletionView.getSelectedIter();

        string repl = mCompletionStore.mStore.getValueString(mCompletionStore.mIter, 0);


        TextIter ti = new TextIter;
        TextIter tiStart = new TextIter;

        auto tple = repl.findSplitAfter("</span>");

        DocX.getBuffer.getIterAtMark(ti, DocX.getBuffer.getInsert());
        //TextIter tiStart = ti.copy();
        //tiStart.backwardWordStart();


        if(mCompletionStatus == STATUS_COMPLETION)
        {
			auto OriginalText = DocX.Symbol(tiStart, false);
			auto lastdot = OriginalText.lastIndexOf('.');
			if(lastdot > -1)tiStart.forwardChars(cast(int)lastdot+1);
			DocX.getBuffer.delet(tiStart, ti);
		}

        DocX.getBuffer().insert(ti, tple[1]);
        DocX.Pasting = false;
        CompletionPop();
    }

    void Present()
    {

        if(mCompletionStatus != STATUS_OFF)
        {
            mTipsWin.hide();
            mCompletionView.setModel(mCompletionStore.GetModel());
            mCompletionWin.setOpacity(mWinOpacity);
            mCompletionView.setCursor(new TreePath("0"), null, false);
            ResizeCompletionWindow(null);
            mCompletionWin.showAll();

            emit(mCompletionStore.mMatches[0]);
            return;
        }
        else
        {
            mCompletionWin.hide();
            mTipsWin.hide();

            if (mTipsIndex < 0)  return;

            mTipsView.setModel(mTipsStore[mTipsIndex].GetModel());
            mTipsView.setCursor(new TreePath(true), null, false);
            mTipsWin.setOpacity(mWinOpacity);
            if(mTipsStore[mTipsIndex].mMatches.length > 0)
            {
                mTipsWin.showAll();
                emit(mTipsStore[mTipsIndex].mMatches[0]);
            }
            return;
        }
    }


    void UpdateComments(TreeView tv)
    {
        int indx;
        TreeModelIF nix = new ListStore([GType.STRING]);
        if(mCompletionStatus == STATUS_OFF)
        {
            auto Path = mTipsView.getSelection().getSelectedRows(nix);
            if(Path.length < 1) return;
            int[] xes = Path[0].getIndices();
            indx = xes[0];
            emit(mTipsStore[mTipsIndex].mMatches[indx]);
        }
        /*else
        {
            auto Path = mCompletionView.getSelection().getSelectedRows(nix);
            if(Path.length < 1) return;
            int[] xes = Path[0].getIndices();
            indx = xes[0];
            emit(mCompletionStore.mMatches[indx]);
        }*/
    }


    void ResizeCompletionWindow(Widget x)
    {
		int WinYPos;
		int WinHeight;

		int OrigXlen, OrigYlen, OrigX, OrigY;
		dui.GetDocMan.Current.getWindow(GtkTextWindowType.TEXT).getOrigin(OrigX, OrigY);
        dui.GetDocMan.Current.getWindow(GtkTextWindowType.TEXT).getSize(OrigXlen, OrigYlen);

		GtkRequisition sr;
		mCompletionView.sizeRequest(sr);

		if(sr.height < mWinYlen)WinHeight = sr.height + 5;
		else WinHeight = mWinYlen;

		if( (mCompletionStore.mYPos + WinHeight + mCompletionStore.mYLen) < (OrigYlen + OrigY))
		{
			WinYPos = cast(int)(mCompletionStore.mYPos + mCompletionStore.mYLen);
		}
		else
		{
			WinYPos = cast(int)(mCompletionStore.mYPos - (WinHeight + padding));
		}

		mCompletionWin.resize(mWinXlen, WinHeight);
		mCompletionWin.move(mCompletionStore.mXPos, WinYPos);

	}

	void ResizeTipWindow(Widget x)
	{
		int WinYPos;
		int WinHeight;

		int OrigXlen, OrigYlen, OrigX, OrigY;
		dui.GetDocMan.Current.getWindow(GtkTextWindowType.TEXT).getOrigin(OrigX, OrigY);
        dui.GetDocMan.Current.getWindow(GtkTextWindowType.TEXT).getSize(OrigXlen, OrigYlen);

		GtkRequisition sr;
		mTipsView.sizeRequest(sr);

		if(sr.height < mWinYlen)WinHeight = sr.height;
		else WinHeight = mWinYlen;

		if( (mTipsStore[mTipsIndex].mYPos + WinHeight + mTipsStore[mTipsIndex].mYLen) < (OrigYlen + OrigY))
		{
			WinYPos = cast(int)(mTipsStore[mTipsIndex].mYPos + mTipsStore[mTipsIndex].mYLen);
		}
		else
		{
			WinYPos = cast(int)(mTipsStore[mTipsIndex].mYPos - (WinHeight + padding));
		}

		mTipsWin.resize(mWinXlen, WinHeight);
		mTipsWin.move(mTipsStore[mTipsIndex].mXPos, WinYPos);
	}

//********************************************************************************************************************
//********************************************************************************************************************
//********************************************************************************************************************

    public:

    this()
    {
        mCompletionBuilder = new Builder;
        mCompletionBuilder.addFromFile(Config.getString("DOC_POP", "glade_file","$(HOME_DIR)/glade/docpop.glade"));
        mCompletionWin = cast (Window)mCompletionBuilder.getObject("window1");
        mCompletionView = cast(TreeView)mCompletionBuilder.getObject("treeview1");
        mCompletionStatus = STATUS_OFF;

        mTipsBuilder = new Builder;
        mTipsBuilder.addFromFile(Config.getString("DOC_POP", "glade_file","$(HOME_DIR)/glade/docpop.glade"));
        mTipsWin = cast (Window)mTipsBuilder.getObject("window1");
        mTipsView = cast (TreeView)mTipsBuilder.getObject("treeview1");
        mTipsIndex = -1;

        mTipsView.addOnCursorChanged (&UpdateComments);
        mCompletionView.addOnCursorChanged(&UpdateComments);

        //mCompletionWin.addOnShow(&ResizeCompletionWindow);
        mTipsWin.addOnShow(&ResizeTipWindow);
    }

    void Engage()
    {

        mWinXlen = Config.getInteger("DOC_POP", "window_width", 600);
        mWinYlen = Config.getInteger("DOC_POP", "window_heigth", 120);
        auto x   = Config.getInteger("DOC_POP", "window_opacity", 50);

        mWinOpacity = (cast(double)x)/100;

        dui.GetDocMan.Event.connect(&WatchForNewDocuments);
        Log.Entry("Engaged AUTO_POP_UPS");
    }

    void Disengage()
    {
        dui.GetDocMan.Event.disconnect(&WatchForNewDocuments);
        Log.Entry("Disengaged "~this.classinfo.name);
    }


    void CompletionPush(DSYMBOL[] Possibles, long xpos, long ypos, int ylen, int Status = STATUS_COMPLETION)
    {
        //if( (mCompletionStatus != Status) && ( Possibles.length < 1)) return;
        CompletionPop();
        if(Possibles.length < 1) return;

        mCompletionStatus = Status;
        mCompletionStore = DATA_STORE(Possibles, xpos, ypos, ylen);
        Present();

    }

    void CompletionPop()
    {
        mCompletionStatus = STATUS_OFF;
        Present();

    }

    void TipPush(DSYMBOL[] Possibles, long xpos, long ypos, long ylen)
    {
		if(Possibles.length < 1) return;
        CompletionPop();

        mTipsIndex++;
        if (mTipsIndex >= MAX_TIP_DEPTH)
        {
            mTipsIndex = MAX_TIP_DEPTH;
            return;
        }

        mTipsStore[mTipsIndex] = DATA_STORE(Possibles, xpos, ypos, ylen, true);

        Present();


    }

    void TipPop()
    {
        mTipsIndex--;
        if (mTipsIndex < -1) mTipsIndex = -1;
        Present();
    }

    void TipPopAll()
    {
		mTipsIndex = -1;
		Present();
	}

    void Kill()
    {
        CompletionPop();
        TipPopAll();
    }


    int Height()
    {
		int x, y;

		if(mCompletionWin.getVisible())
		{
			mCompletionWin.getSize(x,y);
			return y;
		}

		if(mTipsWin.getVisible())
		{
			mTipsWin.getSize(x,y);
			return y;
		}
		return 0;
    }

    //mixin Signal!(string, string);
    mixin Signal!(DSYMBOL);
}
