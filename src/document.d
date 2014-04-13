module document;

import ui;
import dcore;

import std.datetime;
import std.file;
import std.path;
import std.algorithm;
import std.string;
import std.uni;
import std.conv;
static import std.process ;

import gtk.TextIter;
import gtk.Widget;
import gtk.Box;
import gtk.Label;
import gtk.ScrolledWindow;
import gtk.Button;
import gtk.TextBuffer;
import gtk.MessageDialog;
import gtk.Adjustment;

import gdk.Event;
import gdk.Keysyms;

import gobject.ObjectG;
import gobject.ParamSpec;

import gsv.SourceView;
import gsv.SourceBuffer;
import gsv.SourceLanguage;
import gsv.SourceLanguageManager;
import gsv.SourceStyleSchemeManager;
import gsv.SourceUndoManager;
import gsv.SourceUndoManagerIF;



class DOCUMENT : SourceView, DOC_IF
{
	private:
	string	mFullName;


	bool	mVirgin;

	Widget 	mPageWidget;
	Box		mTabWidget;
	Label   mTabLabel;
	SourceUndoManagerIF mUndoManager;

	bool 	mIsOpeningScroll;


	SysTime mFileTimeStamp;

	string  mLastSelection;

	void UpdateTabWidget()
	{
		if(Modified)
		{
			mTabLabel.setMarkup(`<span foreground="red" >[* `~TabLabel()~` *]</span>`);
		}
		else mTabLabel.setText(TabLabel());
		mTabWidget.setTooltipText(Name);
	}




	public:

	void SetOpeningScroll()
	{
		mIsOpeningScroll = true;
	}

	this()
	{
		ScrolledWindow ScrollWin = new ScrolledWindow(null, null);
		ScrollWin.setSizeRequest(-1,-1);

		ScrollWin.add(this);

		ScrollWin.setPolicy(GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);
		ScrollWin.showAll();

		auto tabXButton = new Button(StockID.NO, true);

		//tabXButton.setRelief(ReliefStyle.HALF);
		tabXButton.setSizeRequest(8, 8);
		tabXButton.addOnClicked(delegate void (Button x){DocMan.Close(this);});

		mTabWidget = new Box(Orientation.HORIZONTAL, 0);
		//mTabWidget.setSizeRequest(-1, -1);
		mTabLabel = new Label(TabLabel);
		//mTabWidget.add(mTabLabel);
		//mTabWidget.add(tabXButton);
		mTabWidget.packStart(mTabLabel,1, 1, 0);
		mTabWidget.packStart(tabXButton, 0, 0,2);
		mTabWidget.showAll();

		mPageWidget = ScrollWin;

		getBuffer().addOnModifiedChanged(delegate void (TextBuffer Buf){UpdateTabWidget();});
		getBuffer().addOnNotify(delegate void(ParamSpec ps, ObjectG objg){DocMan.NotifySelection();},"has-selection");
		addOnFocus(delegate bool(GtkDirectionType direction, Widget w) {DocMan.NotifySelection(); return false;});
		addOnFocusIn(delegate bool(Event event, Widget w) {CheckExternalModification();return false;});


		//set sensitivity of undo and redo actions for this buffer
		addOnFocusIn(delegate bool(Event event, Widget w)
		{
			mUndoManager = getBuffer.getUndoManager();
			auto unAction = GetAction("ActUndo");
			unAction.setSensitive(mUndoManager.canUndo);

			auto reAction = GetAction("ActRedo");
			reAction.setSensitive(mUndoManager.canRedo);
			return false;

		});
		getBuffer.getUndoManager.addOnCanUndoChanged(delegate void (SourceUndoManagerIF manager)
		{
			auto unAction = GetAction("ActUndo");
			unAction.setSensitive(manager.canUndo);
		});
		getBuffer.getUndoManager.addOnCanUndoChanged(delegate void (SourceUndoManagerIF manager)
		{
			auto reAction = GetAction("ActRedo");
			reAction.setSensitive(manager.canRedo);
		});



		getBuffer().createTag("HiLiteAllSearchBack", "background", Config.GetValue("document", "hiliteallsearchback", "white"));
		getBuffer().createTag("HiLiteAllSearchFore", "foreground", Config.GetValue("document", "hiliteallsearchfore", "black"));

		getBuffer().createTag("HiLiteSearchBack", "background", Config.GetValue("document", "hilitesearchback", "darkgreen"));
		getBuffer().createTag("HiLiteSearchFore", "foreground", Config.GetValue("document", "hilitesearchfore", "yellow"));

		mUndoManager = getBuffer.getUndoManager();
	}

