module ui_search;

//a basic ui for search. can be easily set aside for another.

//ok what i'm doing now
// search scope current uses the searchcontext from GtkSourceView
// other scopes use the buggy (when searches are large) implementation i made. 
import core.memory;
import std.algorithm;
import std.conv;
import std.file;
import std.format;
import std.path;
import std.range;


import qore;
import docman;
import ui;

void EngageSearch()
{
    auto builder = new Builder(Config.GetResource("ui_search", "glade_file", "glade", "ui_search.glade"));
    mSideRoot = cast(Widget)builder.getObject("search_side_root");
    mSearchButton = cast(Button)builder.getObject("search_button");
    mSearchEntry = cast(Entry)builder.getObject("search_entry");
    mSearchCombo = cast(ComboBoxText)builder.getObject("search_combo");
    mHiliteButton = cast(Button)builder.getObject("hilite_button");
    
    mReplaceButton = cast(Button)builder.getObject("replace_button");
    mReplaceAllButton= cast(Button)builder.getObject("replace_all_button");
    mReplaceEntry = cast(Entry)builder.getObject("replace_entry");
    mReplaceCombo = cast(ComboBoxText)builder.getObject("replace_combo");
    
    //scope
    mCurrScope = cast(RadioButton)builder.getObject("curr_scope");
    mSourceScope = cast(RadioButton)builder.getObject("source_scope");
    mAllScope = cast(RadioButton)builder.getObject("all_scope");
    mOpenScope = cast(RadioButton)builder.getObject("open_scope");
    mFolderScope = cast(RadioButton)builder.getObject("folder_scope");

    void ScopeToggle(ToggleButton rb)
    {
        if(rb is mCurrScope)mSearchScope = SEARCH_SCOPE.CURRENT;
        if(rb is mSourceScope)mSearchScope = SEARCH_SCOPE.SOURCE;
        if(rb is mAllScope)mSearchScope = SEARCH_SCOPE.ALL;
        if(rb is mOpenScope)mSearchScope = SEARCH_SCOPE.OPEN;
        if(rb is mFolderScope)mSearchScope = SEARCH_SCOPE.FOLDER;
    }
    
    mCurrScope.addOnToggled(&ScopeToggle);   
    mAllScope.addOnToggled(&ScopeToggle);    
    mSourceScope.addOnToggled(&ScopeToggle);   
    mOpenScope.addOnToggled(&ScopeToggle);   
    mFolderScope.addOnToggled(&ScopeToggle);   
    
    mSearchButton.addOnClicked(delegate void(Button me)
    {
        SearchAction();
        AppendComboHistory(mSearchCombo, mSearchEntry.getText());
    });
    mSearchEntry.addOnActivate(delegate void(Entry e)
    {
        SearchAction();
        //mSearchCombo.appendText(e.getText());
        AppendComboHistory(mSearchCombo, e.getText());
        if(mSearchScope == SEARCH_SCOPE.CURRENT) SearchFindFore();
        else  mSearchResultsView.grabFocus(); 
    });
    
    mSearchEntry.addOnChanged(delegate void(EditableIF eif)
    {
        auto doc = GetCurrentDoc();
        if(!doc)return;
        doc.SetSearchHilite(false);
    });
    
    mHiliteButton.addOnClicked(delegate void(Button btn)
    {
        auto doc = GetCurrentDoc();
        if (!doc) return;
        doc.SetSearchHilite(!doc.GetSearchHilite);
    });
    
    mReplaceEntry.addOnActivate(delegate void(Entry intree)
    {
        if(intree.getText().length)
        {
            if(GetCurrentDoc !is null)
                GetCurrentDoc.Replace(mSearchEntry.getText(), mReplaceEntry.getText());
            AppendComboHistory(mReplaceCombo, mReplaceEntry.getText());
        }
    });
    mReplaceButton.addOnClicked(delegate void(Button btn)
    {
        ReplaceAction();
        AppendComboHistory(mReplaceCombo, mReplaceEntry.getText());
    });
    mReplaceAllButton.addOnClicked(delegate void(Button btn)
    {
        ReplaceAllAction();
    });
    
       
    //options
    mCaseChkBtn = cast(CheckButton)builder.getObject("case_sensitive_checkbtn");
    mRegexChkBtn = cast(CheckButton)builder.getObject("regex_checkbtn");
    mBeginChkBtn = cast(CheckButton)builder.getObject("begin_checkbtn");
    mEndChkBtn = cast(CheckButton)builder.getObject("end_checkbtn");
    mRecurseChkBtn = cast(CheckButton)builder.getObject("recurse_checkbtn");
    
    mCaseChkBtn.addOnToggled(delegate void(ToggleButton tb)
    {
        mSearchOptions.mCaseSensitive = tb.getActive();        
    });
    mRegexChkBtn.addOnToggled(delegate void(ToggleButton tb)
    {
        mSearchOptions.mRegEx = tb.getActive();        
    });
    mBeginChkBtn.addOnToggled(delegate void(ToggleButton tb)
    {
        mSearchOptions.mWordStart = tb.getActive();        
    });
    mEndChkBtn.addOnToggled(delegate void(ToggleButton tb)
    {
        mSearchOptions.mWordEnd = tb.getActive();        
    });
    mRecurseChkBtn.addOnToggled(delegate void(ToggleButton tb)
    {
        mSearchOptions.mRecursion = tb.getActive();        
    });
    
    
    
    GActionEntry[] actEntriesSearch = [
	    {"actionSearch", &action_Search, null, null, null},
	    {"actionFindFore", &action_FindFore, null, null, null},
	    {"actionFindBack", &action_FindBack, null, null, null},
	    {"actionReplace", &action_Replace, null, null, null},
	    {"actionReplaceAll", &action_ReplaceAll, null, null, null},
	];
    mMainWindow.addActionEntries(actEntriesSearch, null);
    
    uiApplication.setAccelsForAction("win.actionSearch",["F3"]);
    AddToolObject("search","Search","Seek out that which is obsure",
        Config.GetResource("icons","search","resources", "spectacle.png"),"win.actionSearch");
    uiApplication.setAccelsForAction("win.actionFindFore", ["<ctrl>f"]);
    AddToolObject("find", "Quick Find", "Um quick! Next occurence!",
        Config.GetResource("icons", "find", "resources", "spectacle.png"), "win.ActionFindFore");
    uiApplication.setAccelsForAction("win.actionFindBack", ["<ctrl>g"]);
    AddToolObject("find back", "Quick Find Back", "Um, quick! Find last occurence!",
        Config.GetResource("icons", "find_back", "resources", "spectacle.png"), "win.ActionFindBack");
    uiApplication.setAccelsForAction("win.actionReplace", ["<ctrl>H"]);
    AddToolObject("replace", "Replace", "Guess!", 
        Config.GetResource("icons", "replace", "resources", "spectacle.png"), "win.actionReplace");
    uiApplication.setAccelsForAction("win.actionReplaceAll", ["<ctrl><SHIFT>H"]);
    AddToolObject("replace_all", "Replace All", "Guess More!", 
        Config.GetResource("icons", "replace_all", "resources", "spectacle.png"), "win.actionReplace");         
    //results stuff
    mExtraRoot = cast(ScrolledWindow)builder.getObject("search_extra_root");
    mExtraRoot.showAll();
    mSearchResultsView = cast(TreeView)builder.getObject("results_view");
    mSearchResultsStore = cast(ListStore)builder.getObject("treasure_store");
    mSearchAppStatus = new Box(Orientation.HORIZONTAL,1);
    mSearchAppStatusLabel = new Label("Hello D programmer ;)");
    mSearchAppStatus.packStart(mSearchAppStatusLabel, false, true, 1);
    AddEndStatusWidget(mSearchAppStatus);
    mSearchAppStatus.showAll();

    mSillyNoticeOfResultsLimit = cast(Label)builder.getObject("silly_notice");
    
    

    Log.Entry("Engaged");    
}

