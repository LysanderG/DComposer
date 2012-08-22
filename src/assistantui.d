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
import std.string;
import std.path;
import std.algorithm;
import std.file;

import core.memory;

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
import gtk.HPaned;
import gtk.ScrolledWindow;
import gtk.CheckButton;

import gtk.TreePath;
import gtk.TreeViewColumn;

import glib.SimpleXML;

version(WEBKIT)
{
	import gtkc.gtk;
	import gtkc.gobject;

	//substituting GtkWebKitView * with GtkWidget * because it is easier than trying to define GtkWebKitView
	extern (C) GtkWidget * webkit_web_view_new();
	extern (C) void webkit_web_view_load_uri  (GtkWidget *web_view, const gchar *uri);
}


class ASSISTANT_UI : ELEMENT
{

    private :
    
    string      mName;
    string      mInfo;
    bool        mState;

    ASSISTANT_PAGE mPreferenceObject;
    
    Builder     mBuilder;
    VBox        mRoot;
    ComboBox    mPossibles;
    Button      mBtnParent;
    Button      mBtnJumpTo;
    Button      mBtnWebLink;
    Label       mSignature;

    
    TextView    mComments;
    GtkWidget * mWebView;
    ScrolledWindow mScrollWin;
    
    TreeView    mChildren;
    ListStore   mPossibleStore;
    ListStore   mChildrenStore;
    HPaned      mHPane;

    DSYMBOL[]   mList;

    bool        mEnabled; //this should be State !! but not sure that will work as planned 6 months ago.
                           //... look into this

    GtkListStore* 		mStoreStruct;

    string		mLastDocWord;

    
    void WatchForNewDoc(string EventType, DOCUMENT NuDoc)
    {
		
        if(EventType != "AppendDocument")return;
        NuDoc.addOnKeyRelease (delegate bool (GdkEventKey* ev, Widget huh){AssistWord();return false;});
        NuDoc.addOnButtonRelease (delegate bool (GdkEventButton* ev, Widget huh){AssistWord();return false;}); 
        
   }

	void AssistWord()
	{
		string CurrentWord = dui.GetDocMan.GetWord();
		if(CurrentWord == mLastDocWord) return;
		mLastDocWord = CurrentWord;
		
		auto Possibles = Symbols.ExactMatches(CurrentWord);
		if(Possibles.length < 1) return;
		CatchSymbols(Possibles);
	}   
        
        
    void CatchSymbols(DSYMBOL[] Symbols)
    {
        if (Symbols.length < 1) return;
        TreeIter ti = new TreeIter;

        mList = Symbols;
        
		GC.disable();
        mPossibleStore.clear();

        foreach(sym; mList)
        {
            mPossibleStore.append(ti);
            mPossibleStore.setValue(ti, 0, sym.Path);
        }
        GC.enable();
        mPossibles.setActive(0);

        UpdateAssistant();
    }

    
    void CatchSymbol(DSYMBOL Symbol)
    {
        TreeIter ti = new TreeIter;        
        GC.disable();
        mPossibleStore.clear();
        //fill combobox
        mPossibleStore.append(ti);
        mPossibleStore.setValue(ti,0, SimpleXML.escapeText(Symbol.Path,-1));
        mSignature.setText(Symbol.Type);
        mChildrenStore.clear();
        foreach (sym; Symbol.Children)
        {
            ti = new TreeIter;
            mChildrenStore.append(ti);
            mChildrenStore.setValue(ti, 0, SimpleXML.escapeText(sym.Name,-1));
        }
        GC.enable();
        mPossibles.setActive(0);
        UpdateAssistant();
    }


