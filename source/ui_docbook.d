module ui_docbook;

import ui;
import log;
import config;


import gtk.Builder;
import gtk.ScrolledWindow;
import gtk.Notebook;
import gtk.EventBox;
import gdk.Event;
import gtk.Widget;
import gtk.Label;
import gtk.MenuItem;



import gio.SimpleAction;
import gio.SimpleActionGroup;
import gio.FileIcon;
import gio.FileT;

import glib.Variant;


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
		//new document
        auto newdoc = new MenuItem("New", delegate void(MenuItem mi){dwrite("help");},"activate");
        newdoc.showAll();
		//open document
		//save document
		//save as
		//save all
		//close
		//close all
		
		//compile document
		//run document
		//unittest document
		
	}
	
}