void MeshSearch()
{
    mSillyNoticeOfResultsLimit.setMarkup("#NOTICE: Searches will be limited to#\n" ~
                                        mResultsPageLimit.to!string ~" displayed results\n" ~
                                        "until I figure out how not to\n" ~
                                        "crash the X server with \n" ~
                                        "small needles and large haystacks.");
    AddSubMenuAction(0, 0, "Search", "actionSearch");
    
    void contextDlg(MenuItem mi){SearchAction();}
    //MenuItem mi = new MenuItem("Search",&contextDlg, "win.actionSearch"); 
    AddMenuPart("Search", &contextDlg, "win.actionSearch");
    
    auto history = Config.GetArray!string("ui_search","search_history");
    foreach(h;history)mSearchCombo.appendText(h);
    history = Config.GetArray!string("ui_search","replacement_history");
    foreach(h;history)mReplaceCombo.appendText(h);
    
    AddSidePane(mSideRoot, "Search Control");
    AddExtraPane(mExtraRoot, "Search Results");
    
    mSearchResultsView.addOnRowActivated(delegate void(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter;
        mSearchResultsStore.getIter(ti, tp);
        string sfile;
        int line, col;
        sfile = mSearchResultsStore.getValueString(ti, 0);
        line  = mSearchResultsStore.getValueInt(ti, 1);
        col   = mSearchResultsStore.getValueInt(ti, 2);
        docman.OpenDocAt(sfile, line, col);

    });

    mSearchResultsView.addOnKeyPress(delegate bool(Event ev, Widget wj)
    {
        bool jumpToResult;
        TreePath tpath = new TreePath(true);
        TreePath npath = new TreePath(true);
        TreeViewColumn tvc = null;
        mSearchResultsView.getCursor(tpath, tvc);
        if(tpath is null)
        {
            tpath = new TreePath(true);
            mSearchResultsView.setCursor(tpath, tvc, false);
            return false;
        }
        uint kv;
        ev.getKeyval(kv);
        if(kv == Keysyms.GDK_j)
        {
            jumpToResult = true;
            tpath.next();
            npath = tpath.copy();
            mSearchResultsView.setCursor(tpath, tvc, false);
            mSearchResultsView.getCursor(npath, tvc);
            if(npath is null)
            {
                tpath.prev();
                mSearchResultsView.setCursor(tpath, tvc, false);
            }
        }
        if(kv == Keysyms.GDK_k) 
        {
            jumpToResult = true;
            if(tpath.prev())
            mSearchResultsView.setCursor(tpath, tvc, false);
        }
        if(jumpToResult)
        {
            TreeIter ti = new TreeIter;
            mSearchResultsStore.getIter(ti, tpath);
            string sfile;
            int line, col;
            sfile = mSearchResultsStore.getValueString(ti, 0);
            line  = mSearchResultsStore.getValueInt(ti, 1);
            col   = mSearchResultsStore.getValueInt(ti, 2);
            docman.OpenDocAt(sfile, line, col);
            mSearchResultsView.grabFocus();
        }
        return false;
    });
    Log.Entry("\tui_search Meshed");
}