    void UpdateAssistant()
    {
        int indx = mPossibles.getActive();
        if(( indx < 0) || (indx >= mList.length)) return;
        TreeIter ti = new TreeIter;

		GC.disable();
        mChildrenStore.clear();
        foreach (sym; mList[indx].Children)
        {
            ti = new TreeIter;
            mChildrenStore.append(ti);
            mChildrenStore.setValue(ti, 0, SimpleXML.escapeText(sym.Name,-1));
        }
        GC.enable();

        if(mList[indx].Comment.length < 1)
        {
	        version(WEBKIT)
	        {
				writeln(mList[indx].Comment);
			    string none = "file://" ~ Config.getString("ASSISTANT_UI","doc_folder", "$(SYSTEM_DIR)/docs/");
			    none ~= "undocumented.html";
			    webkit_web_view_load_uri(mWebView, none.ptr);
		    }
		    else
		    {
				mComments.getBuffer.setText(mList[indx].Path ~ " has no documentation.");
		    }
		    
			return;
		}

		//if symbol in file is a project file then check -Dd/-Df
		//else check $(home_dir) for any user added tag/doc packages
		//then check config doc directories?? 
			
		string DocDir, DocFile;
		DocFile = mList[indx].InFile;

		DocFile = stripExtension(baseName(DocFile));
		DocFile = DocFile.setExtension("html");
		
		version(WEBKIT)
		{
			if(canFind(Project[SRCFILES],mList[indx].InFile)) //is this a project file -- then look in project docs
			{
				writeln("truely", mList[indx].InFile);
				DocDir = buildPath(Project.WorkingPath, Project.GetFlags["-Dd"].Argument);
				string url = buildPath(DocDir, DocFile);
				if(exists(url))
				{
					url = "file://"~url~"#"~mList[indx].Name;
					webkit_web_view_load_uri(mWebView, toStringz(url));
				}
			}
			else //look in any folders set up as document folders?? whatever is in config file
			{
				if (Config.hasGroup("DOCUMENTATION_FOLDERS"))
				{
					auto docFolders = Config.getKeys("DOCUMENTATION_FOLDERS");
					foreach (Folder; docFolders)
					{
						writeln(Folder);
						string url = buildPath(Config.getString("DOCUMENTATION_FOLDERS",Folder), "std_"~DocFile);
						writeln(url);
						if(exists(url))
						{
							url = "file://"~url~"#"~mList[indx].Name;
							webkit_web_view_load_uri(mWebView, toStringz(url));
							break;
						}
					}
				}
			}				
	    }
	    else
	    {
			mComments.getBuffer.setText(mList[indx].Comment);
	    }
		
	
		//if not there then dlang.org/phobos/std_file#name
		
        string LabelText = "("~mList[indx].Kind~") -- Signature : " ~ mList[indx].Type;
        mSignature.setText(LabelText);
    }

    void FollowChild()
    {
        TreeIter ti = mChildren.getSelectedIter();
        if(ti is null) return;

        auto indx = mPossibles.getActive();
        if(indx < 0) return;
        string Lookup = mList[indx].Path ~ "." ~ ti.getValueString(0);

        
        auto sym = Symbols.ExactMatches(Lookup);

        CatchSymbols(sym);
    }

    void JumpTo()
    {
        auto indx = mPossibles.getActive();
        if(indx < 0) return;

        //dui.GetDocMan.OpenDoc(mList[indx].InFile, mList[indx].OnLine);
        dui.GetDocMan.Open(mList[indx].InFile, mList[indx].OnLine);
    }
    
    void Parent()
    {
        auto indx = mPossibles.getActive();

        if(indx < 0)return;

        auto LastDot = lastIndexOf(mList[indx].Path, ".");
        if(LastDot < 1) return;
        auto Lookup = mList[indx].Path[0..LastDot];
        auto PossibleParentSyms = Symbols.ExactMatches(Lookup);
        CatchSymbols(PossibleParentSyms);

    }
        
    void Reconfigure()
    {
        //mMouseHover = Config.getBoolean("ASSISTANT_UI", "follow_doc_tool_tip", false);
        mEnabled    = Config.getBoolean("ASSISTANT_UI", "enabled", true);
        
        mRoot.setVisible(mEnabled);
    }

        
        

    public:

