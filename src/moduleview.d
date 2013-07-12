// untitled.d
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


module moduleview;

import elements;
import dcore;
import ui;
import symbols;

import std.stdio;
import std.path;
import core.memory;

import gtk.Builder;
import gtk.TreeView;
import gtk.TreeStore;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.ScrolledWindow;
import gtk.TreeViewColumn;
import gtk.Label;
import gtk.Notebook;

import glib.SimpleXML;

class MODULE_VIEW : ELEMENT
{
    private :

    bool                mState;

    Builder             mSymBuilder;
    ScrolledWindow      mRoot;
    TreeView            mSymbolTree;
    TreeStore        	mSymbolStore;
    int					mBufferStore;

    GtkTreeStore *		mTreeStoreCache;


    void FillTreeStore(void * newPage)
    {
        TreeIter tiRoots;// = new TreeIter;

        void FillSym(DSYMBOL symx, TreeIter tiParent)
        {

            auto tix = mSymbolStore.append(tiParent);
            mSymbolStore.setValue(tix, 0, symx.Icon);
            mSymbolStore.setValue(tix, 1, symx.Name);
            mSymbolStore.setValue(tix, 2, SimpleXML.escapeText(symx.Path, -1));
            mSymbolStore.setValue(tix, 3, symx.Path);
            if(symx.Base.length > 0)
            {
				auto BaseSymbols = Symbols.GetMatches(symx.Base);
				foreach(base; BaseSymbols)
				{
					if(base.Kind == SymKind.CLASS) FillSym(base, tix);
				}
			}
            foreach (kidx; symx.Children) FillSym(kidx, tix);
        }
        DSYMBOL[] ModuleSyms;
		if(newPage is null)
		{
			if(dui.GetDocMan.Current)
			{
				mSymbolTree.getColumn(1).setTitle("Module symbols: " ~ dui.GetDocMan.Current.ShortName());
				ModuleSyms = Symbols.GetMatches(dui.GetDocMan.Current.ShortName.stripExtension());
			}
		}
		else
		{
			foreach(doc; dui.GetDocMan.Documents)
			{
				if(newPage == doc.PageWidget.getWidgetStruct())
				{
					mSymbolTree.getColumn(1).setTitle("Module symbols: " ~ doc.ShortName());
					ModuleSyms = Symbols.GetMatches(doc.ShortName.stripExtension());
					break;
				}
			}
		}
		if(ModuleSyms.length < 1)
		{
			mSymbolTree.getColumn(1).setTitle("No Symbols");
			return;
		}
        foreach(sym; ModuleSyms)
        {
			if(sym.Kind != SymKind.MODULE)continue;
			tiRoots = null;
			foreach (kid; sym.Children) FillSym(kid, tiRoots);
        }
    }


    void Refresh(void * newPage)
    {
        mSymbolStore.clear;
        FillTreeStore(newPage);
        mSymbolTree.expandAll();
    }
    void Refresh()
    {
        mSymbolStore.clear;
        FillTreeStore(cast(void *)null);
        mSymbolTree.expandAll();
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

    void SetPagePosition(UI_EVENT uie)
	{
		switch (uie)
		{
			case UI_EVENT.RESTORE_GUI :
			{
				dui.GetSidePane.reorderChild(mRoot, Config.getInteger("MODULE_VIEW", "page_position"));
				break;
			}
			case UI_EVENT.STORE_GUI :
			{
				Config.setInteger("MODULE_VIEW", "page_position", dui.GetSidePane.pageNum(mRoot));
				break;
			}
			default :break;
		}
	}


    public:

    @property string    Name(){return "MODULE_VIEW";}
    @property string    Information(){return "List of symbols in current module";}
    @property bool      State(){return mState;}
    @property void      State(bool nustate) {mState = nustate;}

    this()
    {

        mSymBuilder =   new Builder ;

        mSymBuilder.addFromFile(Config.getString("MODULE_VIEW", "glade_file", "$(HOME_DIR)/glade/dsymview.glade"));
        mRoot           = cast (ScrolledWindow) mSymBuilder.getObject("scrolledwindow1");
        mSymbolTree     = cast (TreeView) mSymBuilder.getObject("treeview1");

		mSymbolStore = new TreeStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING]);


		mTreeStoreCache = mSymbolStore.getTreeStoreStruct();

		mSymbolTree.setModel(mSymbolStore);


        Symbols.connect(&Refresh);

        mSymbolTree.addOnRowActivated(delegate void (TreePath tp, TreeViewColumn tvc, TreeView tv){JumpTo();});
    }

    void Engage()
    {
        mState = true;

		dui.GetCenterPane.addOnSwitchPage (delegate void(void* x, guint i, Notebook t){Refresh(x);});
		//dui.GetCenterPane.addOnChangeCurrentPage(delegate bool(gint e, Notebook nb){Refresh();return false;});
        mSymbolTree.addOnCursorChanged(&ForwardSymbol);

        mRoot.showAll();
        dui.GetSidePane.appendPage(mRoot, "Module");
        dui.connect(&SetPagePosition);

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