	void Configure()
	{

		auto Lang = SourceLanguageManager.getDefault().guessLanguage(Name, null);
		getBuffer.setLanguage(Lang);

		string StyleID = Config.GetValue("document", "style_scheme", "mnml");
		getBuffer().setStyleScheme(SourceStyleSchemeManager.getDefault().getScheme(StyleID));


		setAutoIndent(Config.GetValue("document", "auto_indent", true));
		setIndentOnTab(Config.GetValue("document", "indent_on_tab", true));
		setInsertSpacesInsteadOfTabs(Config.GetValue("document", "spaces_for_tabs", true));

		bool SmartHomeEnd = Config.GetValue("document", "smart_home_end", true);
		setSmartHomeEnd(SmartHomeEnd ? SourceSmartHomeEndType.BEFORE : SourceSmartHomeEndType.DISABLED);

		setHighlightCurrentLine(Config.GetValue("document", "hilite_current_line", false));
        setShowLineNumbers(Config.GetValue("document", "show_line_numbers",true));
        setShowRightMargin(Config.GetValue("document", "show_right_margin", true));
        getBuffer.setHighlightSyntax(Config.GetValue("document", "hilite_syntax", true));
        getBuffer.setHighlightMatchingBrackets(Config.GetValue("document", "match_brackets", true));
        setRightMarginPosition(Config.GetValue("document", "right_margin", 120));
        setIndentWidth(Config.GetValue("document", "indentation_width", 8));
        setTabWidth(Config.GetValue("document", "tab_width", 4));
        setBorderWindowSize(GtkTextWindowType.BOTTOM, 5);
		setPixelsBelowLines(1);
        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.GetValue("document", "font", "Inconsolata Bold 12")));
	}




	@property string Language()
	{
		return getBuffer().getLanguage().getId();
	}

	@property void Language(string nulang)
	{
		if(nulang is null) getBuffer().setLanguage(null);
		auto lang = SourceLanguageManager.getDefault().getLanguage(nulang);
		if(lang is null) return;
		getBuffer().setLanguage(lang);
	}

	@property void	Name(string nuname)
	{
		mFullName = absolutePath(nuname);
		UpdateTabWidget();
	}
	@property string Name()
	{
		return mFullName;
	}
	@property string TabLabel()
	{
		return baseName(mFullName);
	}


	@property bool 	Virgin()
	{
		return mVirgin;
	}
	@property void  Virgin(bool nuVirgin)
	{
		mVirgin = nuVirgin;
	}

	@property bool 	Modified()
	{
		return cast(bool) getBuffer.getModified();
	}
	@property void  Modified(bool nuModified)
	{
		getBuffer().setModified(nuModified);
	}

	int 	Line()
	{
		auto ti = Cursor();
		//TextIter ti = new TextIter;
		//tBuffer.getIterAtMark(ti, getBuffer().getInsert());
		return ti.getLine();
		//return getBuffer().getInsert().getLine();
	}

	int		Column()
	{
		auto ti = Cursor();
		//TextIter ti = new TextIter;
		//getBuffer.getIterAtMark(ti, getBuffer().getInsert());
		return ti.getLineOffset();
		//return getBuffer().getInsert().getLineOffset();
	}
	string LineText()
	{
		auto tiStart = Cursor();
		auto tiEnd = tiStart.copy();
		tiStart.setLineOffset(0);
		tiEnd.forwardToLineEnd();
		return tiStart.getText(tiEnd);;
	}


	/**
	 * returns the symbol or partial symbol from cursor to scanning left til beginning of symbol
	 **/
	string Symbol()
	{
		dstring rv;
		auto movingTi = Cursor().copy();


		bool MatchParen()
		{
			int parenctr = 1;
			while(movingTi.backwardChar())
			{
				auto ch = cast(dchar)movingTi.getChar();
				if(ch == ')') parenctr++;
				if(ch == '(') parenctr--;
				if(parenctr == 0)
				{
					movingTi.forwardChar();
					return true;
				}
			}
			return false;
		}


		dstring ScanBack()
		{
			enum :int { NO_CHAR, LEGIT_CHAR, LEGIT_CHAR_2, DOT, R_PAREN, L_PAREN, WHITE, ILLEGIT_CHAR}

			dstring rval;
			bool ContinueScanning = true;
			dchar ch_current;
			int ch_prev = NO_CHAR;

			while(movingTi.backwardChar())
			{
				ch_current = movingTi.getChar();
				switch( ch_current)
				{

					case 'a' : .. case 'z':
					case 'A' : .. case 'Z':
					case '_' :
					{
						if(ch_prev == WHITE)
						{
							ContinueScanning = false;
							break;
						}
						rval = ch_current ~ rval;
						ch_prev = LEGIT_CHAR;
						break;
					}
					case '0' : .. case '9':
					{
						if(ch_prev == WHITE)
						{
							ContinueScanning = false;
							break;
						}
						rval = ch_current ~ rval;
						ch_prev = LEGIT_CHAR_2;
						break;
					}

					case ' ' :
					case '\t':
					case '\n':
					{
						if(ch_prev == DOT) break;
						if(ch_prev == R_PAREN) break;
						ch_prev = WHITE;
						break;
					}

					case '.':
					{
						if( (ch_prev == DOT) ||(ch_prev == R_PAREN)) //no "blah..foo" names no "blah.()" either
						{
							ContinueScanning = false;
							break;
						}
						rval = ch_current ~ rval;
						ch_prev = DOT;
						break;
					}

					case '(' :
					{
						if(ch_prev != L_PAREN)
						{
							ContinueScanning = false;
							break;
						}
						ch_prev = R_PAREN;
						break;
					}
					case ')' :
					{
						if(ch_prev != DOT)
						{
							ContinueScanning = false;
							break;
						}
						if(MatchParen())
						{
							ch_prev = L_PAREN;
							break;
						}
						else
						{
							ContinueScanning = false;
							break;
						}
						break;
					}
					default : //illegit char
					{
						ContinueScanning = false;
						ch_prev = ILLEGIT_CHAR;
						break;
					}
				}

				if(ContinueScanning == false)break;
			}
			if((rval.length > 1) && (rval[0].isNumber())) rval = "";
			return rval;
		}

		rv = ScanBack();

		return to!string(rv);
	}

	string FullSymbol()
	{
		string rv;
		auto movingTi = Cursor().copy();


		bool MatchParen()
		{
			int pctr = 1;
			while (movingTi.forwardChar())
			{
				auto ch = movingTi.getChar();
				if(ch == '(') pctr++;
				if(ch == ')') pctr--;
				if(pctr == 0)
				{
					movingTi.forwardChar();
					return true;
				}
			}
			return false;
		}



		string ScanForward()
		{
			enum : int { NO_CHAR, LEGIT_CHAR, LEGIT_CHAR_2, DOT, R_PAREN, L_PAREN, WHITE, ILLEGIT_CHAR}
			dstring rval;
			bool ContinueScanning = true;
			dchar ch_current;
			int ch_prev = NO_CHAR;

			do
			{
				ch_current = movingTi.getChar();
				switch(ch_current)
				{
					case 'a' : .. case 'z':
					case 'A' : .. case 'Z':
					case '_' :
					{
						if(ch_prev == WHITE)
						{
							ContinueScanning = false;
							break;
						}
						rval ~= ch_current;
						ch_prev = LEGIT_CHAR;
						break;
					}
					case '0' : .. case '9' :
					{
						if(ch_prev == WHITE)
						{
							ContinueScanning = false;
							break;
						}
						rval ~= ch_current;
						ch_prev = LEGIT_CHAR_2;
						break;
					}
					case ' ' :
					case '\t':
					case '\n':
					{
						if(ch_prev == DOT) break;
						if(ch_prev == R_PAREN)break;
						ch_prev = WHITE;
						break;
					}
					case '.':
					{
						if((ch_prev == DOT) || (ch_prev == R_PAREN))
						{
							ContinueScanning = false;
							break;
						}
						rval ~= ch_current;
						ch_prev = DOT;
						break;
					}
					case ')' :
					{
						if(ch_prev != L_PAREN)
						{
							ContinueScanning = false;
							break;
						}
						ch_prev = R_PAREN;
						break;
					}
					case '(' :
					{
						if(MatchParen())
						{
							ch_prev = L_PAREN;
							break;
						}
						else
						{
							ContinueScanning = false;
							break;
						}
						break;
					}
					default :
					{
						ContinueScanning = false;
						ch_prev = ILLEGIT_CHAR;
						break;
					}
				}
				if(ContinueScanning == false) break;
			}while(movingTi.forwardChar());

			return to!string(rval);
		}

		rv = Symbol() ~ ScanForward();
		return rv;
	}


	string Word()
	{
		string rv;
		auto ti = Cursor();

		if(ti.insideWord())
		{
			auto tiEnd = ti.copy();
			tiEnd.forwardWordEnds(1);
			ti.backwardWordStarts(1);
			rv = ti.getText(tiEnd);
		}
		return rv;
	}
	string WordUnderPointer()
	{
		return "";
	}
	string Selection()
	{
		TextIter alpha = new TextIter;
		TextIter beta = new TextIter;

		if(getBuffer().getSelectionBounds(alpha, beta)) return getBuffer().getText(alpha, beta, true);

		return "";
	}
	string LastSelection()
	{
		return mLastSelection;
	}
	void 	GotoLine(int LineNo)
	{
		import glib.Timeout;

		//if(LineNo == 0) return;
		MainWindow.setFocus(this);
		if(mIsOpeningScroll)
		{
			auto scrolltimeout = new Timeout(getBuffer().getLineCount()/3, delegate bool()
			{
				mIsOpeningScroll = false;
				TextIter IL = new TextIter;
				getBuffer().getIterAtLine(IL, LineNo);
				getBuffer().placeCursor(IL);
				scrollToIter(IL, 0.25, false, 0, 0);
				return false;
			});
		}
		else
		{
			TextIter IL = new TextIter;
			getBuffer().getIterAtLine(IL, LineNo);
			getBuffer().placeCursor(IL);
			scrollToIter(IL, 0.25, false, 0, 0);
		}
	}

	string GetText(){return getBuffer.getText();}
	void SetText(string txt){getBuffer.setText(txt);}
	void InsertText(string txt)
	{
		getBuffer.beginUserAction();
		getBuffer.insertAtCursor(txt);
		getBuffer.endUserAction();
	}

	void	Save()
	{
		try
		{
			string savetext = getBuffer.getText();
			if(!savetext.endsWith("\n"))savetext ~= "\n";
			std.file.write(Name,savetext);
			Modified = false;
			mFileTimeStamp = timeLastModified(Name);
			mVirgin = false;
		}
		catch(FileException fe)
		{
			Log.Entry(fe.msg,"Error");
			ui.ShowMessage("File Error", fe.msg);
			throw(fe);
		}
	}
	void SaveAs(string NuName)
	{
		Name = NuName;
		Save();
	}
	void Close()
	{
	}


	void ShowMe()
	{
		mPageWidget.showAll();
		mTabWidget.showAll();
		showAll();
	}

	////////////////////////////////////////////////
	//////////////////////////////////////////////////
	@property Widget PageWidget()
	{
		return mPageWidget;
	}
	@property Widget PageTab()
	{
		return mTabWidget;
	}

	void StopUndo(){getBuffer().beginNotUndoableAction();}
	void RestartUndo(){getBuffer(). endNotUndoableAction();}

	void SetTimeStamp()
	{
		mFileTimeStamp = timeLastModified(Name);
	}
	void CheckExternalModification()
	{
		if(Virgin) return;
		auto currentTimeStamp = timeLastModified(Name);

		if(mFileTimeStamp >= currentTimeStamp) return;
        auto msg = new MessageDialog(null, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, true,null);

        string msgtext = TabLabel ~ "\nHas potentially been modified by another program.\nHow do you wish to proceed?";
        if(Modified)msgtext ~= "\n(WARNING! Reloading may result in data loss)";
        msg.setTitle("External Change Detected");
		msg.setMarkup(msgtext);
		msg.addButton("Reload", 1000);
		msg.addButton("Ignore", 2000);
		msg.setDefaultResponse(1000);
		auto msgResponse = msg.run();
		msg.hide();

		mFileTimeStamp = currentTimeStamp;

		if(msgResponse == 2000) return;

		string text = ReadUTF8(Name);
		mVirgin = false;
		getBuffer().beginNotUndoableAction();
        getBuffer().setText(text);
        getBuffer().endNotUndoableAction();
		getBuffer().setModified(false);
	}


	void HiliteSearchResult(int LineNo, int Start, int End)
	{
		auto tiDocStart = new TextIter;
		auto tiDocEnd = new TextIter;
		getBuffer.getStartIter(tiDocStart);
		getBuffer.getEndIter(tiDocEnd);
		getBuffer.removeTagByName("HiLiteSearchBack", tiDocStart, tiDocEnd);
		getBuffer.removeTagByName("HiLiteSearchFore", tiDocStart, tiDocEnd);

		auto tiStart = new TextIter;
		auto tiEnd = new TextIter;

		getBuffer().getIterAtLine(tiStart, LineNo);
		if(tiStart.getCharsInLine <= Start) return;
		tiStart.setLineOffset(Start);

		//getBuffer().getIterAtLineOffset(tiStart, LineNo, Start);
		getBuffer().getIterAtLineOffset(tiEnd, LineNo, End);


		getBuffer().applyTagByName("HiLiteSearchBack", tiStart, tiEnd);
		getBuffer().applyTagByName("HiLiteSearchFore", tiStart, tiEnd);
	}

	void HiliteAllSearchResults(int LineNo, int Start, int End)
	{
		auto tiStart = new TextIter;
		auto tiEnd = new TextIter;

		getBuffer().getIterAtLineOffset(tiStart, LineNo, Start);
		getBuffer().getIterAtLineOffset(tiEnd, LineNo, End);

		getBuffer().applyTagByName("HiLiteAllSearchBack", tiStart, tiEnd);
		getBuffer().applyTagByName("HiLiteAllSearchFore", tiStart, tiEnd);
	}

	void ClearHiliteAllSearchResults()
	{
		auto tiDocStart = new TextIter;
		auto tiDocEnd = new TextIter;
		getBuffer.getStartIter(tiDocStart);
		getBuffer.getEndIter(tiDocEnd);
		getBuffer.removeTagByName("HiLiteAllSearchBack", tiDocStart, tiDocEnd);
		getBuffer.removeTagByName("HiLiteAllSearchFore", tiDocStart, tiDocEnd);
	}


	void ReplaceWord(string newText)
	{
		auto tiStart = Cursor();
		if(!tiStart.insideWord())
		{
			InsertText(newText);
			return;
		}
		auto tiEnd = tiStart.copy();
		tiStart.backwardWordStarts(1);
		tiEnd.forwardWordEnds(1);
		getBuffer().beginUserAction();
		getBuffer().delet(tiStart, tiEnd);
		getBuffer().insert(tiStart, newText);
		getBuffer().endUserAction();
	}

	void ReplaceLine(string newText)
	{
		auto tiStart = Cursor();
		auto tiEnd = tiStart.copy();

		tiStart.setLineOffset(0);
		tiEnd.forwardToLineEnd();
		getBuffer.beginUserAction();
		getBuffer.delet(tiStart, tiEnd);
		getBuffer.insert(tiStart, newText);
		getBuffer.endUserAction();

	}
	void ReplaceSelection(string newText)
	{
		auto tiStart = new TextIter;
		auto tiEnd = new TextIter;

		getBuffer.getSelectionBounds(tiStart, tiEnd);

		if(tiStart !is null)
		{
			getBuffer.beginUserAction();
			getBuffer.delet(tiStart, tiEnd);
			getBuffer.insert(tiStart, newText);
			getBuffer.endUserAction();
		}
	}



	void ReplaceText(string NewText, int Line, int StartOffset, int EndOffset)
	{
		auto tiStart = new TextIter;
		auto tiEnd = new TextIter;

		getBuffer().getIterAtLineOffset(tiStart, Line, StartOffset);
		getBuffer().getIterAtLineOffset(tiEnd, Line, EndOffset);

		getBuffer.beginUserAction();
		getBuffer().delet(tiStart, tiEnd);
		getBuffer().insert(tiStart, NewText);
		getBuffer.endUserAction();

	}

	void CompleteSymbol(string TagText)
	{
		auto cursor = Cursor();

		dchar ch;
		while(cursor.backwardChar())
		{
			ch = cursor.getChar();
			if( (ch.isAlpha()) || (ch.isNumber()) || (ch == '_')) continue;
			cursor.forwardChar();
			break; //non identifier character so end of the road
		}
		getBuffer.beginUserAction();
		getBuffer().delet(cursor, Cursor());
		insertText(TagText);
		getBuffer.endUserAction();
	}

	TextIter Cursor()
	{
		auto ti = new TextIter;
		getBuffer().getIterAtMark(ti, getBuffer().getInsert());
		return ti.copy();
	}

	//returns the screen coordinates of the cursor textiter
	RECTANGLE GetCursorRectangle()
	{
		int x, y;
		int x2, y2;
		Rectangle strong, weak;

		getCursorLocations (Cursor(), strong,  weak);

		bufferToWindowCoords (TextWindowType.WIDGET, strong.x, strong.y, x, y);
		getWindow(TextWindowType.WIDGET).getOrigin(x2, y2);

		RECTANGLE RV;
		RV.x = x+x2;
		RV.y = y+y2;
		RV.xl = strong.width;
		RV.yl = strong.height;

		return RV;
	}

	void Undo()
	{
		mUndoManager.undo();
	}

}
