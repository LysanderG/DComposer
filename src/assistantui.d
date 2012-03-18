// assistantui.d
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

module assistantui;

import std.stdio;
import std.datetime;

import dcore;
import symbols;
import ui;
import document;
import docman;
import elements;




import gtk.Builder;
import gtk.VBox;
import gtk.ComboBox;
import gtk.Button;
import gtk.Label;
import gtk.TextView;
import gtk.TextIter;
import gtk.TreeView;
import gtk.TreeIter;
import gtk.ListStore;
import gtk.Widget;



class ASSISTANT_UI : ELEMENT
{

    private :
    
    string      mName;
    string      mInfo;
    bool        mState;

    StopWatch   mTTipTimer;
    TickDuration mMinTime;

    
    Builder     mBuilder;
    VBox        mRoot;
    ComboBox    mPossibles;
    Button      mBtnInsert;
    Button      mBtnJumpTo;
    Button      mBtnWebLink;
    Label       mSignature;
    TextView    mComments;
    TreeView    mChildren;
    ListStore   mPossibleStore;
    ListStore   mChildrenStore;

    DSYMBOL[]   mList;

    
    void WatchForNewDoc(string EventType, DOCUMENT_IF NuDoc)
    {
        if(EventType != "AppendDocument")return;
        auto doc = cast(DOCUMENT)NuDoc;
        doc.addOnQueryTooltip (&CatchDocToolTip); 
        
    }

    bool CatchDocToolTip(int x , int y, int key_mode, GtkTooltip* TTipPtr, Widget WidDoc)
    {
        mTTipTimer.stop();
        writeln(mTTipTimer.peek, " <--> ", mMinTime );
        if(mTTipTimer.peek.seconds <  2)
        {
            mTTipTimer.start();
            return false;
        }
        mTTipTimer.reset();
        mTTipTimer.start();
        
        //if (key_mode)return false;
        //get symbol at x, y
        int bufx, bufy, trailing;
        TextIter ti = new TextIter;
        DOCUMENT DocX = cast (DOCUMENT) WidDoc;

        DocX.windowToBufferCoords(TextWindowType.WIDGET, x, y, bufx, bufy);
        DocX.getIterAtPosition(ti, trailing, bufx, bufy);
        //for now just go the easy way out

        if(!ti.insideWord())return false;
        auto start = ti.copy();
        auto end = ti.copy();
        start.backwardWordStart();
        end.forwardWordEnd();

        string Candidate = start.getText(end);

        //writeln(cast(char)ti.getChar());
        auto Possibles = Symbols.ExactMatches(Candidate);
        if (Possibles.length < 1)return false;

        CatchSymbols(Possibles);
        return false;
    }
        
        
    void CatchSymbols(DSYMBOL[] Symbols)
    {
        TreeIter ti = new TreeIter;

        mList = Symbols;
        
        mPossibleStore.clear();

        foreach(sym; mList)
        {
            mPossibleStore.append(ti);
            mPossibleStore.setValue(ti, 0, sym.Path);
        }
        mPossibles.setActive(0);

        UpdateAssistant();
    }

    
    void CatchSymbol(DSYMBOL Symbol)
    {
        TreeIter ti = new TreeIter;
        
        mPossibleStore.clear();

        //fill combobox
        mPossibleStore.append(ti);
        mPossibleStore.setValue(ti,0, Symbol.Path);

        mSignature.setText(Symbol.Type);
        if(Symbol.Comment.length >0)mComments.getBuffer().setText(Symbol.Comment);
        else mComments.getBuffer().setText("No documentation available");



        mChildrenStore.clear();
        foreach (sym; Symbol.Children)
        {
            ti = new TreeIter;
            mChildrenStore.append(ti);
            mChildrenStore.setValue(ti, 0, sym.Name);
        }

        mPossibles.setActive(0);
    }


    void UpdateAssistant()
    {
        int indx = mPossibles.getActive();
        writeln(indx);
        if(( indx < 0) || (indx >= mList.length)) return;
        TreeIter ti = new TreeIter;

        mChildrenStore.clear();
        foreach (sym; mList[indx].Children)
        {
            ti = new TreeIter;
            mChildrenStore.append(ti);
            mChildrenStore.setValue(ti, 0, sym.Name);
        }

        if(mList[indx].Comment.length >0)mComments.getBuffer().setText(mList[indx].Comment);
        else mComments.getBuffer().setText("No documentation available");

        if(mList[indx].Type.length > 0) mSignature.setText(mList[indx].Type);
        else mSignature.setText(" ");
    }
        

    public:

    this()
    {
        mName = "ASSISTANT_UI";
        mInfo = "Show Symbol information";
        mState = false;

    }

    @property string Name() {return mName;}
    @property string Information() {return mInfo;}
    @property bool   State() {return mState;}
    @property void   State(bool NuState)
    {
        if (NuState == mState) return;
        NuState ? Engage() : Disengage();
    }

    void Engage()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("ASSISTANT_UI", "glade_file", "~/.neontotem/dcomposer/assistantui.glade"));

        mRoot           =   cast(VBox)      mBuilder.getObject("vbox1");
        mPossibles      =   cast(ComboBox)  mBuilder.getObject("combobox1");
        mBtnInsert      =   cast(Button)    mBuilder.getObject("button1");
        mBtnJumpTo      =   cast(Button)    mBuilder.getObject("button2");
        mBtnWebLink     =   cast(Button)    mBuilder.getObject("button3");
        mSignature      =   cast(Label)     mBuilder.getObject("label1");
        mComments       =   cast(TextView)  mBuilder.getObject("textview1");
        mChildren       =   cast(TreeView)  mBuilder.getObject("treeview2");

        mPossibleStore  =   new ListStore([GType.STRING]);
        mChildrenStore  =   new ListStore([GType.STRING]);

        
        mPossibles.setModel(mPossibleStore);        
        mChildren.setModel(mChildrenStore);


        mRoot.showAll();
        dui.GetExtraPane.appendPage(mRoot, "Assistant");

        mPossibles.addOnChanged(delegate void(ComboBox cbx){UpdateAssistant();});

        dui.GetAutoPopUps.connect(&CatchSymbol);
        dui.GetDocMan.Event.connect(&WatchForNewDoc);

        mTTipTimer.start();
        mMinTime.from!"msecs"(5000);

        Log.Entry("Engaged ASSISTANT_UI element");
    }

    void Disengage()
    {
        Log.Entry("Disengaged ASSISTANT_UI element");
    }
}
        
