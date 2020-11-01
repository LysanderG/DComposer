module ui_docbook;


import std.conv;
import std.algorithm;
import std.format;

import ui;
import ui_action;
import ui_toolbar;
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
    	Config.SetResourcePath("styles","styles");
    	mStyleManager.appendSearchPath(Config.GetResource("styles", "searchPaths", "styles"));

	    
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
        Log.Entry("\tEngaged");   
    }
    
    void Mesh()
	{
        foreach(preOpener; docman.GetDocs())
        {
            AddDocument(preOpener);
        }
        
    	Log.Entry("\tMeshed");
    }

    void StoreDocBook()
    {}
    
    void Disengage()
    {
        Log.Entry("\tDisengaged");
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
               dwrite("opened ",fileName);
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
	    dwrite(curr);
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
			Config.GetResource("icons","docnew","resource", "document-text.png"),"win.actionDocNew");
		auto menuItemNew = new GMenuItem("New", "actionDocNew");
       
        //open document
		mApplication.setAccelsForAction("win.actionDocOpen", ["<Control>o"]);
		AddToolObject("docopen","Open", "Open Document",
			Config.GetResource("icons","docopen","resource","folder-open-document-text.png"),"win.actionDocOpen");
		auto menuItemOpen = new GMenuItem("Open", "actionDocOpen");
		
		//save document
		mApplication.setAccelsForAction("win.actionDocSave", ["<Control>s"]);
		AddToolObject("docsave","Save", "Save Document",
			Config.GetResource("icons","docsave","resource","document-save.png"),"win.actionDocSave");
		auto menuItemSave = new GMenuItem("Save", "actionDocSave");
       
        //save as
		mApplication.setAccelsForAction("win.actionDocSaveAs", ["<Control><Shift>s"]);
		AddToolObject("docsaveas", "Save As", "Save Document As...",
		    Config.GetResource("icon","docsaveas", "resource", "document-save-as.png"), "win.actionDocSaveAs");
		auto menuItemSaveAs = new GMenuItem("Save As...", "actionDocSaveAs");	
		
		//save all
		mApplication.setAccelsForAction("win.actionDocSaveAll", ["<Super>s"]);
		AddToolObject("docsaveall", "Save All", "Save All Open Documents",
			Config.GetResource("icon","docsaveall", "resource", "document-save-all.png"), "win.actionDocSaveAll");
		auto menuItemSaveAll = new GMenuItem("Save All", "actionDocSaveAll");
		
		//close
		mApplication.setAccelsForAction("win.actionDocClose", ["<Control>w"]);
		AddToolObject("docclose","Close", "Close Document",
			Config.GetResource("icons","docclose","resource","document-close.png"),"win.actionDocClose");
		auto menuItemClose = new GMenuItem("Close", "actionDocClose");		
		
		//close all
		mApplication.setAccelsForAction("win.actionDocCloseAll", ["<Control><Shift>w"]);
		AddToolObject("doccloseall","Close All", "Close All Documents",
			Config.GetResource("icons","doccloseall","resource","document-close-all.png"),"win.actionDocCloseAll");
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
		dwrite("opening a new document.");
	}
	void action_DocSave(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.Save();
	}
	void action_DocSaveAs(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.SaveAs();
		dwrite("saving as a new document.");
	}
	void action_DocSaveAll(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.SaveAll();
    	dwrite("saving all documents");
    }
	void action_DocClose(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.Close();
		dwrite("close a new document.");
	}
	void action_DocCloseAll(void* simAction, void* varTarget, void* voidUserData)
	{
    	mDocBook.CloseAll();
		dwrite("Closing all  a new document.");
	}
	void action_DocCompile(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("compiling a new document.");
	}
	void action_DocRun(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("running a new document.");
	}
}

