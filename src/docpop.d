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
import document;

import dcore;

import std.stdio;
import std.algorithm;


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




struct STACK
{
    string[]    Possibles;
    int         Xpos;
    int         Ypos;
    int         Type;
    DOCUMENT    Owner;

    void        FillModel(ref ListStore x)
    {
        TreeIter ti = new TreeIter;
        //ListStore ls = cast(ListStore)(tv.getModel());
        x.clear();
        foreach(P; Possibles)
        {
            //P = SimpleXML.escapeText(P, -1);
            x.append(ti);
            x.setValue(ti, 0, P);
            x.setValue(ti, 1, "anything");
        }
        
    }
}
    


class DOC_POP
{
    private :

    enum :int { IDLE = 0, ACTIVE, INTERRUPTED}

    Builder         mBuilder;
    Window          mWindow;
    TreeView        mTreeView;
    ListStore       mListStore;

    STACK[128]      mStack;
    int             mCurStack;

    int             mCurrentType;


    public:

    void Engage()
    {
        mBuilder = new Builder;
        mBuilder.addFromFile(Config.getString("DOC_POP", "glade_file","/home/anthony/.neontotem/dcomposer/docpop.glade"));

        mWindow = cast(Window)mBuilder.getObject("window1");
        mWindow.setTransientFor(dui.GetWindow());
        mListStore = cast(ListStore)mBuilder.getObject("liststore1");
        mTreeView = cast(TreeView)mBuilder.getObject("treeview1");

        mCurStack = -1;
        
        
        Log.Entry("Engaged DOC_POP");

    }

    void Disengage()
    {
        Log.Entry("Disengaged DOC_POP");
    }
    

    void Push(DOCUMENT doc, TextIter where, string[] ListOfPossibles, int Type )
    {
        mCurStack++;
        
        //find location
        GdkRectangle rect;
        int wx, wy, tvX, tvY;

        Rectangle Location = new Rectangle(&rect);

        doc.addOnFocusOut( delegate bool(GdkEventFocus*x, Widget y) {Hide(); return false;});
        doc.getIterLocation(where, Location);
        doc.bufferToWindowCoords(GtkTextWindowType.TEXT, rect.x, rect.y, wx, wy);

        doc.getWindow(GtkTextWindowType.TEXT).getOrigin(tvX, tvY);

        wy += tvY;
        wx += tvX;
        wy += rect.height;

        mStack[mCurStack].Possibles = ListOfPossibles;        
        mStack[mCurStack].Xpos = wx;
        mStack[mCurStack].Ypos = wy;
        mStack[mCurStack].Owner = doc;
        mStack[mCurStack].FillModel(mListStore);
        mStack[mCurStack].Type = Type;
        mCurrentType = Type;

        mTreeView.setCursor(new TreePath("0"), null, false);
             
        mWindow.resize(doc.getAllocation().width/2, 120);
        mWindow.move(wx, wy);

        mWindow.show();      
    }

    void Hide()
    {
        mWindow.hide();

        mCurStack = -1;
        
    }
    /*void Close()
    {
        mCurStack--;

        while(mStack[mCurStack].Type != TYPE_CALLTIP) mCurStack--;
        if (mCurStack < 0) return Hide();

        mStack[mCurStack].FillModel(mListStore);
        mWindow.move(mStack[mCurStack].Xpos, mStack[mCurStack].Ypos);
        mWindow.show();

    }*/

    void Close(int type)
    {
        writeln( "mcurstack = ", mCurStack);
        if(mCurStack < 0) return Hide();
        if(mStack[mCurStack].Type == type)
        {
            do
            {
                mCurStack--;
                if(mCurStack < 0) return Hide();
            }while(mStack[mCurStack].Type != TYPE_CALLTIP);
                       
            mStack[mCurStack].FillModel(mListStore);
            mCurrentType = mStack[mCurStack].Type;
            mWindow.move(mStack[mCurStack].Xpos, mStack[mCurStack].Ypos);
            mWindow.show();
        }
    }
    bool CatchButton (GdkEventButton* EvntBtn, Widget Wydjit)
    {
        Hide();
        return false;
    } 
    
    bool CatchKey(GdkEventKey * EvntKey, Widget Wydjit)
    {


        if(!mWindow.getVisible())return false;
        DOCUMENT docX = cast(DOCUMENT) Wydjit;
        
        TreePath tp = new TreePath("0");
        TreeViewColumn tvc = new TreeViewColumn;
        auto key = EvntKey.keyval;

        if ( key == GdkKeysyms.GDK_Escape)
        {
            Hide();
            return true;
        }

        if ((key == GdkKeysyms.GDK_Return ) || (key == GdkKeysyms.GDK_KP_Enter))
        {
            
            if((mCurrentType == TYPE_SYMCOM) || (mCurrentType == TYPE_SCOPELIST))
            {
                TreeModelIF tmpls = new ListStore([GType.STRING, GType.STRING]);
                TreeIter waste = new TreeIter;
                mTreeView.getSelection.getSelected(tmpls, waste);
        
                string repl = tmpls.getValueString(waste, 0);

                TextIter ti = new TextIter;

                docX.getBuffer.getIterAtMark(ti, docX.getBuffer.getInsert());
                auto tple = repl.findSplitAfter("</span> ");


                TextIter tiStart = ti.copy();
                tiStart.backwardWordStart();
                if(mCurrentType == TYPE_SYMCOM) docX.getBuffer.delet(tiStart, ti);                
                
                docX.getBuffer().insert(ti, tple[1]);
                writeln(repl, "2");
                Close(TYPE_SYMCOM);
            }

            //Close();

            return true;
        }

        if ( (key == GdkKeysyms.GDK_Up) || (key == GdkKeysyms.GDK_KP_Up))
        {
            
            mTreeView.getCursor(tp, tvc);

            if(tp is null) tp = new TreePath(true);
            else tp.prev();

            mTreeView.setCursor(tp, null, false);
            return true;
        }

        if ( (key == GdkKeysyms.GDK_Down) || (key == GdkKeysyms.GDK_KP_Down))
        {
            
            mTreeView.getCursor(tp, tvc);
            if(tp is null) tp = new TreePath(true);
            else 
            tp.next();
            mTreeView.setCursor(tp, null, false);
            return true;
        }

        return false;
    }
}

/*
 * thoughts
 *
 * things that close docpop
 *
 * focus out
 * backspace  .... no maybe not... only if deletes the opening '('
 * escape
 * */
