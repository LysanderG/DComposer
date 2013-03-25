// document.d
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
import std.uni;

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
import gtk.RecentManager;

import gtkc.gtk;

import gdk.Event;
import gdk.DragContext;
import gdk.Color;
import gdk.Rectangle;

import gobject.ObjectG;
import gobject.ParamSpec;

import pango.PgFontDescription;

extern(C) GdkAtom gdk_atom_intern(const char *, bool);

/**
 * Testing Documentation
 * DOCUMENT is basically SourceView with a couple of personal tweaks
 * */
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

	int				mPopUpX;
	int				mPopUpY;
	bool			mPopUpByKeyBoard;


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
		if(Modified)
		{
			mTabLabel.setMarkup(`<span foreground="red" >[* `~ShortName~` *]</span>`);
		}
		else mTabLabel.setText(ShortName);
		mTabWidget.setTooltipText(Name);
		mTabWidget.showAll();

	}

	void Configure()
	{
		auto Language = SourceLanguageManager.getDefault().guessLanguage(Name,null);
        getBuffer.setLanguage(Language);

		string StyleId = Config.getString("DOCMAN","style_scheme", "mnml");

		SourceStyleSchemeManager.getDefault().appendSearchPath(Config.ExpandPath("$(HOME_DIR)/styles/"));
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

        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.getString("DOCMAN", "font", "Inconsolata Bold 12")));

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

	/**
	 * acutally this catches any button press and saves pointer position
	 * to use for popup location
	 * better name might be last button press
	 * */

	bool CatchPopUpMenuLocation(GdkEventButton * eb,Widget W)
	{

		getPointer(mPopUpX, mPopUpY);
		mPopUpByKeyBoard = false;
		return false;

	}

	/**
	 * stores when the popupmenu aka context menu
	 * is brought up by the keyboard -- as opposed to right mouse button
	 * this info will be used to determine how to use WordAtPopUpMenu
	 * */
	bool KeyPopUpMenu(Widget w)
	{
		mPopUpByKeyBoard = true;
		return false;
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
		if(text.length > 1) mInPastingProcess = true;
		//else mInPastingProcess = false;
        if(text == "\n") NewLine.emit(ti, text, getBuffer);
        if(text == "}" ) CloseBrace.emit(ti, text, getBuffer);

		//dui.Status.push(0, (Pasting?"Pasting":"not Pasting"));
        TextInserted.emit(this, ti.copy(), text, getBuffer);
        mInPastingProcess = false;

    }


    void DragCatcher(GdkDragContext* Cntxt, int x, int y, GtkSelectionData* SelData, uint info, uint time, Widget user_data)
    {

		auto dragctx = new DragContext(Cntxt);
		auto xx = dragctx.listTargets();
		while ( xx !is null)
		{
			xx = xx.next();
		}
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
	@property void Pasting(bool P){mInPastingProcess = P;}
	///Returns current line number
	@property int LineNumber()
	{
		auto ti = new TextIter;
		getBuffer.getIterAtMark(ti, getBuffer.getInsert());
		return ti.getLine();
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

	/**
	*  Returns fully scoped symbol currently under cursor if any.
	*/
	string Symbol(bool FullSymbol = false)
	{
		TextIter  PlaceHolder = new TextIter;
		auto CursorTI = new TextIter;
		getBuffer.getIterAtMark(CursorTI, getBuffer.getInsert());

		return Symbol(CursorTI, PlaceHolder, FullSymbol);
	}
	/**
	*  Returns fully scoped symbol currently under cursor if any.
	*  Also returns TextIter at beginning of symbol.
	*/
	string Symbol(ref TextIter BeginsAt, bool FullSymbol)
	{
		auto CursorTI = new TextIter;
		getBuffer.getIterAtMark(CursorTI, getBuffer.getInsert());
		return Symbol(CursorTI, BeginsAt, FullSymbol);
	}

	/**
	*  Returns fully scoped symbol at AtIter.
	*  And where that symbols begins is returned in BeginsAtIter
	*/
	string Symbol(TextIter AtIter, ref TextIter BeginsAtIter , bool FullScan = false)
	{


		bool SkipParensBack(ref TextIter ti)
		{
			int Pdepth = 1;
			while(ti.backwardChar() )
			{
				dchar tchar = ti.getChar();
				if (tchar == ')') Pdepth ++;
				if (tchar == '(') Pdepth --;
				if (Pdepth < 1) return false;
			}
			return true;
		}
		bool SkipParensFore(ref TextIter ti)
		{
			int Pdepth = 1;

			while(ti.forwardChar())
			{
				dchar tchar = ti.getChar();
				if(tchar == '(')Pdepth++;
				if(tchar == ')')Pdepth--;
				if(Pdepth < 1) return false;
			}
			return true;
		}
		dstring ScanBack(TextIter ti)
		{
			TextIter tmpIter = ti.copy();
			dstring rv = "";
			dchar ch;
			dchar LastCh = 0;
			bool Terminate = false;

			scope(exit) BeginsAtIter = ti.copy();


			while (tmpIter.backwardChar())
			{
				ch = tmpIter.getChar();

				switch (ch)
				{
					case 'a' : .. case 'z':
					case 'A' : .. case 'Z':
					case '0' : .. case '9':
					case '_' :
					{
												if(( LastCh.isSpace) )
												{
													Terminate = true;
													break;
												}
												rv = ch ~ rv;
												LastCh = ch;
												ti = tmpIter.copy();
												break;
					}

					case '.' :
					{
												if( LastCh.isNumber())
												{
													Terminate = true;
													//rv.length = 0;
													break;
												}
												if( LastCh == '.')
												{
													Terminate = true;
													break;
												}
												rv = ch ~ rv;
												LastCh = ch;

												break;
					}

					case ')' :
					{
												if( (LastCh != '.') && (LastCh != 0))
												{
													Terminate = true;
													break;
												}
												Terminate = SkipParensBack(ti);
												LastCh = '(';
												break;
					}

					default :
					{
												if((ch.isSpace) || (ch == '\t'))
												{
													if(LastCh == '(') break;
													if(LastCh == '.') break;
													//if(LastCh == 0)break;
													LastCh = ch;
													break;
												}
												Terminate = true;
					}
				}
				if(Terminate)break;
			}
			if((rv.length > 0) && (rv[0].isNumber)) rv = [0];


			return rv;
		}

		dstring ScanFore(TextIter ti)
		{
			bool Terminate = false;
			dstring rv = "";
			dchar ch;
			dchar LastCh;
			do
			{
				ch = ti.getChar();
				switch (ch)
				{
					case 0 :
					{
											Terminate = true;
											break;
					}

					case 'A': .. case 'Z':
					case 'a': .. case 'z':
					case '0': .. case '9':
					case '_':
					{
											if ((LastCh.isSpace()) || (LastCh == ')'))
											{
												Terminate = true;
												break;
											}
											rv ~= ch;
											LastCh = ch;
											break;
					}

					case '.' :
					{
											if(LastCh == '.')
											{
												Terminate = true;
												break;
											}
											rv ~= ch;
											LastCh = ch;
											break;
					}

					case '(' :
					{
											Terminate = SkipParensFore(ti);
											LastCh = ')';
											break;
					}

					default :
					{
											if((ch.isSpace) || (ch == '\t'))
											{
												if(LastCh == ')') break;
												if(LastCh == '.') break;
												LastCh = ch;
												break;
											}
											Terminate = true;
											break;
					}
				}

				if(Terminate) break;
			}while(ti.forwardChar());
			return rv;
		}


		auto pre = ScanBack(AtIter.copy());
		dstring post = "";
		if(FullScan) post = ScanFore(AtIter.copy());

		if((pre.length == 1) && (pre[0] == 0)) return ""; //basically an invalid symbol (starts with number)

		return to!string(pre ~ post);
	}



	@property string SymbolOld()
	{

		bool Terminate = false;

		auto cursorti   = new TextIter;
		auto workingti  = new TextIter;

		getBuffer.getIterAtMark(cursorti, getBuffer.getInsert());

		dstring rv = "";


		bool SkipParensBack()
		{
			int Pdepth = 1;
			if(workingti.backwardChar() == 0) return true;//skip the first ).
			do
			{

				dchar tchar = workingti.getChar();
				if (tchar == ')') Pdepth ++;
				if (tchar == '(') Pdepth --;
				if (Pdepth < 1) return false;
			}while(workingti.backwardChar() );
			return true;
		}
		bool SkipParensFore()
		{
			int Pdepth = 1;
			if(!workingti.forwardChar()) return true;
			do
			{
				if(Pdepth < 1) return false;
				dchar tchar = workingti.getChar();
				if(tchar == '(')Pdepth++;
				if(tchar == ')')Pdepth--;

			}while(workingti.forwardChar());
			return true;
		}
		bool SkipWhiteSpaceBack()
		{
			while(workingti.backwardChar())
			{
				dchar tchar = workingti.getChar();
				if(tchar.isSpace())continue;
				if(tchar == ')') {SkipParensBack();continue;}
				if(tchar.isAlpha())return false;
				if(tchar.isNumber())return false;
				if(tchar == '_') return false;
				return true;
			}
			return true;
		}
		bool SkipWhiteSpaceFore()
		{
			while(workingti.forwardChar())
			{
				dchar tchar = workingti.getChar();
				if(tchar.isSpace())continue;
				if(tchar.isAlpha())return false;
				//if(tchar.isNumber())return false;
				if(tchar == '_') return false;
				return true;
			}
			return true;
		}

		bool SkipToDotBack()
		{
			while(workingti.backwardChar())
			{
				dchar tchar = workingti.getChar();
				if(tchar == ')') {SkipParensBack(); continue;}
				if(tchar.isSpace()){SkipWhiteSpaceBack(); continue;}
				if(tchar == '.') return false;
				return true;
			}
			return true;
		}
		bool SkipToDotFore()
		{
			while(workingti.forwardChar())
			{
				dchar tchar = workingti.getChar();
				if(tchar.isSpace())continue;
				if(tchar == '.') return false;
				return true;
			}
			return true;
		}

		workingti = cursorti.copy();
		while(workingti.backwardChar())
		{
			dchar ch = workingti.getChar();
			switch(ch)
			{
				case 'a': .. case'z':
				case 'A': .. case'Z':
				case '_'			:
				case '0': .. case'9':
				case '.'			:

				{
										rv = ch ~ rv;

										break;
				}

				case ' '			:
				case '\t'			:
				{
										break;
				}

				case ')'			:
				{
										if((rv.length > 0) && (rv[0] != '.'))rv.length = 0;
										if(!SkipParensBack())Terminate = false;
										else Terminate = true;
										break;
				}
				default				: 	Terminate = true;
			}
			if(Terminate)break;
		}

		Terminate = false;
		workingti = cursorti.copy();
		do
		{
			dchar ch = workingti.getChar();
			switch(ch)
			{
				case 'a': .. case'z':
				case 'A': .. case'Z':
				case '_'			:
				case '0': .. case'9':
				{
										rv ~= ch;

										break;
				}

				case ' '			:
				case '\t'			:
				{
										if(!SkipToDotFore())
										{
											Terminate = false;
											rv ~= workingti.getChar();
										}
										else Terminate = true;
										break;

				}

				case '.'			:
				{
										rv ~= '.';
										if(!SkipWhiteSpaceFore())
										{
											Terminate = false;
											rv ~= workingti.getChar();
										}
										else Terminate = true;
										break;
				}
				case '('			:
				{
										if(!SkipParensFore())
										{
											Terminate = false;
											rv ~= workingti.getChar();
										}
										else Terminate = true;
										break;
				}

				default				: 	Terminate = true;
			}
			if(Terminate)break;
		}while(workingti.forwardChar());

		if(rv.length > 0)if( rv[0].isNumber())return "";
		return to!string(rv);
		//return startti.getText(endti);
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

    /**
     * Word property wasn't up for this
     * So here is WordAtPopUpMenu
     * easy to implement for when mouse popups  the window
     * easy for when keyboard popups the window
     * problem to do it for both
     * hopefully It works the way I think it does.
     * Any errors look here.
     * */
    @property string WordAtPopUpMenu()
    {
		if(mPopUpByKeyBoard) return Word;
		int trailing, xx, yy;

		 windowToBufferCoords (GtkTextWindowType.WIDGET, mPopUpX, mPopUpY, xx, yy);

		TextIter ti = new TextIter;
		TextIter tiFiller = new TextIter;

		getIterAtPosition (ti, trailing, xx, yy);

		return Symbol(ti, tiFiller, true);

		//if(!ti.insideWord)return "";
		//TextIter tiend = ti.copy();
		//tiend.forwardWordEnd();
		//if(!ti.startsWord())ti.backwardWordStart();
		//return ti.getSlice(tiend);
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

		dui.AddIcon("gtk-no", Config.getString("ICONS", "tab_close", "$(HOME_DIR)/glade/cross-button.png"));

		mTabXBtn  = new Button(StockID.NO, true);

		mTabXBtn.setBorderWidth(1);
		mTabXBtn.setRelief(ReliefStyle.NONE);
		mTabXBtn.setSizeRequest(24, 24);

		mTabXBtn.addOnClicked(&OnTabXButton);

		mTabLabel = new Label("constructing");

		mTabWidget.add(mTabLabel);
		mTabWidget.add(mTabXBtn);

		ScrolledWindow ScrollWin = new ScrolledWindow(null, null);
		ScrollWin.add(this);
		ScrollWin.setPolicy(GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);
		ScrollWin.showAll();

		mPageWidget = ScrollWin;
		setName("dcomposerdoc");
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

		//to catch to location of where the popup menu starts
		addOnPopupMenu(&KeyPopUpMenu);
		addOnButtonPress (&CatchPopUpMenuLocation);

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
        getBuffer.createTag("hiliteback", "background", Config.getString("DOCMAN", "find_match_background","darkgreen"));
        getBuffer.createTag("hilitefore", "foreground", Config.getString("DOCMAN", "find_match_foreground","yellow"));


		//trying drag and drop
		addOnDragDataReceived (&DragCatcher);


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

			Text = ReadUTF8(FileName);  //remember this is not std.file.readText (because I can be dumb)
		}
		catch(Exception ex)
		{

			auto msg = new MessageDialog(dui.GetWindow(), GtkDialogFlags.MODAL, GtkMessageType.ERROR, ButtonsType.OK,
            false, ex.msg);

            msg.setTitle("Unable to open " ~ FileName);
            msg.run();
            msg.destroy();
            throw ex; //lets rest of dcomposer know there was an error
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

		string uriFileName = std.uri.encode("file://" ~ FileName);
		RecentManager.getDefault().addItem(uriFileName);

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
            case GtkResponseType.DELETE_EVENT : return true;
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
		scope(failure)
		{
			Log.Entry("Failed to save " ~ mName, "Error");
			return;
		}
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
		Line = Line; //huh??
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

	TextIter HiliteFoundMatch(int Line, int start, int len)
    {

        TextIter tstart = new TextIter;
        TextIter tend = new TextIter;
        TextIter lineiter = new TextIter;


        getBuffer.getStartIter(tstart);
        getBuffer.getEndIter(tend);

        getBuffer.removeTagByName("hiliteback", tstart, tend);
        getBuffer.removeTagByName("hilitefore", tstart, tend);

		if(getBuffer.getLineCount < Line) return null;
		getBuffer.getIterAtLine(lineiter,Line);
		if(lineiter.getCharsInLine() < start+len) return null;

        getBuffer.getIterAtLineOffset(tstart, Line, start);
        getBuffer.getIterAtLineOffset(tend, Line, start+len);

        int characters = tstart.getCharsInLine();

		if( (characters <  start) || (characters < start + len) ) return null;


        getBuffer.applyTagByName("hiliteback", tstart, tend);
        getBuffer.applyTagByName("hilitefore", tstart, tend);

        return tstart.copy();
    }

	void GetIterPosition(TextIter ti, out int xpos, out int ypos, out int xlen, out int ylen)
	{
        GdkRectangle gdkRect;
        int winX, winY, OrigX, OrigY;

        Rectangle LocationRect = new Rectangle(&gdkRect);
        getIterLocation(ti, LocationRect);
        bufferToWindowCoords(GtkTextWindowType.TEXT, gdkRect.x, gdkRect.y, winX, winY);
        getWindow(GtkTextWindowType.TEXT).getOrigin(OrigX, OrigY);
        xpos = winX + OrigX;
        ypos = winY + OrigY;
        xlen = gdkRect.width;
        ylen = gdkRect.height;
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
    throw new Exception("DComposer is limited opening to valid utf files only.\nEnsure " ~ baseName(FileName) ~ " is properly encoded.\nSorry for any inconvenience.");
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




