//      searchui.d
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


module searchui;


import core.memory;

import dcore;
import ui;
import elements;
import document;
import project;


import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.path;
import std.conv;
import std.datetime;
import std.file;


import gtk.Builder;
import gtk.VBox;
import gtk.HBox;
import gtk.Button;
import gtk.ScrolledWindow;
import gtk.Viewport;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.ListStore;
import gtk.TreePath;
import gtk.ComboBoxEntry;
import gtk.ComboBox;
import gtk.Entry;
import gtk.EditableIF;
import gtk.CellEditableIF;
import gtk.TreeIter;
import gtk.CellRendererText;
import gtk.Table;
import gtk.Widget;
import gtk.Container;
import gtk.Action;
import gtk.CheckButton;
import gtk.RadioButton;
import gtk.TreeModelIF;
import gtk.TextIter;
import gtk.TreeSelection;

import glib.SimpleXML;



class SEARCH_UI : ELEMENT
{
    private:
    string          mName;
    string          mInfo;
    bool            mState;

    //lots of widget crap ... understand why ppl hate gui programming!!

    Builder         mBuilder;
    VBox            mPage;
    Viewport        mOptions;
    ComboBoxEntry   mFindComboBox;
    ComboBoxEntry   mReplaceComboBox;
    Entry           mFind;
    Entry           mReplace;
    Button          mReplaceBtn;
    Button          mReplaceAllBtn;
    Button          mFindNextBtn;
    Button          mFindPrevBtn;
    Button          mHideOptionsBtn;
    Button          mHideAllBtn;
    CheckButton     mCaseSensitive;
    CheckButton     mRegex;
    CheckButton		mWholeWords;

    RadioButton     mScopeSelection;
    RadioButton     mScopeFile;
    RadioButton     mScopeSession;
    RadioButton     mScopeFolder;
    RadioButton     mScopeProject;
    
    TreeView        mResultsView;
    ListStore       mFindList;
    ListStore       mReplaceList;
    ListStore       mResultsList;

    TreeIter        TI; //see if makings this a class member stops d's gc from screwing up my treeview/treemodel stuff



    void EditedFind(CellEditableIF ci)
    {
        //TI = new TreeIter;
        //mFindList.append(TI);
        //mFindList.setValue(TI,0, mFind.getText());

        //mFindComboBox.setModel(mFindList);
        ////FillResultsList();
        //GetResults();

        CHECK SendData;
        SendData.Text = mFind.getText();
        SendData.Bool = true;        
        
        mFindList.foreac(&Check2, &SendData);            
        
        if(SendData.Bool) mFindComboBox.appendText(mFind.getText());
        GetResults();
    
    }

    void FindNextBtnClicked(Button X)
    {
		if(mPage.getParent.getParent.getVisible() != true) return;
        TreeIter tiFirst = new TreeIter;
        if(!mResultsList.getIterFirst(tiFirst))GetResults();
        
        TreePath tp = new TreePath(true);
        TreePath errortp;
        TreeViewColumn tvc = new TreeViewColumn;

        mResultsView.getCursor(tp, tvc);
        if(tp is null) return;
        errortp = tp;
        tp.next();
        mResultsView.setCursor(tp, null, false);
        mResultsView.getCursor(tp, tvc);
        if (tp is null)
        {
			tp = new TreePath(true);
			mResultsView.setCursor(tp, null, false);
		}

    }

    void FindPrevBtnClicked(Button X)
    {
		if(mPage.getParent.getParent.getVisible() != true) return;
        TreeIter tiFirst = new TreeIter;
        if(!mResultsList.getIterFirst(tiFirst))GetResults();
        
        TreeViewColumn tvc = new TreeViewColumn;
        TreePath tp = new TreePath(true);
        mResultsView.getCursor(tp, tvc);
        if(tp is null) return;
        tp.prev();
        mResultsView.setCursor(tp, null, false);


    }