void DisengageSearch()
{
    Log.Entry("Disengaged");
}

void StoreSearchGui()
{
    //search history
    string[] stores;
    TreeModelIF tmIF = mSearchCombo.getModel();
    TreeIter ti = new TreeIter;
    ti.setModel(tmIF);
    tmIF.getIterFirst(ti);
    do
    {
        stores ~= tmIF.getValueString(ti, 0);
    }while(tmIF.iterNext(ti));
    Config.SetArray("ui_search", "search_history", stores);
    
    //replace history
    TreeModelIF repModel = mReplaceCombo.getModel();
    dwrite (repModel);
    TreeIter repTI = new TreeIter(repModel, new TreePath(true));
    dwrite (repTI);
    
    string[] repStore;
    if(!repModel.getIterFirst(repTI))dwrite("EERRRROORR!!");
    do
    {
        repStore ~= repModel.getValueString(repTI, 0);
    }while(repModel.iterNext(repTI));
    Config.SetArray("ui_search", "replacement_history", repStore);   
    
    Log.Entry("Gui Stored");
}

void SearchAction()
{
    scope(exit)SetBusyIndicator(false);
    SetBusyIndicator(true);
    string sText;
    auto doc = GetCurrentDoc();
    if(mMainWindow.getFocus() is cast(Widget)doc)
    {
        sText = doc.Selection();
        if(sText.length < 1) sText = doc.Word();      
    }
    if(sText.length)
    {
        mSearchCombo.setActiveText(sText, true);
    }
    if(mSearchEntry.getText().length < 1) 
    {
        mSearchEntry.grabFocus();
        return;
    }
    
	auto finds = Search(mSearchScope, mSearchEntry.getText(), mSearchOptions);
	FillSearchResults(finds);
	UpdateSearchAppStatus(mSearchEntry.getText(), mSearchScope, finds.length);
	mSearchEntry.grabFocus();
}

void SearchNextAction()
{
}
void SearchPrevAction()
{
}

void SearchFindFore()
{
    auto doc = GetCurrentDoc();
    if(doc is null) return;
    if(!mSearchEntry.getText().length)
    {
        mSearchEntry.grabFocus();
        return;        
    }
    QuickSearchFore(mSearchEntry.getText, mSearchOptions);
}
void SearchFindBack()
{
    auto doc = GetCurrentDoc();
    if(doc is null) return;
    if(!mSearchEntry.getText().length)
    {
        mSearchEntry.grabFocus();
        return;        
    }
    QuickSearchBack(mSearchEntry.getText, mSearchOptions);
}

