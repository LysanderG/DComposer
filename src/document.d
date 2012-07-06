// untitled.d
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

module document;

import dcore;
import ui;
import docman;

import std.path;
import std.stdio;
import std.file;
import std.utf;
import std.encoding;
import std.conv;
import std.datetime;
import std.signals;

import gsv.SourceView;
import gsv.SourceBuffer;
import gsv.SourceStyleSchemeManager;
import gsv.SourceLanguageManager;
import gsv.SourceMark;

import gtk.Action;
import gtk.Label;
import gtk.Widget;
import gtk.HBox;
import gtk.Button;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.Menu;
import gtk.MessageDialog;
import gtk.Clipboard;
import gtk.TextIter;
import gtk.Paned;
import gtk.ScrolledWindow;

import gtkc.gtk;

import gdk.Event;

import gobject.ObjectG;
import gobject.ParamSpec;

import pango.PgFontDescription;

extern(C) GdkAtom gdk_atom_intern(const char *, bool);

class DOCUMENT : SourceView
{
	private:
	
	string 			mName;
	bool			mVirgin;

	ulong 			mInitialLine;
	
	SysTime			mFileTimeStamp;

	bool			mInPastingProcess;

	HBox			mTabWidget;
	Label			mTabLabel;
	Button 			mTabXBtn;

	Widget			mPageWidget;


//**********************************************************************************************************************

	bool CheckForExternalChanges(GdkEventFocus* Event, Widget widget)
	{
		if(Virgin)return false;
		auto timeStamp = timeLastModified(Name);

		if(mFileTimeStamp <  timeStamp)
		{
            auto msg = new MessageDialog(dui.GetWindow, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, true,null);
            msg.setMarkup(Name ~ " has been modified externally.\nWould you like to reload it with any changes\nor ignore changes?\n(" ~ mFileTimeStamp.toISOExtString() ~ " / " ~ timeStamp.toISOExtString() ~ ")");
            msg.addButton("Reload", 1000);
            msg.addButton("Ignore", 2000);

            auto rv = msg.run();
            msg.hide();           
            

            if(rv == 1000)
            {
				mFileTimeStamp = timeLastModified(Name);
				string Text = ReadUTF8(Name);
				mVirgin = false;
                getBuffer().beginNotUndoableAction();
                getBuffer().setText(Text);
                getBuffer().endNotUndoableAction();
				getBuffer().setModified(false);      
			}
            else mFileTimeStamp = timeLastModified(Name);
			return true;
        }       
        
        return false;
    }
			
		

	void UpdatePageTab()
	{
		if(Modified) mTabLabel.setText ("[* " ~ ShortName ~ " *]");
		else mTabLabel.setText(ShortName);
		//mTabLabel.setTooltipText(Name);
		mTabWidget.setTooltipText(Name);
		mTabWidget.showAll();
		
	}