    this()
    {
        mName = "ASSISTANT_UI";
        mInfo = "Show Symbol information";
        mState = false;

        mPreferenceObject = new ASSISTANT_PAGE("Elements", "Assistant");

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
        mBuilder.addFromFile(Config.getString("ASSISTANT_UI", "glade_file", "$(HOME_DIR)/glade/assistantui.glade"));

        mRoot           =   cast(VBox)      mBuilder.getObject("vbox1");
        mPossibles      =   cast(ComboBox)  mBuilder.getObject("combobox1");
        mBtnParent      =   cast(Button)    mBuilder.getObject("button1");
        mBtnJumpTo      =   cast(Button)    mBuilder.getObject("button2");
        mBtnWebLink     =   cast(Button)    mBuilder.getObject("button3");
        mSignature      =   cast(Label)     mBuilder.getObject("label1");
        mScrollWin		= 	cast(ScrolledWindow)mBuilder.getObject("scrolledwindow1");

		version(WEBKIT)
		{
			mWebView 	= 	webkit_web_view_new();
			Widget tmp 	= new Widget(mWebView);
			mScrollWin.add(tmp);
			tmp.show();
		}
		else
		{
			mComments	= new TextView;
			mScrollWin.add(mComments);
			mComments.show();
		}
        
        
        version(WEBKIT) webkit_web_view_load_uri  (mWebView, "http://dlang.org".ptr);
        
        mChildren       =   cast(TreeView)  mBuilder.getObject("treeview2");
        mHPane          =   cast(HPaned)    mBuilder.getObject("hpaned1");

        mPossibleStore  =   new ListStore([GType.STRING]);
        mChildrenStore  =   new ListStore([GType.STRING]);
        

        mHPane.setPosition(Config.getInteger("ASSISTANT_UI", "store_gui_pane_position",10)); 
        
        mPossibles.setModel(mPossibleStore);        
        mChildren.setModel(mChildrenStore);

        //mMouseHover = Config.getBoolean("ASSISTANT_UI", "follow_doc_tool_tip", false);
        mEnabled    = Config.getBoolean("ASSISTANT_UI", "enabled", true);
        
        mRoot.setVisible(mEnabled);
        dui.GetExtraPane.appendPage(mRoot, "Assistant");
		dui.GetExtraPane.setTabReorderable ( mRoot, true); 
        mPossibles.addOnChanged(delegate void(ComboBox cbx){UpdateAssistant();});

        dui.GetAutoPopUps.connect(&CatchSymbol);
        dui.GetDocMan.Event.connect(&WatchForNewDoc);


        

        Symbols.Forward.connect(&CatchSymbols);
        mChildren.addOnRowActivated(delegate void (TreePath tp, TreeViewColumn tvc, TreeView tv){FollowChild();});
        mBtnJumpTo.addOnClicked(delegate void(Button btn){JumpTo();});
        mBtnParent.addOnClicked(delegate void(Button btn){Parent();});

        Config.Reconfig.connect(&Reconfigure);

        Log.Entry("Engaged ASSISTANT_UI element");
    }

    void Disengage()
    {

        dui.GetAutoPopUps.disconnect(&CatchSymbol);
        dui.GetDocMan.Event.disconnect(&WatchForNewDoc);
        Config.setInteger("ASSISTANT_UI", "store_gui_pane_position", mHPane.getPosition()); 
        Log.Entry("Disengaged ASSISTANT_UI element");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {        
        return mPreferenceObject;
    } 
}



//PREFRENCES STUFF

class ASSISTANT_PAGE : PREFERENCE_PAGE
{
    CheckButton    mEnabled;
    CheckButton    mPseudoToolTipEnabled;

    override void PrepGui()
    {
		mEnabled.setActive(Config.getBoolean("ASSISTANT_UI","enabled", true));
        mPseudoToolTipEnabled.setActive(Config.getBoolean("ASSISTANT_UI", "follow_doc_tool_tip", true));
	}

    this(string PageName, string SectionName)
    {
        super(PageName, Config.getString("PREFERENCES", "glade_file_assistant", "$(HOME_DIR)/glade/assistpref.glade"));

        mEnabled = cast (CheckButton) mBuilder.getObject("checkbutton1");
        mPseudoToolTipEnabled = cast (CheckButton) mBuilder.getObject("checkbutton2");

        mEnabled.setActive(Config.getBoolean("ASSISTANT_UI","enabled", true));
        mPseudoToolTipEnabled.setActive(Config.getBoolean("ASSISTANT_UI", "follow_doc_tool_tip", true));

        //Config.ShowConfig.connect(&PrepGui);
        mFrame.showAll();
    }

    override void Apply()
    {
        Config.setBoolean("ASSISTANT_UI", "enabled", mEnabled.getActive());
        Config.setBoolean("ASSISTANT_UI", "follow_doc_tool_tip", mPseudoToolTipEnabled.getActive());
    }
}
    

    
        
