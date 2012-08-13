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

    this(DSYMBOL[] nuPossibles, long Xpos, long Ypos, bool tip = false)
    {
        mMatches = nuPossibles;

        
        mXPos = Xpos;
        mYPos = Ypos;

        mStore = new ListStore([GType.STRING, GType.STRING, GType.STRING]);
        GtkStore = mStore.getListStoreStruct();
        mIter = new TreeIter;


        sort!("a.Name < b.Name")(mMatches);
        if(tip) //this is a call tip needs to show the call signature
        {
            
            foreach(match; mMatches)
            {
                if(match.Kind != "function") continue;
                mStore.append(mIter);
                auto x = countUntil(match.Type, "(");
                string signature = match.Type[0..x] ~" "~ match.Name ~" "~ match.Type[x..$];
                mStore.setValue(mIter, 0, std.xml.decode(signature));
                mStore.setValue(mIter, 1, std.xml.decode(match.Path));
                //mStore.setValue(mIter, 2, std.xml.decode(match.Comment));
                
            }
            return;
        }

        
        foreach(match; mMatches)
        {
			match.Name = encode(match.Name);
            mStore.append(mIter);
            mStore.setValue(mIter, 0, std.xml.decode(match.GetIcon() ~ match.Name));
            mStore.setValue(mIter, 1, std.xml.decode(match.Path));
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




    
    void WatchForNewDocuments(string EventType, DOCUMENT DocXIf)
    {
        auto DocX = cast(DOCUMENT)DocXIf;
        if(EventType != "AppendDocument") return;

        DocX.addOnFocusOut(delegate bool (GdkEventFocus* EvntFocus, Widget wydjit) {Kill();return false;}); 
        DocX.addOnKeyPress(&CaptureDocumentKeys);
        DocX.addOnButtonPress(&CaptureDocumentButtons);
    }

    bool CaptureDocumentKeys(GdkEventKey * EvntKey, Widget Wydjit)
    {
        if (!PopUpVisible()) return false;
        
        DOCUMENT docX = cast(DOCUMENT) Wydjit;
        
        
        switch (EvntKey.keyval)
        {
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

    void MoveSelectionDown(Widget Wydjit)
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
        LocalView.getCursor(tp, tvc);
        if(tp is null)
        {
            tp = new TreePath(true);
            LocalView.setCursor(tp, null, 0);
            return;
        }
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

        DocX.getBuffer.getIterAtMark(ti, DocX.getBuffer.getInsert());
        auto tple = repl.findSplitAfter("</span>");


        TextIter tiStart = ti.copy();
        tiStart.backwardWordStart();
        if(mCompletionStatus == STATUS_COMPLETION) DocX.getBuffer.delet(tiStart, ti);                
        
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
            mCompletionView.setCursor(new TreePath("0"), null, false);
            mCompletionWin.resize(mWinXlen, mWinYlen);
            mCompletionWin.setOpacity(mWinOpacity);
            mCompletionWin.move(mCompletionStore.mXPos, mCompletionStore.mYPos);
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
            mTipsWin.resize(mWinXlen, mWinYlen);
            mTipsWin.setOpacity(mWinOpacity);
            mTipsWin.move(mTipsStore[mTipsIndex].mXPos, mTipsStore[mTipsIndex].mYPos);
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
        else 
        {
            auto Path = mCompletionView.getSelection().getSelectedRows(nix);
            if(Path.length < 1) return;
            int[] xes = Path[0].getIndices();
            indx = xes[0];
            emit(mCompletionStore.mMatches[indx]);
        }        
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
    }

    void Engage()
    {

        mWinXlen = Config.getInteger("DOC_POP", "window_width", 400);
        mWinYlen = Config.getInteger("DOC_POP", "window_heigth", 120);
        auto x   = Config.getInteger("DOC_POP", "window_opacity", 50);

        mWinOpacity = (cast(double)x)/100;
        
        dui.GetDocMan.Event.connect(&WatchForNewDocuments);
        Log.Entry("Engaged AUTO_POP_UPS");
    }

    void Disengage()
    {
        dui.GetDocMan.Event.disconnect(&WatchForNewDocuments);
        Log.Entry("Disengaged AUTO_POP_UPS");
    }


    void CompletionPush(DSYMBOL[] Possibles, long xpos, long ypos, int Status = STATUS_COMPLETION)
    {
        //if( (mCompletionStatus != Status) && ( Possibles.length < 1)) return;
        CompletionPop();
        if(Possibles.length < 1) return;
        
        mCompletionStatus = Status;
        mCompletionStore = DATA_STORE(Possibles, xpos, ypos);
        Present();
        
    }

    void CompletionPop()
    {
        mCompletionStatus = STATUS_OFF;
        Present();
        
    }

    void TipPush(DSYMBOL[] Possibles, long xpos, long ypos)
    {
        CompletionPop();
        mTipsIndex++;
        if (mTipsIndex >= MAX_TIP_DEPTH)
        {
            mTipsIndex = MAX_TIP_DEPTH;
            return;
        }
        mTipsStore[mTipsIndex] = DATA_STORE(Possibles, xpos, ypos, true);
        Present();
        
    }

    void TipPop()
    {
        mTipsIndex--;
        if (mTipsIndex < -1) mTipsIndex = -1;
        Present();
    }

    void Kill()
    {
        CompletionPop();
        TipPop();
    }


    int Height()
    {
        return mWinYlen;
    }

    //mixin Signal!(string, string);
    mixin Signal!(DSYMBOL);
}
