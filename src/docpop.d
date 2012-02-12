//      docpop.d
//      
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//      
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//      
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//      
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.


module docpop;

import ui;
import docman;
import document;

import dcore;

import std.stdio;
import std.algorithm;
import core.memory;


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

immutable int DATA_DEPTH = 24;

private struct DATA_STORE
{
    private     ListStore   mStore;
    private     TreeIter    mIter;
    string[]    mPossibles;
    string[]    mExtraInfo;
    int         mType;

    int         mXPos;
    int         mYPos;

    this(string[] nuPossibles, string[] info, int Type, int Xpos, int Ypos)
    {
        assert(nuPossibles.length == info.length);

        mPossibles = nuPossibles;
        mExtraInfo = info;
        mType = Type;
        mXPos = Xpos;
        mYPos = Ypos;

        mStore = new ListStore([GType.STRING, GType.STRING]);
        mIter = new TreeIter;

        foreach(pindex, PossibleItem; mPossibles)
        {
            mStore.append(mIter);
            mStore.setValue(mIter, 0, PossibleItem);
            mStore.setValue(mIter, 1, mExtraInfo[pindex]);
        }
    }

    ListStore GetModel() {return mStore;}

}

class DOC_POP
{
    private :

    Builder                 mBuilder;
    Window                  mWindow;
    TreeView                mTreeView;

    DATA_STORE              mCompletionData;
    bool                    mCompletionDataSet;
    
    DATA_STORE[DATA_DEPTH]  mTipChain;
    int                     mCurrentTipIndex;

    

    void WatchForNewDocuments(string EventType, DOCUMENT_IF DocXIf)
    {
        auto DocX = cast(DOCUMENT)DocXIf;
        if(EventType != "AppendDocument") return;

        DocX.addOnFocusOut(delegate bool (GdkEventFocus* EvntFocus, Widget wydjit) {KillChain();return false;}); 
        DocX.addOnKeyPress(&CaptureDocumentKeys);
        DocX.addOnButtonPress(&CaptureDocumentButtons);
    }

    bool CaptureDocumentKeys(GdkEventKey * EvntKey, Widget Wydjit)
    {
        if(!mWindow.getVisible())return false;
        DOCUMENT docX = cast(DOCUMENT) Wydjit;
        
        auto key = EvntKey.keyval;

        switch (key)
        {
            case GdkKeysyms.GDK_Escape      :   KillChain(); return true;
            
            case GdkKeysyms.GDK_Up          :
            case GdkKeysyms.GDK_KP_Up       :   MoveSelectionUp(Wydjit);return true;
            
            case GdkKeysyms.GDK_Down        :
            case GdkKeysyms.GDK_KP_Down     :   MoveSelectionDown(Wydjit);return true;
            
            case GdkKeysyms.GDK_Tab         :   (EvntKey.state & GdkModifierType.SHIFT_MASK) ? MoveSelectionUp(Wydjit) : MoveSelectionDown(Wydjit); return true;
            
            case GdkKeysyms.GDK_Return      :
            case GdkKeysyms.GDK_KP_Enter    :
            {
                if(mCompletionDataSet) CompleteText(Wydjit);
                else Pop();
                return true;
            }
            default : return false;
        }
        return false;
    }

        

    bool CaptureDocumentButtons(GdkEventButton * EvntKey, Widget Wydjit)
    {
        KillChain();
        return false;
    }

    void MoveSelectionUp(Widget Wydjit)
    {
        TreePath tp = new TreePath;
        TreeViewColumn tvc = new TreeViewColumn;

        mTreeView.getCursor(tp, tvc);
        if(tp is null)
        {
            tp = new TreePath(true);
            mTreeView.setCursor(tp, null, 0);
            return;
        }

        if(tp.prev()) mTreeView.setCursor(tp, null, 0);

        
    }
    void MoveSelectionDown(Widget Wydjit)
    {
        TreePath tp = new TreePath;
        TreeViewColumn tvc = new TreeViewColumn;
        
        mTreeView.getCursor(tp, tvc);
        if(tp is null)
        {
            tp = new TreePath(true);
            mTreeView.setCursor(tp, null, 0);
            return;
        }  
        tp.next();
        mTreeView.setCursor(tp, null, 0);
        if(tp is null)
        {
            tp = new TreePath(true);
            mTreeView.setCursor(tp, null, 0);
            return;
        }
    }
        
