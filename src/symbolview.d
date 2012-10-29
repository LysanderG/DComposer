//      symbolview.d
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

module symbolview;

import elements;
import dcore;
import ui;
import symbols;

import std.stdio;
import core.memory;

import gtk.Builder;
import gtk.TreeView;
import gtk.TreeStore;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.ScrolledWindow;
import gtk.TreeViewColumn;

import glib.SimpleXML;

class SYMBOL_VIEW : ELEMENT
{
    private :

    bool                mState;

    Builder             mSymBuilder;
    ScrolledWindow      mRoot;
    TreeView            mSymbolTree;
    TreeStore        	mSymbolStore;
    int					mBufferStore;

    GtkTreeStore *		mTreeStoreCache;



    void FillTreeStore()
    {
        TreeIter tiRoots = new TreeIter;
        TreeIter ti;

        void FillSym(DSYMBOL symx, TreeIter tiParent)
        {

            auto tix = mSymbolStore.append(tiParent);
            mSymbolStore.setValue(tix, 0, symx.GetIcon());
            mSymbolStore.setValue(tix, 1, symx.Name);
            mSymbolStore.setValue(tix, 2, SimpleXML.escapeText(symx.Path, -1));
            mSymbolStore.setValue(tix, 3, symx.Path);
            foreach (kidx; symx.Children) FillSym(kidx, tix);
        }

        foreach(sym; Symbols.Symbols())
        {
            ti = mSymbolStore.append(null);
            mSymbolStore.setValue(ti, 0, sym.GetIcon());
            mSymbolStore.setValue(ti, 1, sym.Name);
            if(sym.Path.length == 0) sym.Path = sym.Name;
            mSymbolStore.setValue(ti, 2, SimpleXML.escapeText(sym.Path,-1));
            mSymbolStore.setValue(ti, 3, sym.Path);
            foreach (kid; sym.Children) FillSym(kid, ti);
        }
    }


    void Refresh()
    {
		GC.disable();
		mSymbolTree.getSelection().unselectAll();
		mSymbolTree.collapseAll();
        mSymbolStore.clear;
        FillTreeStore();
        GC.enable();
    }


    void JumpTo()
    {
        TreeIter ti = mSymbolTree.getSelectedIter();

        string FileToOpen;
        int AtLineNo;

        auto sym = Symbols.GetMatches(ti.getValueString(3));
        if(sym.length < 1) return;

        FileToOpen = sym[0].File;
        AtLineNo = sym[0].Line;


        if(FileToOpen.length < 1)return;
        dui.GetDocMan.Open(FileToOpen, AtLineNo-1);
    }


    void ForwardSymbol(TreeView tv)
    {
        TreeIter ti = mSymbolTree.getSelectedIter();

        if(ti is null) return;

        auto sym = Symbols.GetMatches(ti.getValueString(3));

        Symbols.ForwardSignal(sym);
    }


    public:

    @property string    Name(){return "SYMBOL_VIEW";}
    @property string    Information(){return "List of D programming symbols";}
    @property bool      State(){return mState;}
    @property void      State(bool nustate) {mState = nustate;}

    this()
    {

        mSymBuilder =   new Builder ;

        mSymBuilder.addFromFile(Config.getString("SYMBOL_VIEW", "glade_file", "$(HOME_DIR)/glade/dsymview.glade"));
        mRoot           = cast (ScrolledWindow) mSymBuilder.getObject("scrolledwindow1");
        mSymbolTree     = cast (TreeView) mSymBuilder.getObject("treeview1");
        //mSymbolStore    = cast (TreeStore) mSymBuilder.getObject("treestore1");

		mSymbolStore = new TreeStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING]);


		mTreeStoreCache = mSymbolStore.getTreeStoreStruct();

		mSymbolTree.setModel(mSymbolStore);


        Symbols.connect(&Refresh);

        mSymbolTree.addOnRowActivated(delegate void (TreePath tp, TreeViewColumn tvc, TreeView tv){JumpTo();});

    }

    void Engage()
    {
        mState = true;

        mSymbolTree.addOnCursorChanged(&ForwardSymbol);

        mRoot.showAll();
        dui.GetSidePane.appendPage(mRoot, "SYMBOLS");
        dui.GetSidePane.setTabReorderable ( mRoot, true);
        Refresh();

        Log.Entry("Engaged "~Name()~"\t\telement.");
    }

    void Disengage()
    {
        mState = false;
        mRoot.hide();
        Log.Entry("Disengaged "~Name()~"\t\telement.");
    }


    PREFERENCE_PAGE GetPreferenceObject()
    {
        return null;
    }
}




