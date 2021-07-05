module ui_docbook;


import std.conv;
import std.algorithm;
import std.format;
import std.traits;
import std.string;
import std.file;

import qore;
import ui;
import ui_action;
import ui_toolbar;
import ui_preferences;
import ui_project;
import log;
import config;
import docman;
import transmit;


import gdk.Event;
import gio.FileIcon;
import gio.FileT;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import glib.Variant;
import gsv.SourceStyle;
import gsv.SourceStyleScheme;
import gsv.StyleSchemeChooserButton;
import gsv.SourceStyleSchemeManager;
import gtk.Box;
import gtk.Builder;
import gtk.Dialog;
import gtk.EventBox;
import gtk.FileChooserDialog;
import gtk.Label;

import gtk.MenuItem;
import gtk.MessageDialog;
import gtk.Notebook;
import gtk.ScrolledWindow;
import gtk.Widget;
import gio.Menu :GMenu=Menu;
import gio.MenuItem : GMenuItem=MenuItem;

class UI_DOCBOOK
{
private:
    Label						mStatusLine;
	SourceStyleSchemeManager 	mStyleManager;
	
	Clipboard                   mClipboard;
	string                      mDocCmdLineSwitches;
	
	bool                        mEditSelection;
	SimpleAction                mActionUndo;
	SimpleAction                mActionRedo;
	SimpleAction                mActionCut;
	SimpleAction                mActionCopy;
	SimpleAction                mActionPaste;
	
	Timeout						mTimeoutKeeper;
	
	void DocumentModifiedExternally(DOC_IF doc)
    {
        auto Document = cast(DOCUMENT)doc;
        if(Document is null) return;        
        if(Document.Virgin) return;
        if(!Document.FullName.exists())
        {
            ShowMessage("Externally Modified File", Document.FullName ~ " no longer exists in storage!",["Acknowledge"]);
            Document.VirginReset();
            Document.getBuffer.setModified(true);
            return;
        }
        auto currentTimeStamp = timeLastModified(Document.FullName);
        if(currentTimeStamp > Document.TimeStamp)
        {
            Document.TimeStamp = currentTimeStamp;
            auto rv = ShowMessage("Externally Modified File",
                                    Document.Name ~ 
                                    "\nHas possibly been modified since last save.\n" ~
                                    "How dow you wish to proceed?\nIGNORE external changes(continue)\nLOAD the changed file(replace)\nSAVE document to new file(Save As)\nMOVE changed file to new file(copy)",
                                    ["IGNORE(continue)", 
                                     "LOAD(replace)",
                                     "SAVE(save as)",
                                     "MOVE(copy)"]
                                    ); 
            switch(rv)
            {
                case 0: break;
                case 1: Document.Load(Document.FullName); break;
                case 2: SaveAs(Document);break;              
                case 3: copy(Document.FullName, Document.FullName ~"~"); break;
                default:
            } 
        }
    }
        
    bool TimerStatusUpdate()
    {
	    import core.memory;
	    GC.disable();
	    Transmit.GatherStatusSections.emit(uiDocBook.Current);
        uiDocBook.UpdateStatusLine(uiDocBook.Current);
        GC.enable();
        return true;
    }
    
    void WatchGatherStatusSections(DOC_IF doc)
    {
        if(doc is null) return;
        string fmtString;
        string background;
        string foreground;
        string Value;
        
        //filename
        fmtString = `<span background="%s" foreground="%s"> | %s | </span>`;
        background = "black";
        foreground = "white";
        if (doc.Modified) foreground = "red";
        Value = format(fmtString, background, foreground, doc.Name);
        doc.AddStatusSection(0, Value);

        //tab of tabs
        fmtString = `<span background="yellow" foreground="black"> %s/%s open tabs </span>`;
        auto pgNum = mNotebook.pageNum(cast(Widget) doc.PageWidget());
        auto pages = mNotebook.getNPages();
        Value = format(fmtString, pgNum, pages);
        doc.AddStatusSection(10000, Value);
        
        //line of lines and col
        //DOCUMENT document = cast (DOCUMENT)doc;
        fmtString = `<span background="black" foreground="white"> [ %s/%s:%s ] </span>`;
        Value = format(fmtString, doc.Line, doc.LineCount,doc.Column);
        doc.AddStatusSection(1000, Value);
    }
	
public:
    Notebook            		mNotebook;
	EventBox					mEventBox;
    	
	SimpleAction                mActionEditCut;

	

    alias mNotebook this;
    