    void GetResults()
    {
        SEARCH_RESULT[] Results;
        SEARCH_OPTIONS Options;
        TI = new TreeIter;
        
        Options.UseRegex = cast(bool)mRegex.getActive();
        Options.CaseInSensitive = !mCaseSensitive.getActive();
        Options.WholeWordOnly = cast(bool)mWholeWords.getActive;
        Options.WordStart = false;
        Options.RecurseFolder = false;

        string Needle = mFind.getText();
        

        if (mScopeFile.getActive())
        {
            auto tmpDocument = dui.GetDocMan.GetDocument();
            string HayStack  = tmpDocument.getBuffer.getText();
            string DocTitle  = tmpDocument.Name;
            Results = FindInString(HayStack, Needle, DocTitle, Options);
        }
        if(mScopeProject.getActive())
        {
            foreach (srcFile; Project[SRCFILES])
            {
                if(dui.GetDocMan.IsOpen(srcFile))
                {
                    auto tmpDocument = dui.GetDocMan.GetDocument(srcFile);
                    string HayStack = tmpDocument.getBuffer.getText();
                    Results ~= FindInString(HayStack, Needle, srcFile, Options);
                }
                else
                {
                    Results ~= FindInFile(srcFile, Needle, Options);
                }
            }
            foreach (relFile; Project[RELFILES])
            {
                if(dui.GetDocMan.IsOpen(relFile))
                {
                    auto tmpDocument = dui.GetDocMan.GetDocument(relFile);
                    string HayStack = tmpDocument.getBuffer.getText();
                    Results ~= FindInString(HayStack, Needle, relFile, Options);
                }
                else
                {
                    Results ~= FindInFile(relFile, Needle, Options);
                }
            }
        }
        if(mScopeSession.getActive())
        {
            //why is this an associative array ???
            string[string] HayStacks;

            foreach (doc; dui.GetDocMan.Documents) HayStacks[doc.Name] = doc.getBuffer.getText();

            Results = FindInStrings(HayStacks, Needle , Options);
        }

        if(mScopeFolder.getActive())
        {
			foreach (string Fname; dirEntries(getcwd(), SpanMode.shallow))
			{
				if(dui.GetDocMan.IsOpen(Fname))
                {
                    auto tmpDocument = dui.GetDocMan.Documents[Fname];
                    string HayStack = tmpDocument.getBuffer.getText();
                    Results ~= FindInString(HayStack, Needle, Fname, Options);
                }
                else
                {
                    Results ~= FindInFile(Fname, Needle, Options);
                }
			}
		}

        string tagstart = `<span background="black" foreground="green" >`;
        string tagend   = "</span>";

        mResultsList.clear();
        foreach (result; Results)
        {

            string[3] Splits;

            Splits[0] = SimpleXML.escapeText( result.LineText[0..result.StartOffset], -1);
            Splits[1] = SimpleXML.escapeText( result.LineText[result.StartOffset..result.EndOffset], -1);
            Splits[2] = SimpleXML.escapeText( result.LineText[result.EndOffset..$], -1);
            
            if (Splits[1].empty) return;
            
            TI = new TreeIter;
            mResultsList.append(TI);
            mResultsList.setValue(TI, 0, result.DocName);
            mResultsList.setValue(TI, 1, cast(int)result.LineNumber);
            mResultsList.setValue(TI, 2, Splits[0] ~ tagstart ~ Splits[1] ~ tagend ~ Splits[2]);//MarkupLine);
            mResultsList.setValue(TI, 3, result.DocName);
            mResultsList.setValue(TI, 4, cast(int)result.StartOffset);
            mResultsList.setValue(TI, 5, cast(int)result.EndOffset);
        }
        mResultsView.setCursor(new TreePath(true), null, false);
        mResultsView.grabFocus();
    }
    
    void FillResultsListFromFile()
    {
        int matches;
        int offset;
        
        string needle = mFind.getText();
        DOCUMENT tmpdoc = dui.GetDocMan.Current;
        if (tmpdoc is null ) return;
        auto Text = tmpdoc.getBuffer.getText;

        if(mCaseSensitive.getActive)
        {
            needle = needle.toLower;
            Text = Text.toLower;
        }

        string[] SplitText = Text.splitLines(); //lmao was using just split -- hours figuring out wth was going on!

        void ParseLine(string HayStack, int LineNo)
        {
            string tagstart = `<span background="black" foreground="green" >`;
            string tagend   = "</span>";
            
            auto Splits = HayStack.findSplit(needle);
            if (Splits[1].empty) return;
            
            
            matches++;
            offset += Splits[0].length;
            string[3] markup;

            markup[0] = SimpleXML.escapeText( SplitText[LineNo][0..offset], -1);
            markup[1] = SimpleXML.escapeText( SplitText[LineNo][offset .. offset + needle.length], -1);
            markup[2] = SimpleXML.escapeText( SplitText[LineNo][(offset + needle.length) .. $], -1);

            
            TI = new TreeIter;
            mResultsList.append(TI);
            mResultsList.setValue(TI, 0, tmpdoc.ShortName);
            mResultsList.setValue(TI, 1, cast(int)LineNo+1);
            mResultsList.setValue(TI, 2, markup[0] ~ tagstart ~ markup[1] ~ tagend ~ markup[2]);//MarkupLine);
            mResultsList.setValue(TI, 3, tmpdoc.Name);
            mResultsList.setValue(TI, 4, cast(int)offset);
            mResultsList.setValue(TI, 5, cast(int)needle.length);
            offset += needle.length; //wow this was a tricky one... sure missed it


            ParseLine(Splits[2], LineNo);

        }
        foreach(int LineNo, LineText; SplitText)
        {
            offset = 0;
            ParseLine(LineText, LineNo) ;
        }

    }
        