	void Configure()
	{
		auto Language = SourceLanguageManager.getDefault().guessLanguage(Name,null);
        getBuffer.setLanguage(Language);

		string StyleId = Config.getString("DOCMAN","style_scheme", "cobalt");

		SourceStyleSchemeManager.getDefault().appendSearchPath("$(HOME_DIR)/styles/");
        getBuffer().setStyleScheme(SourceStyleSchemeManager.getDefault().getScheme(StyleId));

		setAutoIndent(Config.getBoolean("DOCMAN", "auto_indent", true));
        setIndentOnTab(Config.getBoolean("DOCMAN", "indent_on_tab", true));
        setInsertSpacesInsteadOfTabs(Config.getBoolean("DOCMAN","spaces_for_tabs", true));

		if(Config.getBoolean("DOCMAN", "smart_home_end", true))setSmartHomeEnd(SourceSmartHomeEndType.AFTER);
        else setSmartHomeEnd(SourceSmartHomeEndType.DISABLED);

		setHighlightCurrentLine(Config.getBoolean("DOCMAN", "hilite_current_line", false));
        setShowLineNumbers(Config.getBoolean("DOCMAN", "show_line_numbers",true));
        setShowRightMargin(Config.getBoolean("DOCMAN", "show_right_margin", true));
        getBuffer.setHighlightSyntax(Config.getBoolean("DOCMAN", "hilite_syntax", true));
        getBuffer.setHighlightMatchingBrackets(Config.getBoolean("DOCMAN", "match_brackets", true));
        setRightMarginPosition(Config.getInteger("DOCMAN", "right_margin", 120));
        setIndentWidth(Config.getInteger("DOCMAN", "indention_width", 8));
        setTabWidth(Config.getInteger("DOCMAN", "tab_width", 4));

        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.getString("DOCMAN", "font", "mono 18")));

	}

	void OnTabXButton(Button X)
	{
		dui.GetDocMan.Close(this);
	}

	void PopulateContextMenu(GtkMenu* gtkBigMenu, TextView ThisOne)
	{
		Menu X = new Menu(gtkBigMenu);

		foreach(action; dui.GetDocMan.GetContextMenuActions())
		{
			X.prepend(action.createMenuItem());
		}
	}
		
	void SetBreakPoint(TextIter ti, GdkEvent * event, SourceView sv)
	{
		scope (failure) {Log.Entry("Error toggling breakpoint.","Error");return;}

		auto x = getBuffer.getSourceMarksAtIter(ti,"breakpoint");

        if(x is null)
        {
            getBuffer.createSourceMark(null, "breakpoint", ti);
            BreakPoint.emit("add", Name, ti.getLine() + 1);
            return;
        }
        getBuffer.removeSourceMarks(ti, ti, "breakpoint");
        BreakPoint.emit("remove", Name, ti.getLine()+1);
	}

	void SetUpEditSensitivity()
    {

		//from what I gather 69 is the system clipboard
		//not very good programming here but I'm at a loss at how else to procedd
        auto Clpbd = Clipboard.get(cast(GdkAtom)69);

        dui.Actions.getAction("PasteAct").setSensitive(Clpbd.waitIsTextAvailable());
        dui.Actions.getAction("CutAct").setSensitive(getBuffer.getHasSelection());
        dui.Actions.getAction("CopyAct").setSensitive(getBuffer.getHasSelection());
        return ;
    }

    void OnInsertText(TextIter ti, string text, int len, TextBuffer Buffer)
    {
       
        if(text == "\n") NewLine.emit(ti, text, getBuffer);
        if(text == "}" ) CloseBrace.emit(ti, text, getBuffer);

        TextInserted.emit(this, ti, text, getBuffer);
    }
		