	void Engage(Builder mBuilder)
	{
		mStyleManager = SourceStyleSchemeManager.getDefault();
    	mStyleManager.appendSearchPath(Config.GetResource("styles", "searchPaths", "styles"));
        mDocCmdLineSwitches = Config.GetValue!string("document","cmd_line_switches");
	    
        mNotebook = cast(Notebook)mBuilder.getObject("doc_book");
		mStatusLine = cast(Label)mBuilder.getObject("doc_status");
		mEventBox = cast(EventBox)mBuilder.getObject("doc_eventbox");
		
		mEventBox.addOnEnterNotify(delegate bool(GdkEventCrossing* mode, Widget self)
		{
			setShowTabs(true);
			return true;
        });
        mNotebook.addOnLeaveNotify(delegate bool(GdkEventCrossing* mode, Widget self)
        {
            //this line is here because GtkButton causes a LeaveNotify event
            //that I really don't want. so ... this is my hack.
            if(mode.y > 0) return true;
            
	        setShowTabs(false);
	        return true;
        },ConnectFlags.AFTER);
                
        addOnSwitchPage(delegate void(Widget w, uint pgNum, Notebook self)
        {
            ScrolledWindow x = cast(ScrolledWindow) w;
            auto xdoc = cast(DOCUMENT)x.getChild();
            xdoc ? (CurrentDocName = xdoc.FullName) : (CurrentDocName = "");           
            UpdateStatusLine(xdoc);
        });
        addOnPageRemoved(delegate void(Widget w, uint pg, Notebook self)
        {
            //should be named addOnPreRemovalOfPage 'cause page is acutually
            //removed after responding to this signal.
            if(docman.GetDocs.length < 2)
            {
                CurrentDocName = ""; 
            }
        });
        
        mClipboard = Clipboard.getDefault(Display.getDefault());
        
        Transmit.DocClose.connect(&Close);

        EngageActions();
        EngagePreferences();
        EngageDocPreferences();
        
        Transmit.GatherStatusSections.connect(&WatchGatherStatusSections);
        Log.Entry("\tDocBook Engaged");   
    }
    
    void Mesh()
	{

        foreach(preOpener; docman.GetDocs())
        {
            AddDocument(preOpener);
        }
        
        mTimeoutKeeper = new Timeout(800, &TimerStatusUpdate);
        //Timeout.add(800, &TimerStatusUpdate, cast(void*)mNotebook);
        
    	Log.Entry("\tDocBook Meshed");
    }

    void StoreDocBook()
    {}
    
    void Disengage()
    {
        
        Transmit.DocClose.disconnect(&Close);
        Log.Entry("\tDocBook Disengaged");
    }

    void Open()
    {
        auto Ofd = new FileChooserDialog("Resurrect the dcomposed doc", null, GtkFileChooserAction.OPEN);

        Ofd.setSelectMultiple(true);
        Ofd.setModal(false);
        auto result  = Ofd.run();
        Ofd.hide();
        if(result != GtkResponseType.OK) return;
        auto fileList = Ofd.getFilenames();
        
        while(fileList)
        {
            scope(failure)
            {
                Log.Entry("Error loading " ~ text(cast(char*) fileList.data()));
                fileList = fileList.next();
                continue;
            }
            auto fileName = text(cast(char*)fileList.data());

            if(docman.Opened(fileName))
            {
               auto doc = cast(DOCUMENT)docman.GetDoc(fileName);
               mNotebook.setCurrentPage(doc.getParent());
               fileList = fileList.next();
               continue;
            }
            auto x = DOC_IF.Create();
            x.Name = fileName;
            x.Load(fileName);
            docman.AddDoc(x);
            AddDocument(x);
            fileList = fileList.next();
        }
        
    }
    void Save(DOC_IF doc = null)
    {
	    if(doc is null) doc = Current();
	    if(doc is null) return;
	    
	    if(doc.Virgin)
	    {
    	    SaveAs(doc);
    	    return;
        }
	    doc.Save();	    
    }
    void SaveAs(DOC_IF doc = null)
    { 
        if(doc is null) doc = Current;
        if(doc is null) return;        
        
        auto sfd = new FileChooserDialog("Bury the dcomposed doc as ...", mMainWindow, FileChooserAction.SAVE);
        sfd.setCurrentName(doc.Name);
        sfd.setFilename(doc.FullName);
        auto result = sfd.run();
        sfd.hide();
        if(result != GtkResponseType.OK) return;
        docman.ReplaceDoc(doc.FullName, sfd.getFilename);
        doc.SaveAs(sfd.getFilename);
    }
    void SaveAll()
    {
        foreach(doc;GetModifiedDocs)doc.Save();
    }
    void Close(DOC_IF curr = null)
    {
	    if(curr is null) curr = Current();
	    if(curr is null) return;
	    if(curr.Modified)
	    {
		    bool confirmedClose = false;
		    auto msgDialog = new MessageDialog(
		    	mMainWindow,
		    	GtkDialogFlags.MODAL,
		    	GtkMessageType.QUESTION,
		    	GtkButtonsType.NONE,
		    	"%s\nHas been modified. Do you wish to close and discard changes; Save and close; or cancel action.",
		    	curr.FullName());
		    msgDialog.addButtons(["Save & Close","Discard & Close","Do NOT close"],[GtkResponseType.APPLY,GtkResponseType.ACCEPT,GtkResponseType.CANCEL]);
		    auto response = msgDialog.run();
		    msgDialog.hide();
		    if(response == ResponseType.CANCEL) return;
		    if(response == ResponseType.APPLY) Save();

        }
	    mNotebook.removePage(mNotebook.getCurrentPage());
	    docman.RemoveDoc(curr);   
    }
    void CloseAll()
    {
	   	DOC_IF[] docs = docman.GetDocs();
	   	docs.each!(n=>Close(n));
    }
    bool Empty()
    {
        return docman.Empty();
    }
    