    void FillResultsList()
    {
        //mResultsView.setModel(null);
        //mResultsList = new ListStore([GType.STRING, GType.INT, GType.STRING, GType.STRING, GType.INT, GType.INT]);
        mResultsList.clear();
        
        if(mScopeSelection.getActive)Log.Entry("searching selection... (or will soon)","Debug");
        if(mScopeFile)FillResultsListFromFile();
        //finish the others later ... open docs .. folder and project

        //mResultsView.setModel(mResultsList);

        mResultsView.setCursor(new TreePath(true), null, false);
        mResultsView.grabFocus();

        scope(failure){Log.Entry(`Possible attempt to set treepath'0' on an empty treeview`,"Debug"); return;}
    }

    


    

    void GotoResult()
    {
        //this function is causing a disparity between resultlist and resultview
        //??? how???

        
        TI = mResultsView.getSelection.getSelected();
        
        if(!mResultsList.iterIsValid(TI))
        {
            FillResultsList();
            return;
        }

        string FileName = mResultsList.getValueString(TI, 3);
        int LineNo = mResultsList.getValueInt(TI, 1);
        dui.GetDocMan.Open(FileName, LineNo-1);
        DOCUMENT tmp = dui.GetDocMan.Current;
        if (tmp is null) return;
        tmp.HiliteFoundMatch(LineNo -1 , mResultsList.getValueInt(TI, 4), mResultsList.getValueInt(TI, 5)); //pray hard
        mResultsView.grabFocus();
    }

    void GotoResult2(TreeSelection ts)
    {
        GC.disable();
        TreeModelIF tmper;
        //foreach (tp; ts.getSelectedRows(tmper))Log.Entry(tp.toString(),"Debug");
        
        TI = ts.getSelected();

        if(TI is null) return;
        string FileName = mResultsList.getValueString(TI, 3);
        int LineNo = mResultsList.getValueInt(TI, 1);
        dui.GetDocMan.Open(FileName, LineNo-1);
        DOCUMENT tmp = dui.GetDocMan.Current;
        if (tmp is null) return;
        tmp.HiliteFoundMatch(LineNo -1 , mResultsList.getValueInt(TI, 4), mResultsList.getValueInt(TI, 5) -mResultsList.getValueInt(TI, 4)); //pray hard
        mResultsView.grabFocus();
        GC.enable();
    }


    //Simply switches focus to the find comboentry prepared to accept text for searching.
    void BeginSearch(Action X)
    {
		//what's that smell
        if(!dui.GetExtraPane.getVisible()) dui.PerformAction("ViewExtraPaneAct");
        mPage.getParent.getParent.showAll();
        dui.GetExtraPane.setCurrentPage(mPage.getParent.getParent);

        mFindComboBox.setActiveText(dui.GetDocMan.GetWord(),true);
        mFindComboBox.grabFocus();
        
    }


    void ReplaceOne()
    {
        TI = mResultsView.getSelection.getSelected();

        if (TI is null) return;

        
        if(!mResultsList.iterIsValid(TI)) return;

        string filename = mResultsList.getValueString(TI, 3);
        int line        = mResultsList.getValueInt(TI,1);
        int offstart    = mResultsList.getValueInt(TI, 4);
        int offend      = mResultsList.getValueInt(TI, 5);
        DOCUMENT tmp 	= dui.GetDocMan.Current;
        if (tmp is null) return;

        TextIter txti1 = new TextIter;
        TextIter txti2 = new TextIter;

        tmp.getBuffer.getIterAtLineOffset (txti1, line-1, offstart);
        tmp.getBuffer.getIterAtLineOffset (txti2, line-1, offend);
        tmp.getBuffer.delet(txti1, txti2);
        //tmp.getBuffer.getIterAtLineOffset(txti1,line-1,offstart);
        tmp.getBuffer.insert(txti1, mReplace.getText(), -1);
        
        //auto DeletedPath = TI.getTreePath(); //after removing the row there will be nothing selected so must reselect the "deleted path"
        //mResultsList.remove(TI);
        //mResultsView.getSelection.selectPath(DeletedPath);

        //instead of deleting row just re-search because all the positions are out of whack after the replace
        auto LastPositionPath = TI.getTreePath();
        GetResults();
        mResultsView.getSelection.selectPath(LastPositionPath);
        
    }

