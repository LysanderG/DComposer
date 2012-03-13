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
    TreeStore           mSymbolStore;

    
    void FillTreeStore(ref TreeStore ts)
    {
        TreeIter tiRoots = new TreeIter;
        TreeIter ti;
        
        if(ts is null) ts = new TreeStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING]);

        void FillSym(DSYMBOL symx, TreeIter tiParent)
        {
            auto tix = ts.append(tiParent);
            //ts.setValue(tix, 0, Symbols.GetValueFromType(symx.Kind));
            ts.setValue(tix, 0, symx.GetIcon());
            ts.setValue(tix, 1, symx.Name);
            ts.setValue(tix, 2, SimpleXML.escapeText(symx.Path, -1));
            ts.setValue(tix, 3, symx.Path);
            foreach (kidx; symx.Children) FillSym(kidx, tix);

        }

        foreach(sym; Symbols.Symbols())
        {
            ti = ts.append(null);
            //ts.setValue(ti, 0, Symbols.GetValueFromType(sym.Kind));
            ts.setValue(ti, 0, sym.GetIcon());
            ts.setValue(ti, 1, sym.Name);
            if(sym.Path.length == 0) sym.Path = sym.Name;
            ts.setValue(ti, 2, SimpleXML.escapeText(sym.Path,-1));
            ts.setValue(ti, 3, sym.Path);
            foreach (kid; sym.Children) FillSym(kid, ti);
        }
    }


    void Refresh()
    {
        mSymbolStore.clear();
        FillTreeStore(mSymbolStore);
        mSymbolTree.setModel(mSymbolStore);
    }


    void JumpTo()
    {
        TreeIter ti = mSymbolTree.getSelectedIter();

        
        string FileToOPen;
        int AtLineNo;

        //Symbols.GetLocation(ti.getValueString(3), FileToOPen, AtLineNo);
        auto sym = Symbols.Match(ti.getValueString(3));

        FileToOPen = sym[0].InFile;
        AtLineNo = sym[0].OnLine;

        
        if(FileToOPen.length < 1)return;
        
        dui.GetDocMan.OpenDoc(FileToOPen, AtLineNo-1);
    }


    void UpdateProjectTags(string EventName)
    {
        if(EventName != "TagsCreated") return;
        Symbols.Load(Project.Name, Project.Name ~ ".tags");
        Refresh();
    }
        


    public:

    @property string    Name(){return "SYMBOL_VIEW";}
    @property string    Information(){return "List of D programming symbols";}
    @property bool      State(){return mState;}
    @property void      State(bool nustate) {mState = nustate;}

    this()
    {

        mSymBuilder =   new Builder ;

        mSymBuilder.addFromFile(Config.getString("SYMBOL_VIEW", "glade_file", "/home/anthony/.neontotem/dcomposer/dsymview.glade"));
        mRoot           = cast (ScrolledWindow) mSymBuilder.getObject("scrolledwindow1");
        mSymbolTree     = cast (TreeView) mSymBuilder.getObject("treeview1");
        mSymbolStore    = cast (TreeStore) mSymBuilder.getObject("treestore1");

        Symbols.connect(&Refresh);
        mSymbolTree.addOnRowActivated(delegate void (TreePath tp, TreeViewColumn tvc, TreeView tv){JumpTo();});

        
    }

    void Engage()
    {
        mState = true;

        Project.Event.connect(&UpdateProjectTags);

        mRoot.showAll();
        dui.GetSidePane.appendPage(mRoot, "SYMBOLS");
        Refresh();
        Log.Entry("Engaged SYMBOL_VIEW element");
    }

    void Disengage()
    {
        mState = false;
        mRoot.hide();
         Project.Event.disconnect(&UpdateProjectTags);
        Log.Entry("Disengaged SYMBOL_VIEW element");
    }       
}


    