//**********************************************************************************************************************



	public :
	///Has buffer been modified since last save. (or instantiation)
	@property bool Modified() {return cast(bool)getBuffer().getModified();}
	///Fully qualified path name of this objects file
	@property string Name() {return mName;}
	///ditto
	@property void Name(string NewName){ mName = NewName; UpdatePageTab();}
	///Basically a name to put in the page tab
	@property string ShortName(){return baseName(mName);}
	///Indicates if this object has an actual file associated with it
	@property bool Virgin(){return mVirgin;}
	@property bool Pasting(){return mInPastingProcess;}
	///Returns current line number
	@property ulong LineNumber()
	{
		auto ti = new TextIter;
		getBuffer.getIterAtMark(ti, getBuffer.getInsert());
		auto xline = ti.getLine();
		return cast(ulong)xline;
	}
	@property string LineText()
	{
		auto tistart = new TextIter;
		auto tiend = new TextIter;

		getBuffer.getIterAtMark(tistart, getBuffer.getInsert());
		tiend = tistart.copy();
		tistart.setLineOffset(0);
		tiend.forwardToLineEnd();
		return tistart.getText(tiend);
	}

	///returns the word currently at the insert mark (cursor)
	///May have to spice this up a little to reflect a programming environment
	@property string Word()
	{
        TextIter ti = new TextIter; 
        getBuffer.getIterAtMark(ti, getBuffer.getInsert());
        if(!ti.insideWord)return "";
        TextIter tiend  = ti.copy();
        tiend.forwardWordEnd();
        if(!ti.startsWord())ti.backwardWordStart();
        return ti.getSlice(tiend);        
    }

    ///Returns any selected text
    @property string Selection()
    {
		TextIter tistart = new TextIter;
		TextIter tiend = new TextIter;
		
		if(getBuffer.getSelectionBounds(tistart, tiend))
		{
			return getBuffer.getText(tistart, tiend, false);
		}
		return null;
	}
		
		
	

	this()
	{
		mTabWidget = new HBox(0,1);

		mTabXBtn  = new Button(StockID.CLOSE, &OnTabXButton, true);
		mTabXBtn.setBorderWidth(2);
		mTabXBtn.setRelief(ReliefStyle.NONE);
		mTabXBtn.setSizeRequest(20, 20);

		mTabLabel = new Label("constructing");

		mTabWidget.add(mTabLabel);
		mTabWidget.add(mTabXBtn);

		ScrolledWindow ScrollWin = new ScrolledWindow(null, null);
		ScrollWin.add(this);
		ScrollWin.setPolicy(GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);
		ScrollWin.showAll();
		
		mPageWidget = ScrollWin;	
	}

	/**Basically connects signals.  Not done in constructor to ensure all objects (meaning Config for now)
	 * have actually been created and exist.
	 * */	
	void Engage()
	{
		//what to do when Config keyfile changes
		Config.Reconfig.connect(&Configure);

		//see if another program has altered text whenever we focus on document
		addOnFocusIn(&CheckForExternalChanges);

		//build a popup menu on right clicks (items for menu from docman)
		addOnPopulatePopup(&PopulateContextMenu);

		//this allows certain elements to see paste as a single insert vs an insert for each char
		getBuffer.addOnPasteDone (delegate void (Clipboard cb, TextBuffer tb) {mInPastingProcess = false;});
		addOnDragEnd(delegate void (GdkDragContext* Context, Widget W){mInPastingProcess = false;});
        addOnDragBegin(delegate void (GdkDragContext* Context, Widget W){mInPastingProcess = true;});

		//this is to combat the open file on line (tryting to scroll on a window that isnt 'done'
		addOnExpose(delegate bool (GdkEventExpose* ev, Widget w){if(mInitialLine != ulong.max){GotoLine(mInitialLine);mInitialLine = ulong.max;}return false;});

		//send a signal to any debugger that user wants a breakpoint (oh and marks line)
		addOnLineMarkActivated(&SetBreakPoint);

		//this controls editing menu (cut/copy/paste) sensitivity (ie grayed out)
		addOnKeyRelease(delegate bool(GdkEventKey* k, Widget w){SetUpEditSensitivity();return false;});
        addOnButtonRelease( delegate bool(GdkEventButton* b, Widget w){SetUpEditSensitivity();return false;});

        //Change the TAB look to let user know the text has been changed and should be saved
        getBuffer().addOnModifiedChanged(delegate void (TextBuffer Buf){UpdatePageTab();});

		//mostly to let elements know text is being inserted
		getBuffer.addOnInsertText(&OnInsertText, cast(GConnectFlags)1);


		//stuff that I dont want to repeat every configure ( and some that should be configured)
        setShowLineMarks(true);
        setMarkCategoryIconFromStock ("breakpoint", "gtk-yes");
        setMarkCategoryIconFromStock ("lineindicator", "gtk-go-forward");
        getBuffer.createTag("hiliteback", "background", "green");
        getBuffer.createTag("hilitefore", "foreground", "yellow");

		UpdatePageTab();
		
		Configure();

	}

	/// Not sure if I actually need this.  Intended to reverse anything done in Engage.
	void Disengage()
	{
		//what to do here??
	}
	
	/**
	 * Returns a new virgin DOCUMENT
	 * Empty of text and ready to go.
	 * Title will determine file type.
	 * */
	static DOCUMENT Create(string title)
	{
		DOCUMENT Rval = new DOCUMENT;

		Rval.mName = absolutePath(title);
		Rval.mVirgin = true;
		Rval.Engage();
		return Rval;
	}

	/**
	 * Returns a new DOCUMENT associated with FileName.
	 * Definitely not a virgin.  Even if FileName is empty.
	 * */
	static DOCUMENT Open(string FileName, ulong LineNo = 1)
	{
		string Text;
		try
		{
			
			Text = ReadUTF8(FileName);
		}
		catch(FileException FileX)
		{
			string reason = "File read error. (Check permissions)";
			if(!exists(FileName))reason = "File does not exist";

			
			auto msg = new MessageDialog(dui.GetWindow(), GtkDialogFlags.MODAL, GtkMessageType.ERROR, ButtonsType.OK,
            false, reason);

            msg.setTitle("Unable to open " ~ FileName);
            msg.run();
            msg.destroy();
            return null;
		}
		catch (UTFException UtfX)
		{			
			auto msg = new MessageDialog(dui.GetWindow(), GtkDialogFlags.MODAL, GtkMessageType.ERROR, ButtonsType.OK,
            false, "DComposer offers its most sincere apologies.\nThis development version is currently limited\n to opening valid UTF files.");

            msg.setTitle("Unable to open " ~ FileName);
            msg.run();
            msg.destroy();
            return null;
		}

		
		DOCUMENT Rval = new DOCUMENT;
		Rval.mFileTimeStamp = timeLastModified(FileName);
		Rval.mName = FileName;
		Rval.mVirgin = false;
		Rval.getBuffer().beginNotUndoableAction();
		Rval.getBuffer().setText(Text);
		Rval.getBuffer().endNotUndoableAction();
		Rval.getBuffer().setModified(false);      
		Rval.mInitialLine = LineNo;
		Rval.Engage();

		return Rval;
	}

	/**
	 *  Confirms closing a modified file.
	 *  Possibly saves before returning the result.
	 *  Caller is responsible for anything else.
	 *  Such as freeing resources.
	 * */
	bool Close(bool Quitting = false)
	{
		if(!Modified) return true;

		auto ToSaveDiscardOrKeepOpen = new MessageDialog(dui.GetWindow(), DialogFlags.DESTROY_WITH_PARENT, GtkMessageType.QUESTION, ButtonsType.NONE, true, null); 
        ToSaveDiscardOrKeepOpen.setMarkup(Name ~ "\nHas unsaved changes.\nWhat do you wish to do?");
        ToSaveDiscardOrKeepOpen.addButton("Save Changes", cast(GtkResponseType) 1);
        ToSaveDiscardOrKeepOpen.addButton("Discard Changes", cast(GtkResponseType) 2);
        if(!Quitting)ToSaveDiscardOrKeepOpen.addButton("Do not Close", cast(GtkResponseType) 3);

        ToSaveDiscardOrKeepOpen.setTitle("Closing DComposer Document");

        auto rVal = cast(int) ToSaveDiscardOrKeepOpen.run();
        ToSaveDiscardOrKeepOpen.destroy();

        switch(rVal)
        {
            case 1: Save();return true;
            case 2: return true;
            case 3: return false;
            case GtkResponseType.GTK_RESPONSE_DELETE_EVENT : return true;
            default : Log().Entry("Bad (unexpected) ResponseType from Confirm CloseFileDialog", "Error");
        }

        return true;
	}

	/**
	 * Writes buffer to mName.
	 * Throws an exception if it fails.
	 * */
	void Save()
	{
		string saveText = getBuffer.getText();

		std.file.write(mName, saveText);

		getBuffer.setModified(false);
		mFileTimeStamp = timeLastModified(mName);
		mVirgin = false;
	}

	/**
	 * Changes mName and calls Save()
	 * */
	void SaveAs(string NewName)
	{
		string OriginalName = Name;
		scope(failure) Name = OriginalName;
		Name = NewName;
		Save();
	}

	/**
	 * Moves cursor (insert mark) to Line.
	 * Watch out for off by one errors. At least 'til I check it out.
	 * */
	void GotoLine(ulong Line)
	{
		Line = Line;
		TextIter tistart, tiend;
		tistart = new TextIter;
        tiend = new TextIter;
        getBuffer.getStartIter(tistart);
        getBuffer.getEndIter(tiend);
        getBuffer.removeSourceMarks(tistart, tiend, "lineindicator");

        TextIter ti = new TextIter;
        getBuffer.getIterAtLine(ti, cast(int)Line);
		auto mark = getBuffer.createSourceMark(null, "lineindicator", ti);
		

        getBuffer.placeCursor(ti);
        
        scrollToMark (mark, 0.01, true , 0.000, 0.500);
    }

	/**
	 * Performs the usual edit actions on the DOCUMENT.
	 * Verb can be "UNDO", "REDO", "CUT", "COPY", "PASTE", or "DELETE"
	 * */
    void Edit(string Verb)
    {
        switch (Verb)
        {
            case "UNDO"  :   getBuffer.undo();   break;
            case "REDO"  :   getBuffer.redo();   break;
            case "CUT"   :   getBuffer.cutClipboard(Clipboard.get(cast(GdkAtom)69),1); break;
            case "COPY"  :   getBuffer.copyClipboard(Clipboard.get(cast(GdkAtom)69)); break;
            case "PASTE" :   mInPastingProcess = true; getBuffer.pasteClipboard(Clipboard.get(cast(GdkAtom)69),null, 1); break;
            case "DELETE":   getBuffer.deleteSelection(1,1);break;

            default : Log.Entry("Currently unavailable function :"~Verb,"Debug");
        }
    }

    Widget PageWidget()
    {
		return mPageWidget;
	}
	void SetPageWidget(Widget PageWidget)
	{
		mPageWidget = PageWidget;
	}
	Widget TabWidget()
	{
		return mTabWidget;
	}

	void HiliteFoundMatch(int Line, int start, int len)
    {
        TextIter tstart = new TextIter;
        TextIter tend = new TextIter;

        getBuffer.getStartIter(tstart);
        getBuffer.getEndIter(tend);
        getBuffer.removeTagByName("hiliteback", tstart, tend);
        getBuffer.removeTagByName("hilitefore", tstart, tend);

        getBuffer.getIterAtLineOffset(tstart, Line, start);
        getBuffer.getIterAtLineOffset(tend, Line, start+len);

         
        getBuffer.applyTagByName("hiliteback", tstart, tend);
        getBuffer.applyTagByName("hilitefore", tstart, tend);
    }


	
		
	mixin Signal!(TextIter, string, TextBuffer) NewLine;
    mixin Signal!(TextIter, string, TextBuffer) CloseBrace;
    mixin Signal!(DOCUMENT, TextIter, string, SourceBuffer) TextInserted;
    mixin Signal!(string, string, int) BreakPoint;
}
	



string ReadUTF8(string FileName)
{
	bool Succeeded;

	ubyte[] data = cast(ubyte[])read(FileName);
    
    if(try8(data))  return toUTF8(cast( char[])data);   
    if(try32(data)) return toUTF8(cast(dchar[])data);
    throw new Exception("Error reading " ~ FileName);    
}

bool try8(const ubyte[] data)
{
	scope(failure) return false;
	validate!(char[])(cast(char[])data);
	return true;
}

bool try16(const ubyte[] data)
{
	scope(failure) return false;
	validate!(wchar[])(cast(wchar[])data);
	return true;
}
bool try32(const ubyte[] data)
{
	scope(failure) return false;
	validate!(dchar[])(cast(dchar[])data);
	return true;
}

	