    void Run()
    {
	    if(!Current)return;
        docman.Run(Current.FullName, mDocCmdLineSwitches);
    }
    void Compile()
    {
        if(!Current)return;
        docman.Run(Current.FullName, "-c", mDocCmdLineSwitches);
    }
    void UnitTest()
    {
        if(!Current)return;
        docman.Run(Current.FullName, mDocCmdLineSwitches, "-unittest");
    }
    
    void AddDocument(DOC_IF newDoc,int pos = -1)
    {
        auto scrollWin = new ScrolledWindow;
        scrollWin.add(cast(Widget)newDoc);
        newDoc.Reconfigure();
        scrollWin.showAll();
        mNotebook.insertPage(scrollWin, cast(Widget)newDoc.TabWidget, pos);
        mNotebook.setMenuLabelText(scrollWin, newDoc.Name);
        mNotebook.setCurrentPage(scrollWin);
        ConnectDoc(newDoc);
        Log.Entry("Document added :" ~ newDoc.Name);
    }
    void ConnectDoc(DOC_IF doc)
    {
        auto Doc = cast(DOCUMENT)doc;
        assert(Doc);
        Doc.addOnFocusIn(delegate bool(Event event, Widget widget){DocumentModifiedExternally(Doc);return false;});
        Doc.getBuffer.addOnNotify(delegate void(ParamSpec ps, ObjectG obg)
        {
            SetSelection = Doc.getBuffer.getHasSelection();            
        },"has-selection");
        Doc.getBuffer.getUndoManager.addOnCanRedoChanged(delegate void(SourceUndoManagerIF undoMan)
        {
            SetRedoAble(undoMan.canRedo);
        });
        Doc.getBuffer.getUndoManager.addOnCanUndoChanged(delegate void(SourceUndoManagerIF undoMan)
        {
            SetUndoAble(undoMan.canUndo());
        });
        Doc.addOnFocusIn(delegate bool(Event e, Widget w)
        {
            auto localDoc = cast(DOCUMENT)w;
            auto undoManager = localDoc.getBuffer.getUndoManager;
            SetRedoAble(undoManager.canRedo);
            SetUndoAble(undoManager.canUndo);
            SetSelection(localDoc.getBuffer.getHasSelection);
            return false;
        });       
    }
    DOC_IF Current()
    {
        int currPageNum = mNotebook.getCurrentPage();
        if(currPageNum < 0) 
        {
	        //Log.Entry("No Documents Loaded");
	        return null;
        }
        auto parent = cast(ScrolledWindow)mNotebook.getNthPage(currPageNum);
        auto doc = cast(DOC_IF)parent.getChild();
        return doc;
    }
    void Current(DOC_IF doc)
    {
        mNotebook.setCurrentPage(cast(Widget)doc.PageWidget);
    }
    
    void UpdateStatusLine(DOC_IF doc = Current)
    {
        
        if(doc is null)
        {
            scope(failure) mStatusLine.setMarkup("Error?");
            mStatusLine.setMarkup(ui_project.StatusLine());
            return;
        }
        mStatusLine.setMarkup(doc.GetStatusLine());
    }
    string GetStatusLine()
    {
        return mStatusLine.getText();
    }
    void SetUndoAble(bool canUndo)
    {
        mActionUndo.setEnabled(canUndo);
    }
    void SetRedoAble(bool canRedo)
    {
        mActionRedo.setEnabled(canRedo);
    }
    void SetSelection(bool hasSelection)
    {
        mEditSelection = hasSelection;
        mActionCopy.setEnabled(mEditSelection);
        mActionCut.setEnabled(mEditSelection);
    }
	