    void ReplaceAll()
    {
        mResultsView.getSelection.selectPath(new TreePath("0"));

        do
        {
            ReplaceOne();
        }while(mResultsList.iterIsValid(TI));
    }

    bool ReplaceKey(GdkEventKey* keyinfo, Widget wedjet)
    {
		if((keyinfo.keyval == 0x052) || (keyinfo.keyval == 0x072))//GDK_R)
		{
			ReplaceOne();
		}
		if((keyinfo.keyval == 0x041) || (keyinfo.keyval == 0x061))//GDK_A
		{
			ReplaceAll();
		}
		return false;
	}
    
    public:

    this()
    {
        mName = "SEARCH_UI";
        mInfo = "Look for stuff and fix it mabybe";

        mBuilder            = new Builder;
        mBuilder.addFromFile(Config.getString("SEARCH", "glade_file", "$(HOME_DIR)/glade/findui.glade"));

        mPage               = cast (VBox)           mBuilder.getObject("vbox5");
        mOptions            = cast (Viewport)       mBuilder.getObject("viewport2");        
        mHideOptionsBtn     = cast (Button)         mBuilder.getObject("button6");
        mHideAllBtn         = cast (Button)         mBuilder.getObject("button5");        
        mFindNextBtn        = cast (Button)         mBuilder.getObject("findnext");
        mFindPrevBtn        = cast (Button)         mBuilder.getObject("findprev");
        mReplaceBtn         = cast (Button)         mBuilder.getObject("replacebtn");
        mReplaceAllBtn      = cast (Button)         mBuilder.getObject("button9");
        mResultsView        = cast (TreeView)       mBuilder.getObject("treeview2");
        mResultsList        = cast (ListStore)      mBuilder.getObject("liststore1");
        mCaseSensitive      = cast (CheckButton)    mBuilder.getObject("checkbutton5");
        mRegex              = cast (CheckButton)    mBuilder.getObject("checkbutton8");
        mWholeWords			= cast (CheckButton)	mBuilder.getObject("checkbutton6");

        mScopeSelection     = cast (RadioButton)    mBuilder.getObject("radiobutton6");
        mScopeFile          = cast (RadioButton)    mBuilder.getObject("radiobutton1");
        mScopeSession       = cast (RadioButton)    mBuilder.getObject("radiobutton8");
        mScopeProject       = cast (RadioButton)    mBuilder.getObject("radiobutton10");
        mScopeFolder		= cast (RadioButton)	mBuilder.getObject("radiobutton9");
        mFindComboBox       = new  ComboBoxEntry(true);
        mReplaceComboBox    = new  ComboBoxEntry(true);

        mResultsList.clear();
        

        mFindList           = new                   ListStore([GType.STRING]);
        mReplaceList        = new                   ListStore([GType.STRING]);

        TI= new TreeIter;
        mFindList.append(TI);
        mFindList.setValue(TI, 0, "something!");
        
        
        mFindComboBox.setModel(mFindList);
        mFindComboBox.setTextColumn(0);
        mFind = new Entry;
        auto tmp = mFindComboBox.getChild();
        mFindComboBox.remove(tmp);
        mFindComboBox.add(mFind);

        mReplace = new Entry;
        tmp = mReplaceComboBox.getChild();
        mReplaceComboBox.remove(tmp);
        mReplaceComboBox.add(mReplace);

        
        mFind.addOnActivate(delegate void(Entry X){mFindComboBox.editingDone();});
        mReplace.addOnActivate(delegate void(Entry X){mFindComboBox.editingDone();});
        mFindComboBox.addOnEditingDone (&EditedFind);

        
       

        mResultsView.getSelection.setMode(GtkSelectionMode.BROWSE);
        //mResultsView.addOnCursorChanged (delegate void(TreeView tv){GotoResult();});
        //mResultsView.addOnRowActivated (delegate void(TreePath tp, TreeViewColumn tvc, TreeView tv){GotoResult();});
        mResultsView.getSelection.addOnChanged(&GotoResult2);
        mResultsView.addOnMoveCursor(delegate bool(GtkMovementStep step, int huh, TreeView tv){return true;}, cast(GConnectFlags)0);
        mResultsView.addOnKeyRelease(&ReplaceKey);
        
        auto tmpTable       = cast (Table)          mBuilder.getObject("table1");
        tmpTable.attachDefaults (mFindComboBox, 1, 2, 0, 1);
        tmpTable.attachDefaults (mReplaceComboBox, 1, 2, 1, 2);

        
        mHideOptionsBtn.addOnClicked(delegate void (Button X){mOptions.setVisible(!mOptions.getVisible());});
        mHideAllBtn.addOnClicked(delegate void (Button X){mPage.getParent.getParent.hide();});

        mFindNextBtn.addOnClicked(&FindNextBtnClicked);
        mFindPrevBtn.addOnClicked(&FindPrevBtnClicked);

        mReplaceBtn.addOnClicked(delegate void(Button X){ReplaceOne();});
        mReplaceAllBtn.addOnClicked(delegate void(Button X) {ReplaceAll();});

    
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
        mState = true;
        mPage.showAll();
        dui.GetExtraPane().appendPage(mPage.getParent.getParent, "Search");
        dui.GetExtraPane.setTabReorderable ( mPage, true); 
        

        Action  SearchAct = new Action("SearchAct", "_Search", "Seek out that which is hidden", StockID.FIND);
        SearchAct.addOnActivate(&BeginSearch);
        SearchAct.setAccelGroup(dui.GetAccel());
        dui.Actions().addActionWithAccel(SearchAct, null);
        dui.AddMenuItem("_System", SearchAct.createMenuItem(), 0);
		dui.AddToolBarItem(SearchAct.createToolItem());
		
	
        Action SearchNextAct = new Action("SearchNextAct", "ne_xt", "Step into the light", null);
        SearchNextAct.addOnActivate(delegate void(Action X){FindNextBtnClicked(null);});
        //SearchNextAct.setAccelPath("F3");        
        SearchNextAct.setAccelGroup(dui.GetAccel());        
        dui.Actions().addActionWithAccel(SearchNextAct, "F3");
        
        SearchNextAct.connectAccelerator();

        Action SearchPrevAct = new Action("SearchPrevAct", "_prev", "Step into the light", null);
        SearchPrevAct.addOnActivate(delegate void(Action X){FindPrevBtnClicked(null);});
        //SearchPrevAct.setAccelPath("<Shift>F3");        
        SearchPrevAct.setAccelGroup(dui.GetAccel());        
        dui.Actions().addActionWithAccel(SearchPrevAct, "F4");
        SearchPrevAct.connectAccelerator();
        
        dui.GetDocMan.AddContextMenuAction(SearchAct);
    	
        Log.Entry("Engaged SearchUI element.");
    }

