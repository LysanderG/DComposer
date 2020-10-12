module ui_docbook;

import ui;
import ui_action;
import ui_toolbar;
import log;
import config;


import gdk.Event;
import gio.FileIcon;
import gio.FileT;
import gio.SimpleAction;
import gio.SimpleActionGroup;
import glib.Variant;
import gtk.Builder;
import gtk.EventBox;
import gtk.Label;
import gtk.MenuItem;
import gtk.Notebook;
import gtk.ScrolledWindow;
import gtk.Widget;



class UI_DOCBOOK
{

private:
	Notebook 			mDocBook;
    Label				mInfoLabel;
	EventBox			mEventBox;
	
public:

	void Engage(Builder mBuilder)
	{
		mDocBook = cast(Notebook)mBuilder.getObject("doc_book");
		mInfoLabel = cast(Label)mBuilder.getObject("doc_status");
		mEventBox = cast(EventBox)mBuilder.getObject("doc_eventbox");
		
		mEventBox.addOnEnterNotify(delegate bool(GdkEventCrossing* mode, Widget self)
		{
			mDocBook.setShowTabs(true);
			return false;
        });
        mDocBook.addOnLeaveNotify(delegate bool(GdkEventCrossing* mode, Widget self)
        {

	        mDocBook.setShowTabs(false);
	        return false;
        });
        
        
        EngageActions();       
    }
    
    void Mesh()
	{
    }
    
    void Disengage()
    {
    }
    
private:
	
	void EngageActions()
	{
		
		GActionEntry[] actEntNew = [
			{"actionDocNew", &action_DocNew, null, null, null},
			{"actionDocOpen", &action_DocOpen, null, null, null},
			{"actionDocSave", &action_DocSave, null, null, null},
			{"actionDocSaveAs", &action_DocSaveAs, null, null, null},
			{"actionDocClose", &action_DocClose, null, null, null},
			{"actionDocCloseAll", &action_DocCloseAll, null, null, null},
			{"actionDocCompile", &action_DocCompile, null, null, null},
			];
		GetMainWin().addActionEntries(actEntNew, null);
		
		
		//new
		GetApp().setAccelsForAction("win.actionDocNew",["<Control>n"]);
		AddToolObject("docnew","New","Create a new D source file",
			Config.GetResource("icons","docnew","resource", "document-text.png"),"win.actionDocNew");
        //open document
		GetApp().setAccelsForAction("win.actionDocOpen", ["<Control>o"]);
		AddToolObject("docopen","Open", "Open Document",
			Config.GetResource("icons","docopen","resource","folder-open-document-text.png"),"win.actionDocOpen");
		//save document
		GetApp().setAccelsForAction("win.actionDocSave", ["<Control>s"]);
		AddToolObject("docsave","Save", "Save Document",
			Config.GetResource("icons","docsave","resource","document-save.png"),"win.actionDocSave");
		//save as
		//save all
		//close
		GetApp().setAccelsForAction("win.actionDocClose", ["<Control>w"]);
		AddToolObject("docclose","Close", "Close Document",
			Config.GetResource("icons","docclose","resource","document-close.png"),"win.actionDocClose");
		
		//close all
		
		//compile document
		//run document
		//unittest document
		
	}
	
}


extern (C)
{
	void action_DocNew(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("creating a new document.");
	}
	void action_DocOpen(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("opening a new document.");
	}
	void action_DocSave(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("saving a new document.");
		
	}
	void action_DocSaveAs(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("saving as a new document.");
		
	}
	void action_DocClose(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("close a new document.");
	}
	void action_DocCloseAll(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("Closing all  a new document.");
	}
	void action_DocCompile(void* simAction, void* varTarget, void* voidUserData)
	{
		dwrite("compiling a new document.");
	}
}