	void EngageActions()
	{
		GActionEntry[] actEntNew = [
			{"actionDocNew", &action_DocNew, null, null, null},
			{"actionDocOpen", &action_DocOpen, null, null, null},
			{"actionDocSave", &action_DocSave, null, null, null},
			{"actionDocSaveAs", &action_DocSaveAs, null, null, null},
			{"actionDocSaveAll", &action_DocSaveAll, null, null, null},
			{"actionDocClose", &action_DocClose, null, null, null},
			{"actionDocCloseAll", &action_DocCloseAll, null, null, null},
			{"actionDocRun", &action_DocRun, null, null, null},
			{"actionDocCompile", &action_DocCompile, null, null, null},			
			{"actionDocUnitTest", &action_DocUnitTest, null, null, null},
			];
		mMainWindow.addActionEntries(actEntNew, null);
		
		
		GMenu docMenu = new GMenu();
		//new
		uiApplication.setAccelsForAction("win.actionDocNew",["<Control>n"]);
		AddToolObject("docnew","New","Create a new D source file",
		    Config.GetResource("icons","docnew","resources", "document-text.png"),"win.actionDocNew");
		auto menuItemNew = new GMenuItem("New", "actionDocNew");
       
        //open document
		uiApplication.setAccelsForAction("win.actionDocOpen", ["<Control>o"]);
		AddToolObject("docopen","Open", "Open Document",
		    Config.GetResource("icons","docopen","resources","folder-open-document-text.png"),"win.actionDocOpen");
		auto menuItemOpen = new GMenuItem("Open", "actionDocOpen");
		
		//save document
		uiApplication.setAccelsForAction("win.actionDocSave", ["<Control>s"]);
		AddToolObject("docsave","Save", "Save Document",
		    Config.GetResource("icons","docsave","resources","document-save.png"),"win.actionDocSave");
		auto menuItemSave = new GMenuItem("Save", "actionDocSave");
       
        //save as
		uiApplication.setAccelsForAction("win.actionDocSaveAs", ["<Control><Shift>s"]);
		AddToolObject("docsaveas", "Save As", "Save Document As...",
		    Config.GetResource("icons","docsaveas", "resources", "document-save-as.png"), "win.actionDocSaveAs");
		auto menuItemSaveAs = new GMenuItem("Save As...", "actionDocSaveAs");	
		
		//save all
		uiApplication.setAccelsForAction("win.actionDocSaveAll", ["<Super>s"]);
		AddToolObject("docsaveall", "Save All", "Save All Open Documents",
		    Config.GetResource("icons","docsaveall", "resources", "document-save-all.png"), "win.actionDocSaveAll");
		auto menuItemSaveAll = new GMenuItem("Save All", "actionDocSaveAll");
		
		//close
		uiApplication.setAccelsForAction("win.actionDocClose", ["<Control>w"]);
		AddToolObject("docclose","Close", "Close Document",
		    Config.GetResource("icons","docclose","resources","document-close.png"),"win.actionDocClose");
		auto menuItemClose = new GMenuItem("Close", "actionDocClose");		
		
		//close all
		uiApplication.setAccelsForAction("win.actionDocCloseAll", ["<Control><Shift>w"]);
		AddToolObject("doccloseall","Close All", "Close All Documents",
		    Config.GetResource("icons","doccloseall","resources","document-close-all.png"),"win.actionDocCloseAll");
		auto menuItemCloseAll = new GMenuItem("Close All", "actionDocCloseAll");
		
		//compile document
		uiApplication.setAccelsForAction("win.actionDocCompile", ["<Control><Shift>c"]);
		AddToolObject("doccompile", "Compile", "Compile document",
		    Config.GetResource("icons","doccompile","resources","document-text-compile.png"),"win.actionDocCompile");
        auto menuItemCompile = new GMenuItem("Compile", "actionDocCompile");		    
		//run document
		uiApplication.setAccelsForAction("win.actionDocRun", ["<Control><Shift>r"]);
		AddToolObject("docrun","Run", "Run Document with rdmd",
		    Config.GetResource("icons","docrun","resources","document--arrow.png"),"win.actionDocRun");
		auto menuItemRun = new GMenuItem("Run", "actionDocRun");
		//unittest document
		uiApplication.setAccelsForAction("win.actionDocUnitTest", ["<Control><Shift>U"]);
		AddToolObject("docunittest","Unit Test", "Run Document unit tests",
		    Config.GetResource("icons","docunittest","resources","document-block.png"),"win.actionDocUnitTest");
		auto menuItemUnitTest = new GMenuItem("Unit test", "actionDocUnitTest");
		docMenu.appendItem(menuItemNew);
		docMenu.appendItem(menuItemOpen);
        docMenu.appendItem(menuItemSave);
        docMenu.appendItem(menuItemSaveAs);
        docMenu.appendItem(menuItemSaveAll);
        docMenu.appendItem(menuItemClose);
        docMenu.appendItem(menuItemCloseAll);
        docMenu.appendItem(menuItemCompile);
        docMenu.appendItem(menuItemUnitTest);
        docMenu.appendItem(menuItemRun);
        
		ui.AddSubMenu(2, "Documents", docMenu);
		
		GMenu editMenu = new GMenu;
		//edit undo
		mActionUndo = new SimpleAction("actionEditUndo", null);
		mActionUndo.setEnabled(false);
		auto menuItemUndo = new GMenuItem("Undo", "actionEditUndo");
		mActionUndo.addOnActivate(delegate void(Variant var, SimpleAction sa)
		{
    		auto doc = cast(DOCUMENT)Current;
    		if(doc is null) return;
    		doc.getBuffer.undo;
        });
        mMainWindow.addAction(mActionUndo);
        uiApplication.setAccelsForAction("win.actionEditUndo", ["<Control>z"]);
        AddToolObject("docundo", "Undo", "Undo last change to source text",
            Config.GetResource("icons","undo","resources","arrow-curve-180-left.png"),
            "win.actionEditUndo");
		//edit redo
		mActionRedo = new SimpleAction("actionEditRedo", null);
		mActionRedo.setEnabled(false);
		auto menuItemRedo = new GMenuItem("Redo", "actionEditRedo");
		mActionRedo.addOnActivate(delegate void(Variant var, SimpleAction sa)
		{
    		auto doc = cast(DOCUMENT)Current;
    		if(doc is null) return;
    		doc.getBuffer.redo;
        });
        mMainWindow.addAction(mActionRedo);
        uiApplication.setAccelsForAction("win.actionEditRedo", ["<Control><Shift>z"]);
        AddToolObject("docredo", "Redo", "Redo last change to source text",
            Config.GetResource("icons","redo","resources","arrow-curve.png"),
            "win.actionEditRedo");
            
        //edit cut
        mActionCut = new SimpleAction("actionEditCut", null);
        mActionCut.setEnabled(false);
        auto menuItemCut = new GMenuItem("Cut", "actionEditCut");
        mActionCut.addOnActivate(delegate void(Variant var, SimpleAction sa)
        {
            auto doc = cast(DOCUMENT)Current;
            if(doc is null) return;
            doc.getBuffer.cutClipboard(mClipboard,true);            
        });
        mMainWindow.addAction(mActionCut);
        uiApplication.setAccelsForAction("win.actionEditCut",["<Control>x"]);
        AddToolObject("doccut", "Cut", "Cut Selected Text to Clipboard",
            Config.GetResource("icons","cut","resources","scissors-blue.png"),
            "win.actionEditCut");
			
		//Edit copy
		mActionCopy = new SimpleAction("actionEditCopy", null);
		mActionCopy.setEnabled(false);
		auto menuItemCopy = new GMenuItem("Copy", "actionEditCopy");
		mActionCopy.addOnActivate(delegate void(Variant var, SimpleAction sa)
		{
    		auto doc = cast(DOCUMENT)Current;
    		if(doc is null) return;
    		doc.getBuffer.copyClipboard(mClipboard);    		
        });
        mMainWindow.addAction(mActionCopy);
        uiApplication.setAccelsForAction("win.actionEditCopy", ["<Control>c"]);
        AddToolObject("doccopy","Copy","Copy Selection to Clipboard",
            Config.GetResource("icons","copy","resources","blue-document-copy.png"), 
            "win.actionEditCopy");	
        //edit paste
        mActionPaste = new SimpleAction("actionEditPaste", null);
        auto menuItemPaste = new GMenuItem("Paste", "actionEditPaste");
        mActionPaste.addOnActivate(delegate void(Variant var, SimpleAction sa)
        {
            auto doc = cast(DOCUMENT)Current;
            if(doc is null) return;
            doc.getBuffer.pasteClipboard(mClipboard, null, true); 
        });
        mMainWindow.addAction(mActionPaste);
        uiApplication.setAccelsForAction("win.actionEditPaste",["<Control>p"]);
        AddToolObject("docpaste","Paste", "Paste Clipboard",
            Config.GetResource("icons", "Paste","resources","clipboard-paste-document-text.png"),
            "win.actionEditPaste");
         
        editMenu.appendItem(menuItemUndo);	
        editMenu.appendItem(menuItemRedo);
        editMenu.appendItem(menuItemCut);		
        editMenu.appendItem(menuItemCopy);
        editMenu.appendItem(menuItemPaste);
        
        ui.AddSubMenu(3, "Edit", editMenu);
	}	
	void EngagePreferences()
	{
        //syntax highlight
        auto prefSyntaxHiLiteLabel = new Label("Syntax Highlighting :");
        auto prefSyntaxHiLiteSwitch = new Switch();
                
        prefSyntaxHiLiteSwitch.setState(Config.GetValue("document","syntax_hilite", true));
        prefSyntaxHiLiteSwitch.addOnStateSet(delegate bool(bool state, Switch w)
        {
            Config.SetValue("document","hilite_syntax", state);
            return false;
        });
        AppPreferenceAddWidget("Editor", prefSyntaxHiLiteLabel, prefSyntaxHiLiteSwitch); 
   
        //scheme
        auto prefSchemeLabel = new Label("Style Scheme :");

        auto prefSchemeButton = new StyleSchemeChooserButton();

        AppPreferenceAddWidget("Editor",prefSchemeLabel, prefSchemeButton);
        prefSchemeButton.setStyleScheme(SourceStyleSchemeManager.getDefault().getScheme(Config.GetValue("document", "style_scheme", "mnml")));
        prefSchemeButton.addOnEventAfter(delegate void(Event event, Widget widget)
        {
            if(prefSchemeButton.getStyleScheme.getId != Config.GetValue!string("document", "style_scheme"))
            {
                Config.SetValue("document","style_scheme", prefSchemeButton.getStyleScheme.getId);
            }
        });
        //show line numbers
        auto prefLineNoLabel = new Label("Show line numbers :");
        auto prefLineNoSwitch = new Switch();
        prefLineNoSwitch.setActive(Config.GetValue("document","show_line_numbers",true));
        prefLineNoSwitch.addOnStateSet(delegate bool(bool huh, Switch prefSwitch)
        {
            Config.SetValue("document","show_line_numbers", prefSwitch.getActive());
            return false;
        });
        AppPreferenceAddWidget("Editor", prefLineNoLabel, prefLineNoSwitch);  
        //auto indent
        auto prefAutoIndentLabel = new Label("Auto Indent :");
        auto prefAutoIndentSwitch = new Switch;
        prefAutoIndentSwitch.setActive(Config.GetValue("document","auto_indent", true));
        prefAutoIndentSwitch.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","auto_indent",status);
            return false;
        });
        AppPreferenceAddWidget("Editor",prefAutoIndentLabel, prefAutoIndentSwitch);
        //background pattern ... ignore for now
        //highlight current line
        auto prefHiliteCurLineLabel = new Label("Highlight Current Line :");
        auto prefHiliteCurLineSwitch = new Switch;
        prefHiliteCurLineSwitch.setActive(Config.GetValue("document","hilite_current_line",true));
        prefHiliteCurLineSwitch.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","hilite_current_line", status);
            return false;
        });
        AppPreferenceAddWidget("Editor",prefHiliteCurLineLabel, prefHiliteCurLineSwitch);
        //indent on tab
        auto prefIndentTabSwitch = new Switch;
        prefIndentTabSwitch.setActive(Config.GetValue("document","indent_on_tab",true));
        prefIndentTabSwitch.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document", "indent_on_tab", status);
            return false;
        });
        AppPreferenceAddWidget("Editor", new Label("Indent on Tab"), prefIndentTabSwitch);
        
        //indent width
        auto prefIndentWidthAdjustment = new Adjustment(4.0, 1.0, 65.0, 1.0, 4.0, 4.0);
        auto prefIndentWidthSpinButton = new SpinButton(prefIndentWidthAdjustment, 0.0, 0);
        prefIndentWidthAdjustment.setValue(Config.GetValue("document","indent_width", 4));
        prefIndentWidthAdjustment.addOnValueChanged(delegate void(Adjustment adj)
        {
            Config.SetValue("document","indent_width", prefIndentWidthAdjustment.getValue());
        });
        AppPreferenceAddWidget("Editor", new Label("Indent Width :"), prefIndentWidthSpinButton);
        //spaces for tabs
        auto prefSpaces4Tabs = new Switch;
        prefSpaces4Tabs.setActive(Config.GetValue("document", "spaces_for_tabs",true));
        prefSpaces4Tabs.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document", "spaces_for_tabs", status);
            return false;
        });
        //right margin
        //show right margin
        auto rightBox = new Box(Orientation.HORIZONTAL, 0);
        //auto prefShowRightMargin = new Switch;
        auto prefShowRightMargin = new CheckButton();
        prefShowRightMargin.setActive(Config.GetValue("document","show_right_margin",true));
        prefShowRightMargin.addOnToggled(delegate void(ToggleButton btn)
        {
            Config.SetValue("document", "show_right_margin", btn.getActive());
            
        });
        auto prefRighMarginAdj = new Adjustment(120.0, 1.0, 1000.0, 1.0, 1.0, 0.0);
        auto prefRightMargin = new SpinButton(prefRighMarginAdj, 0, 0);
        prefRighMarginAdj.setValue(Config.GetValue("document","right_margin",120));
        prefRighMarginAdj.addOnValueChanged(delegate void(Adjustment adj)
        {
            Config.SetValue("document", "right_margin", adj.getValue());
        });
        rightBox.packStart(prefShowRightMargin,false, false, 0);
        rightBox.packStart(prefRightMargin, true, true, 0);
        //AddAppPreferenceWidget("Editor", new Label("Right Margin :"), prefShowRightMargin, prefRightMargin);
        AppPreferenceAddWidget("Editor", new Label("Show Right Margin :"), rightBox);
        
        //show line marks
        auto prefLineMarks = new Switch;
        prefLineMarks.setActive(Config.GetValue("document","show_line_marks",true));
        prefLineMarks.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","show_line_marks", status);
            return false;
        });
        AppPreferenceAddWidget("Editor", new Label("Show Line Marks :"), prefLineMarks);
        //smart backspace
        auto prefSmartBackSpace = new Switch;
        prefSmartBackSpace.setActive(Config.GetValue("document","smart_backspace",true));
        prefSmartBackSpace.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","smart_backspace", status);
            return false;
        });
        AppPreferenceAddWidget("Editor", new Label("Smart Backspace :"), prefSmartBackSpace);
        //smart home end
        auto prefSmartHomeEnd = new Switch;
        prefSmartHomeEnd.setActive(Config.GetValue("document","smart_home_end",true));
        prefSmartHomeEnd.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","smart_home_end", status);
            return false;
        });
        AppPreferenceAddWidget("Editor", new Label("Smart Home End :"), prefSmartHomeEnd);
        //tab width
        auto prefTabWidthAdjustment = new Adjustment(4.0, 1.0, 32.0, 1.0, 1.0, 0.0);
        auto prefTabWidthSpinButton = new SpinButton(prefTabWidthAdjustment, 0.0, 0);
        prefTabWidthAdjustment.setValue(Config.GetValue("document","tab_width", 4));
        prefTabWidthAdjustment.addOnValueChanged(delegate void(Adjustment adj)
        {
            Config.SetValue("document","tab_width", adj.getValue());
        });
        AppPreferenceAddWidget("Editor", new Label("Tab Width :"), prefTabWidthSpinButton);
   
        //word wrap
        auto prefWrapStore = new ListStore([GType.STRING, GType.INT]);
        foreach(item; [EnumMembers!WrapMode])
		{	
			auto iter = new TreeIter;
			prefWrapStore.append(iter);	
			prefWrapStore.setValue!string(iter, 0, item.to!string);
			prefWrapStore.setValue!int(iter, 1, item.to!int);
        }
        auto prefWrapCombo = new ComboBox(prefWrapStore);
        prefWrapCombo.setEntryTextColumn(0);
        prefWrapCombo.setActive(Config.GetValue("document", "wrap_mode", 0)); //assumes enum values are sequential 0 .. 3 [none, word, char, word_char]
        prefWrapCombo.addOnChanged(delegate void(ComboBox self)
        {
	        Config.SetValue!GtkWrapMode("document","wrap_mode",cast(GtkWrapMode)self.getActive); //hmm
        });
        AppPreferenceAddWidget("Editor",new Label("Line Wrap :"),prefWrapCombo);
        
        //finally font!! this is one long function.
        auto prefFontButton = new FontButton();
        prefFontButton.setUseFont(true);
        prefFontButton.setFont(Config.GetValue("document", "font", "monospace 13"));
        prefFontButton.addOnFontSet(delegate void(FontButton self)
        {
	        Config.SetValue("document","font", self.getFont());
        });
        
        AppPreferenceAddWidget("Editor", prefFontButton);   
    }   
    void EngageDocPreferences()
    {
        auto uiBuilder = new Builder(Config.GetResource("docbook","pref_glade","glade","pref_doc_rdmd.glade"));
        
        auto root = cast(Box)uiBuilder.getObject("root");
        Button addbtn = cast(Button)uiBuilder.getObject("add_btn");
        Button removebtn = cast(Button)uiBuilder.getObject("remove_btn");
        TreeView optionView = cast(TreeView)uiBuilder.getObject("the_view");
        ListStore optionStore = cast(ListStore)uiBuilder.getObject("liststore1");
        CellRendererText cellText = cast(CellRendererText)uiBuilder.getObject("text_cell");
        CellRendererToggle cellToggle = cast(CellRendererToggle)uiBuilder.getObject("toggle_cell");
        //save optionStore to config
        void optionStoreSave()
        {
            string[] theChoices;
            TreeIter ti;
            optionStore.getIterFirst(ti);
            while(optionStore.iterIsValid(ti))
            {
                theChoices ~= optionStore.getValueString(ti, 1);
                if(optionStore.getValueInt(ti, 0)) mDocCmdLineSwitches = theChoices[$-1];
                optionStore.iterNext(ti);   
            }
            Config.SetValue("document","cmd_line_choices", theChoices);
            Config.SetValue("document", "cmd_line_switches", mDocCmdLineSwitches);
        }

        //load optionStore from config
        optionStore.clear();
        auto ti = new TreeIter;
        foreach(item; Config.GetArray!string("document", "cmd_line_choices", [""]))
        {
            optionStore.append(ti);
            optionStore.setValue!string(ti, 1, item);
        }

        addbtn.addOnClicked(delegate void(Button x)
        {
            TreeIter ti = new TreeIter();
            optionStore.append(ti);
            optionStore.setValue!bool(ti,0,false);
        });
        removebtn.addOnClicked(delegate void(Button x)
        {
              TreeIter ti = new TreeIter();
              ti = optionView.getSelectedIter();
              if(!optionStore.iterIsValid(ti))return;
              optionStore.remove(ti);              
        });
        cellText.addOnEdited(delegate void(string path, string text, CellRendererText crt)
        {
              auto ti = new TreeIter;
              optionStore.getIter(ti, new TreePath(path));
              optionStore.setValue(ti, 1, text);
              optionStoreSave();
        });

        cellToggle.addOnToggled(delegate void(string path, CellRendererToggle crt)
        {
            TreeIter ti = new TreeIter;
            bool val = false;
            optionStore.getIterFirst(ti);
            while(optionStore.iterIsValid(ti))
            {
                bool toggleValue;
                if(optionStore.getPath(ti).toString == path)
                { 
                  mDocCmdLineSwitches = optionStore.getValueString(ti, 1);
                  Config.SetValue("document", "cmd_line_switches", mDocCmdLineSwitches);
                  val = true;
                }
                else val = false;
                optionStore.setValue(ti, 0, val);
                optionStore.iterNext(ti);
            }
        });
        AppPreferenceAddWidget("document", root);
    }    
}


