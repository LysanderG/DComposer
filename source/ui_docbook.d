module ui_docbook;


import std.conv;
import std.algorithm;
import std.format;
import std.traits;

import ui;
import ui_action;
import ui_toolbar;
import ui_preferences;
import log;
import config;
import docman;


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
		
public:
    Notebook            		mNotebook;
	EventBox					mEventBox;
    
    alias mNotebook this;
    
	void Engage(Builder mBuilder)
	{
    	mStyleManager = SourceStyleSchemeManager.getDefault();
    	mStyleManager.appendSearchPath(Config.GetResource("styles", "searchPaths", "styles"));
        dwrite(mStyleManager.getSearchPath());
	    
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
            
            UpdateStatusLine(cast(DOCUMENT)x.getChild());
        });
        addOnPageRemoved(delegate void(Widget w, uint pg, Notebook self)
        {
            //should be named addOnPreRemovalOfPage 'cause page is acutually
            //removed after responding to this signal.
            if(docman.GetDocs.length < 2) UpdateStatusLine("No Opened Documents");            
        });

        EngageActions();
        EngagePreferences();
        Log.Entry("\tDocBook Engaged");   
    }
    
    void Mesh()
	{
        foreach(preOpener; docman.GetDocs())
        {
            AddDocument(preOpener);
        }
        
    	Log.Entry("\tDocBook Meshed");
    }

    void StoreDocBook()
    {}
    
    void Disengage()
    {
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
	    docman.Remove(curr);   
    }
    void CloseAll()
    {
	   	DOC_IF[] docs = docman.GetDocs();
	   	docs.each!(n=>Close(n));
    }
    
    void AddDocument(DOC_IF newDoc,int pos = -1)
    {
        auto scrollWin = new ScrolledWindow;
        scrollWin.add(cast(Widget)newDoc);
        newDoc.Reconfigure();
        scrollWin.showAll();
        mNotebook.insertPage(scrollWin, cast(Widget)newDoc.TabWidget, pos);
        mNotebook.setCurrentPage(scrollWin);
    }
    DOC_IF Current()
    {
        int currPageNum = mNotebook.getCurrentPage();
        if(currPageNum < 0) return null;
        auto parent = cast(ScrolledWindow)mNotebook.getNthPage(currPageNum);
        auto doc = cast(DOC_IF)parent.getChild();
        return doc;
    }
    
    void UpdateStatusLine(string nuStatus)
    {
        mStatusLine.setMarkup(nuStatus);
    }
    void UpdateStatusLine(DOCUMENT doc)
    {
        if(doc is null)mStatusLine.setMarkup("Error?");
        mStatusLine.setMarkup(doc.GetStatusLine());
    }
    string GetStatusLine()
    {
        return mStatusLine.getText();
    }
   