    void Disengage()
    {

        mState = false;
        Log.Entry("Disengaged SearchUI element.");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return null;
    }
       
}



//BREAKING THE DRY RULE RIGHT HERE!!
/++
 + Checks a possible new entry in combobox to see if it already exists.
 + If it does then sets CHECK.Bool to false and returns true stopping the treemodel.foreac() loop.
 + Otherwise returns false indicating possible candidate can be added.
 +/
extern (C) int Check2 (GtkTreeModel *model, GtkTreePath *path, GtkTreeIter *iter,  void * data)
{
    
    CHECK * retData = cast(CHECK *) data;

    ListStore ls = new ListStore(cast(GtkListStore*)model);
    
    TreeIter ti = new TreeIter(iter);
    if( retData.Text == ls.getValueString(ti,0))
    {
        retData.Bool = false;
        return true;
    }
    return false;
}

struct CHECK
{
    string Text;
    bool    Bool;
}

/*
 * some notes
 * ok this search thing was a little more involved than I expected.
 * terrible error when scrolling through the search results treeview
 * ==== if the user holds down the scroll button resultslist (liststore) and resultsview get out of sync all data from the list is garbage
 * ---- this does not happen if user moves "slowly" though the view.   Obviously I'm not using threads so I have no idea
 * ==== about this. Why would switching quickly screw things up??
 *
 *just introduced this one...
 * ----- seg faults if search results are 0!! now thats a nice one,  should be easy to fix but I'm tired now
 * 
 * the interface itself is kinda bad ... (some good ideas but needs to be tweaked)
 * -- default search on enter
 * -- dont focus on option and scope buttons it "hot keys are pressed"
 * -- buttons in the treeview would be nice --> could hide the replace (now have to show all upper page to select replace)
 * -- hiding the options and stuff needs to make the treeview bigger not the sourceview
 * -- hmm implement all the options??? yeah that would be nice
 *
 * well except for the seg fault one
 * I'm going on to the next item on my check list
 * once the minimum components are "usable" I'll comeback fix all this stuff.
 * */

 /*
  *
  * D's garbage collector is trashing my liststore!!
  * or the iterators  which then screws up the liststore ???
  * for now add gc disable /enable block around the offending part
  * will have a look at that later
  * possiblities
  *     don't "re" new mresultslist ... just
  * */
  