extern (C)
{
	void action_DocNew(void* simAction, void* varTarget, void* voidUserData)
	{
    	auto x = DOC_IF.Create();
    	x.Init();    	
    	uiDocBook.AddDocument(cast(DOCUMENT)x);
		Log.Entry("Created new document " ~ x.Name);
	}
	void action_DocOpen(void* simAction, void* varTarget, void* voidUserData)
	{
	    uiDocBook.Open();
	}
	void action_DocSave(void* simAction, void* varTarget, void* voidUserData)
	{
    	uiDocBook.Save();
	}
	void action_DocSaveAs(void* simAction, void* varTarget, void* voidUserData)
	{
    	uiDocBook.SaveAs();
	}
	void action_DocSaveAll(void* simAction, void* varTarget, void* voidUserData)
	{
    	uiDocBook.SaveAll();
    }
	void action_DocClose(void* simAction, void* varTarget, void* voidUserData)
	{
        	uiDocBook.Close();
	}
	void action_DocCloseAll(void* simAction, void* varTarget, void* voidUserData)
	{
    	uiDocBook.CloseAll();
	}
	void action_DocCompile(void* simAction, void* varTarget, void* voidUserData)
	{
    	uiDocBook.Save();
    	uiDocBook.Compile();
	}
	void action_DocRun(void* simAction, void* varTarget, void* voidUserData)
	{
    	uiDocBook.Save();
    	uiDocBook.Run();
	}
	void action_DocUnitTest(void * simAction, void* varTarget, void *voidUserData)
	{
    	uiDocBook.Save();
    	uiDocBook.UnitTest();
    }

}