    void PresentDialog()
    {
        if(mCompletionDataSet)
        {
            mTreeView.setModel(mCompletionData.GetModel());
            mTreeView.setCursor(new TreePath("0"), null, false);
            mWindow.resize(300, 160);
            mWindow.move(mCompletionData.mXPos, mCompletionData.mYPos);
            mWindow.showAll();
            return;
        }
        
        if(mCurrentTipIndex < 0) return;
        
        mTreeView.setModel(mTipChain[mCurrentTipIndex].GetModel());
        mTreeView.setCursor(new TreePath("0"), null, false);
        mWindow.resize(300, 160);
        mWindow.move(mTipChain[mCurrentTipIndex].mXPos, mTipChain[mCurrentTipIndex].mYPos);
        mWindow.showAll();
    }


    void CompleteText(Widget Wydjit)
    {
        if(!mCompletionDataSet) return;
        
        DOCUMENT DocX = cast(DOCUMENT) Wydjit;        
        
        mCompletionData.mIter = mTreeView.getSelectedIter();
        
        string repl = mCompletionData.mStore.getValueString(mCompletionData.mIter, 0);
        

        TextIter ti = new TextIter;

        DocX.getBuffer.getIterAtMark(ti, DocX.getBuffer.getInsert());
        auto tple = repl.findSplitAfter("</span> ");


        TextIter tiStart = ti.copy();
        tiStart.backwardWordStart();
        if(mCompletionData.mType == POP_TYPE_COMPLETION) DocX.getBuffer.delet(tiStart, ti);                
        
        DocX.getBuffer().insert(ti, tple[1]);
        Pop();        
    }
    
    public: 

    this()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("DOC_POP", "glade_file","/home/anthony/.neontotem/dcomposer/docpop.glade"));

        mWindow = cast(Window)mBuilder.getObject("window1");
        mWindow.setTransientFor(dui.GetWindow());
        mTreeView = cast(TreeView)mBuilder.getObject("treeview1");

        mCurrentTipIndex = -1;
    }

    void Engage()
    {
        dui.GetDocMan.Event.connect(&WatchForNewDocuments);
        Log.Entry("Engaged DOC_POP");
        
    }

    void Disengage()
    {
        dui.GetDocMan.Event.disconnect(&WatchForNewDocuments);
        Log.Entry("Disengaged DOC_POP");        
    }

    void Push(int Type, string[] Candidates, string[] ExtraInfo, int Xlocation, int Ylocation)
    {
        if (Candidates.length < 1)
        {
            if(mCompletionDataSet) Pop();
            return;
        }

        sort(Candidates);

        if(mCompletionDataSet)
        {
            Pop();
            mCompletionDataSet = false;
        }

        if(Type != POP_TYPE_TIP)
        {
            mCompletionData = DATA_STORE(Candidates, ExtraInfo, Type, Xlocation, Ylocation);
            mCompletionDataSet = true;
        }
        else
        {
            mCurrentTipIndex++;
            mTipChain[mCurrentTipIndex] = DATA_STORE(Candidates, ExtraInfo, Type, Xlocation, Ylocation);
        }

        PresentDialog();

    }

    
    void Pop()
    {
        mWindow.hide();

        if(mCompletionDataSet)
        {
            mCompletionDataSet = false;
        }
        else
        {
            mCurrentTipIndex--;
            if (mCurrentTipIndex < 0) mCurrentTipIndex = -1;
        }

        PresentDialog();        
    }

    void KillChain()
    {
        mWindow.hide();
        mCurrentTipIndex = -1;
        mCompletionDataSet = false;
    }
    
}   