private:
	
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
			{"actionDocCompile", &action_DocCompile, null, null, null},
			];
		mMainWindow.addActionEntries(actEntNew, null);
		
		
		GMenu docMenu = new GMenu();
		//new
		mApplication.setAccelsForAction("win.actionDocNew",["<Control>n"]);
		AddToolObject("docnew","New","Create a new D source file",
			Config.GetResource("icons","docnew","resources", "document-text.png"),"win.actionDocNew");
		auto menuItemNew = new GMenuItem("New", "actionDocNew");
       
        //open document
		mApplication.setAccelsForAction("win.actionDocOpen", ["<Control>o"]);
		AddToolObject("docopen","Open", "Open Document",
			Config.GetResource("icons","docopen","resources","folder-open-document-text.png"),"win.actionDocOpen");
		auto menuItemOpen = new GMenuItem("Open", "actionDocOpen");
		
		//save document
		mApplication.setAccelsForAction("win.actionDocSave", ["<Control>s"]);
		AddToolObject("docsave","Save", "Save Document",
			Config.GetResource("icons","docsave","resources","document-save.png"),"win.actionDocSave");
		auto menuItemSave = new GMenuItem("Save", "actionDocSave");
       
        //save as
		mApplication.setAccelsForAction("win.actionDocSaveAs", ["<Control><Shift>s"]);
		AddToolObject("docsaveas", "Save As", "Save Document As...",
		    Config.GetResource("icon","docsaveas", "resources", "document-save-as.png"), "win.actionDocSaveAs");
		auto menuItemSaveAs = new GMenuItem("Save As...", "actionDocSaveAs");	
		
		//save all
		mApplication.setAccelsForAction("win.actionDocSaveAll", ["<Super>s"]);
		AddToolObject("docsaveall", "Save All", "Save All Open Documents",
			Config.GetResource("icon","docsaveall", "resources", "document-save-all.png"), "win.actionDocSaveAll");
		auto menuItemSaveAll = new GMenuItem("Save All", "actionDocSaveAll");
		
		//close
		mApplication.setAccelsForAction("win.actionDocClose", ["<Control>w"]);
		AddToolObject("docclose","Close", "Close Document",
			Config.GetResource("icons","docclose","resources","document-close.png"),"win.actionDocClose");
		auto menuItemClose = new GMenuItem("Close", "actionDocClose");		
		
		//close all
		mApplication.setAccelsForAction("win.actionDocCloseAll", ["<Control><Shift>w"]);
		AddToolObject("doccloseall","Close All", "Close All Documents",
			Config.GetResource("icons","doccloseall","resources","document-close-all.png"),"win.actionDocCloseAll");
		auto menuItemCloseAll = new GMenuItem("Close All", "actionDocCloseAll");
		
		//compile document
		//run document
		//unittest document
		docMenu.appendItem(menuItemNew);
		docMenu.appendItem(menuItemOpen);
        docMenu.appendItem(menuItemSave);
        docMenu.appendItem(menuItemSaveAs);
        docMenu.appendItem(menuItemSaveAll);
        docMenu.appendItem(menuItemClose);
        docMenu.appendItem(menuItemCloseAll);
        
		ui.AddSubMenu(2, "Documents", docMenu);
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
        AddAppPreferenceWidget("Editor", prefSyntaxHiLiteLabel, prefSyntaxHiLiteSwitch);   
   
        //scheme
        auto prefSchemeLabel = new Label("Style Scheme :");
        auto prefSchemeButton = new StyleSchemeChooserButton();
        AddAppPreferenceWidget("Editor",prefSchemeLabel, prefSchemeButton);
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
        AddAppPreferenceWidget("Editor", prefLineNoLabel, prefLineNoSwitch);
        //auto indent
        auto prefAutoIndentLabel = new Label("Auto Indent :");
        auto prefAutoIndentSwitch = new Switch;
        prefAutoIndentSwitch.setActive(Config.GetValue("document","auto_indent", true));
        prefAutoIndentSwitch.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","auto_indent",status);
            return false;
        });
        AddAppPreferenceWidget("Editor",prefAutoIndentLabel, prefAutoIndentSwitch);
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
        AddAppPreferenceWidget("Editor",prefHiliteCurLineLabel, prefHiliteCurLineSwitch);
        //indent on tab
        auto prefIndentTabSwitch = new Switch;
        prefIndentTabSwitch.setActive(Config.GetValue("document","indent_on_tab",true));
        prefIndentTabSwitch.setTooltipText("Pressing tab with multiple lines selected indents all selected lines.");             
        prefIndentTabSwitch.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document", "indent_on_tab", status);
            return false;
        });
        AddAppPreferenceWidget("Editor", new Label("Indent on Tab"), prefIndentTabSwitch);
        
        //indent width
        auto prefIndentWidthAdjustment = new Adjustment(4.0, 1.0, 65.0, 1.0, 4.0, 4.0);
        auto prefIndentWidthSpinButton = new SpinButton(prefIndentWidthAdjustment, 0.0, 0);
        prefIndentWidthAdjustment.setValue(Config.GetValue("document","indent_width", 4));
        prefIndentWidthAdjustment.addOnValueChanged(delegate void(Adjustment adj)
        {
            Config.SetValue("document","indent_width", prefIndentWidthAdjustment.getValue());
        });
        AddAppPreferenceWidget("Editor", new Label("Indent Width :"), prefIndentWidthSpinButton);
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
        auto prefShowRightMargin = new Switch;
        prefShowRightMargin.setActive(Config.GetValue("document","show_right_margin",true));
        prefShowRightMargin.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document", "show_right_margin", status);
            return false;
        });
        auto prefRighMarginAdj = new Adjustment(120.0, 1.0, 1000.0, 1.0, 1.0, 0.0);
        auto prefRightMargin = new SpinButton(prefRighMarginAdj, 0, 0);
        prefRighMarginAdj.setValue(Config.GetValue("document","right_margin",120));
        prefRighMarginAdj.addOnValueChanged(delegate void(Adjustment adj)
        {
            Config.SetValue("document", "right_margin", adj.getValue());
        });
        AddAppPreferenceWidget("Editor", new Label("Right Margin :"), prefShowRightMargin, prefRightMargin);
        //show line marks
        auto prefLineMarks = new Switch;
        prefLineMarks.setActive(Config.GetValue("document","show_line_marks",true));
        prefLineMarks.setTooltipText("Show 'marks' (breakpoints, bookmarks, etc) in 'gutter'");
        prefLineMarks.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","show_line_marks", status);
            return false;
        });
        AddAppPreferenceWidget("Editor", new Label("Show Line Marks :"), prefLineMarks);
        //smart backspace
        auto prefSmartBackSpace = new Switch;
        prefSmartBackSpace.setActive(Config.GetValue("document","smart_backspace",true));
        prefSmartBackSpace.setTooltipText("Backspace will remove spaces until tab character is reached");
        prefSmartBackSpace.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","smart_backspace", status);
            return false;
        });
        AddAppPreferenceWidget("Editor", new Label("Smart Backspace :"), prefSmartBackSpace);
        //smart home end
        auto prefSmartHomeEnd = new Switch;
        prefSmartHomeEnd.setActive(Config.GetValue("document","smart_home_end",true));
        prefSmartHomeEnd.addOnStateSet(delegate bool(bool status, Switch sw)
        {
            Config.SetValue("document","smart_home_end", status);
            return false;
        });
        AddAppPreferenceWidget("Editor", new Label("Smart Home/End :"), prefSmartHomeEnd);
        //tab width
        auto prefTabWidthAdjustment = new Adjustment(4.0, 1.0, 32.0, 1.0, 1.0, 0.0);
        auto prefTabWidthSpinButton = new SpinButton(prefTabWidthAdjustment, 0.0, 0);
        prefTabWidthAdjustment.setValue(Config.GetValue("document","tab_width", 4));
        prefTabWidthAdjustment.addOnValueChanged(delegate void(Adjustment adj)
        {
            Config.SetValue("document","tab_width", adj.getValue());
        });
        AddAppPreferenceWidget("Editor", new Label("Tab Width :"), prefTabWidthSpinButton);
   
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
        prefWrapCombo.setTooltipText("Where to wrap lines:\nNONE: no where\nCHAR: between characters(graphemes)\nWORD: between words\nWORD_CHAR: any where basically");
        AddAppPreferenceWidget("Editor",new Label("Line Wrap Mode :"),prefWrapCombo);
        
        //finally font!! this is one long function.
        auto prefFontButton = new FontButton();
        prefFontButton.setUseFont(true);
        prefFontButton.setFont(Config.GetValue("document", "font", "monospace 13"));
        prefFontButton.addOnFontSet(delegate void(FontButton self)
        {
	        Config.SetValue("document","font", self.getFont());
        });
        
        AddAppPreferenceWidget("Editor", prefFontButton);
        
    }
	
	
}


extern (C)
{
	void action_DocNew(void* simAction, void* varTarget, void* voidUserData)
	{
    	auto x = DOC_IF.Create();
    	x.Init();    	
    	mDocBook.AddDocument(cast(DOCUMENT)x);
		Log.Entry("Created new document " ~ x.Name);
	}
	void action_DocOpen(void* simAction, void* varTarget, void* voidUserData)
	{
	    mDocBook.Open();
	}
	void action_DocSave(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.Save();
	}
	void action_DocSaveAs(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.SaveAs();
	}
	void action_DocSaveAll(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.SaveAll();
    }
	void action_DocClose(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.Close();
	}
	void action_DocCloseAll(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.CloseAll();
	}
	void action_DocCompile(void* simAction, void* varTarget, void* voidUserData)
	{
	}
	void action_DocRun(void* simAction, void* varTarget, void* voidUserData)
	{
	}
}