void ReplaceAction()
{
    auto doc = GetCurrentDoc();
    if(doc is null)return;
    if(!mReplaceEntry.getText().length)
    {
        mReplaceEntry.grabFocus();
        return;
    }
    doc.Replace(mSearchEntry.getText, mReplaceEntry.getText());
}
void ReplaceAllAction()
{
    auto doc = GetCurrentDoc();
    if (doc is null) return;
    if(!mReplaceEntry.getText().length)
    {
        mReplaceEntry.grabFocus();
        return;
    }
    doc.ReplaceAll(mReplaceEntry.getText());
}

Box     mSearchAppStatus;
Label   mSearchAppStatusLabel;
Label   mSillyNoticeOfResultsLimit;

void UpdateSearchAppStatus(string needle, SEARCH_SCOPE scp, ulong items )
{
    string hr_scp;
    final switch(scp) with (SEARCH_SCOPE)
    {
        case CURRENT : hr_scp = "current document";break;
        case OPEN : hr_scp = "open documents";break;
        case SOURCE : hr_scp = "project source files";break;
        case ALL : hr_scp = "all project files";break;
        case FOLDER : hr_scp = "current folder"; break;
    }
    
    string status = format("Search for \"%s\" in %s found %s results.", needle, 
    hr_scp, items);
    mSearchAppStatusLabel.setText(status);
}


private:



void FillSearchResults(TREASURE[] treasures)
{
    
    scope(exit)
    {
        GC.enable();
    }
    GC.disable();
    mSearchResultsStore.clear();
    TreeIter ti;
    
    foreach(precious; treasures[0..($ < mResultsPageLimit)?$:mResultsPageLimit-1])
    {
        string markdown =   precious.mLineText[0..precious.mOffsetBegin].encode() ~
                            `<span foreground="red"><b><u>` ~
                            precious.mLineText[precious.mOffsetBegin..precious.mOffsetEnd].encode() ~
                            `</u></b></span>` ~
                            precious.mLineText[precious.mOffsetEnd ..$].encode();
        mSearchResultsStore.append(ti);
        mSearchResultsStore.setValue(ti, 0, precious.mDocId);
        mSearchResultsStore.setValue(ti, 1, precious.mLineNo);
        mSearchResultsStore.setValue(ti, 2, precious.mOffsetBegin);
        mSearchResultsStore.setValue(ti, 3, markdown);
    }
}

void AppendComboHistory(ComboBoxText cbt, string nuSearch)
{
    string[] searches;
    TreeModelIF tmIF = cbt.getModel();
    TreeIter ti = new TreeIter;
    ti.setModel(tmIF);
    tmIF.getIterFirst(ti);
    do { searches ~= tmIF.getValueString(ti, 0);}while(tmIF.iterNext(ti));
    string[] rv;
    foreach(item; searches)
    {
        if(item == nuSearch) continue;
        rv ~= item;
    }

    rv ~= nuSearch;
    rv = rv.tail(15);
    cbt.removeAll();
    rv.each!(n=>cbt.appendText(n));
    
}

extern (C)
{
    void action_Search(void* simAction, void* varTarget, void* voidUserData)
	{
    	SearchAction();
	}
    void action_SearchNext(void* simAction, void* varTarget, void* voidUserData)
	{
    	SearchNextAction();
	}
    void action_SearchPre(void* simAction, void* varTarget, void* voidUserData)
	{
    	SearchPrevAction();
	}

	void action_FindFore(void* simAction, void* varTarget, void* voidUserData)
	{
    	SearchFindFore();
	}
	void action_FindBack(void* simAction, void* varTarget, void* voidUserData)
	{
    	SearchFindBack();
	}
	void action_Replace(void* simAction, void* varTarget, void* voidUserData)
	{
    	ReplaceAction();
    }
	void action_ReplaceAll(void* simAction, void* varTarget, void* voidUserData)
	{
    	ReplaceAllAction();
	}
	
}

Widget          mSideRoot;
ComboBoxText    mSearchCombo;
Entry           mSearchEntry;
ComboBoxText    mReplaceCombo;
Entry           mReplaceEntry;

Button          mSearchButton;
Button          mHiliteButton;
Button          mReplaceButton;
Button          mReplaceAllButton;

CheckButton     mCaseChkBtn;
CheckButton     mRegexChkBtn;
CheckButton     mBeginChkBtn;
CheckButton     mEndChkBtn;
CheckButton     mRecurseChkBtn;

RadioButton     mCurrScope;
RadioButton     mSourceScope;
RadioButton     mAllScope;
RadioButton     mOpenScope;
RadioButton     mFolderScope;

SEARCH_SCOPE    mSearchScope;
SEARCH_OPTIONS  mSearchOptions;

ScrolledWindow  mExtraRoot;
TreeView        mSearchResultsView;
ListStore       mSearchResultsStore;

immutable mResultsPageLimit = 1250;
