module document;

import ui;
import dcore;

import std.datetime;
import std.file;
import std.path;
import std.algorithm;
import std.string;
import std.uni;
import std.utf;
import std.conv;
import std.format;
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
import gtkc.gtk;
import gtkc.glib;


import gdk.Event;
import gdk.Keysyms;
import gdk.Rectangle;

import gobject.ObjectG;
import gobject.ParamSpec;
import gobject.Signals;
import gobject.Type;

import glib.Quark;


import gtkc.gobject;
import gtkc.gobject;
import gtkc.Loader;
import gtkc.paths;

public import gsv.SourceBuffer;
public import gsv.SourceCompletion;
public import gsv.SourceCompletionContext;
public import gsv.SourceCompletionInfo;
public import gsv.SourceCompletionItem;
public import gsv.SourceCompletionProposalIF;
public import gsv.SourceCompletionProvider;
public import gsv.SourceCompletionProviderIF;
public import gsv.SourceCompletionProviderT;
public import gsv.SourceCompletionWords;
public import gsv.SourceLanguage;
public import gsv.SourceLanguageManager;
public import gsv.SourceStyleSchemeManager;
public import gsv.SourceUndoManager;
public import gsv.SourceUndoManagerIF;
public import gsv.SourceView;
public import gsv.SourceMark;
public import gsv.SourceMarkAttributes;
public import gsv.SourceSearchContext;
public import gsv.SourceSearchSettings;
public import gsv.SourceGutter;
public import gsv.SourceGutterRendererText;
public import gsv.SourceGutterRenderer;
public import gsv.Utils;



import gtk.Widget;
import gtk.TextIter;
import gtk.TextBuffer;
import gtk.TextMark;

import gsv.SourceCompletionProviderIF;
import gsv.SourceCompletionProvider;
import gsv.SourceCompletionContext;
import gsv.SourceCompletionInfo;
import gsv.SourceCompletionProposalIF;
import gsv.SourceCompletionProviderT;
import gsv.SourceCompletionItem;

import gobject.ObjectG;
import gobject.Type;

import gtkc.gobject;
import gtkc.Loader;
import gtkc.paths;


import gsvc.gsv;
import gdk.Pixbuf;

import glib.ListG;



class DOCUMENT : SourceView, DOC_IF
{
    private:
    string              mFullName;


    bool                mVirgin;
    bool                mDeletedFile;

    Widget              mPageWidget;
    Box                 mTabWidget;
    Label               mTabLabel;
    SourceUndoManagerIF mUndoManager;

    bool                mFirstScroll;

    int                 mStaticHorizontalCursorPosition = -1;
    
    string[string]      mCodeCoverage;
    SourceGutterRendererText mGutterRendererText;

    SysTime mFileTimeStamp;

    string  mLastSelection;


    enum DIRECTION { UNKOWN, BACKWARD, FORWARD}

    void UpdateTabWidget()
    {
        if(Modified)
        {
            mTabLabel.setMarkup(`<span foreground="red" >[* `~TabLabel()~` *]</span>`);
        }
        else mTabLabel.setText(TabLabel());
        mTabWidget.setTooltipText(Name);
    }

    TextIter GetMovementIter(bool selection_bound, DIRECTION Direction)
    {
        auto buff = getBuffer();
        //TextIter ti;
        auto Lti = new TextIter;
        auto Rti = new TextIter;

        if(getBuffer().getSelectionBounds(Lti, Rti))
        {
            if(Direction == DIRECTION.BACKWARD) return Lti;
            if(Direction == DIRECTION.FORWARD ) return Rti;
        }
        return Cursor();
        /*
        if(selection_bound)
        {
            ti = new TextIter;
            buff.getIterAtMark(ti, buff.getMark("selection_bound"));
        }
        else
        {
            ti = Cursor();
        }
        return ti;*/
    }
    void SetMoveIter(TextIter ti, bool selection_bound)
    {
        string markname;
        auto Lti = new TextIter;
        auto Rti = new TextIter;


        if(selection_bound)
        {

            getBuffer().getSelectionBounds(Lti, Rti);
            if(ti.compare(Lti) < 0) markname = "insert";
            if(ti.compare(Rti) > 0) markname = "selection_bound";
            getBuffer().moveMarkByName(markname, ti);
            scrollMarkOnscreen(getBuffer().getMark(markname));
        }
        else
        {
            auto xtmp = new TextIter;
            getBuffer().getEndIter(xtmp);
            getBuffer().placeCursor(ti);
            scrollMarkOnscreen(getBuffer().getMark("insert"));
        }
    }


    public:


    this()
    {

        mDeletedFile = false; //if there was a file but now its gone. no file yet though so false

        ScrolledWindow ScrollWin = new ScrolledWindow(null, null);
        ScrollWin.setSizeRequest(-1,-1);

        ScrollWin.add(this);

        ScrollWin.setPolicy(GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);
        ScrollWin.showAll();

        auto tabXButton = new Button(StockID.NO, true);

        tabXButton.setSizeRequest(8, 8);
        tabXButton.addOnClicked(delegate void (Button x){DocMan.Close(this);});

        mTabWidget = new Box(Orientation.HORIZONTAL, 0);
        mTabLabel = new Label(TabLabel);
        mTabWidget.packStart(mTabLabel,1, 1, 0);
        mTabWidget.packStart(tabXButton, 0, 0,2);
        mTabWidget.showAll();

        mPageWidget = ScrollWin;

        addOnFocusOut(delegate bool(Event e, Widget me){DocMan.PageFocusOut.emit(this);return false;});
        addOnFocusIn(delegate bool(Event e, Widget me){DocMan.PageFocusIn.emit(this);return false;});

        addOnKeyPress(delegate bool(Event e, Widget me)
        {
            uint keyval;
            int rv;
            e.getKeyval(keyval);
            GdkModifierType state;
            e.getState(state);
            DocMan.DocumentKeyDown.emit(keyval, cast(uint)state);
            
            return DocMan.BlockDocumentKeyPress();

        },cast(GConnectFlags)0);

        bool MouseButtonCallBack(Event ev, Widget wgdt)
        {
            DocMan.MouseButton.emit(cast (void*)ev, this);
            return false;
        }

        addOnButtonPress(&MouseButtonCallBack);
        addOnButtonRelease(&MouseButtonCallBack);


        getBuffer().addOnInsertText(delegate void(TextIter ti, string text, int len, TextBuffer tb)
        {
            if(tb.getMark("dcomposer_saveMark") !is null){return;}

            auto saveMark = new TextMark("dcomposer_saveMark", 0);
            tb.addMark(saveMark, ti);
            DocMan.Insertion.emit(cast(void* )ti, text, len, cast(void*)tb);
            tb.getIterAtMark(ti, saveMark);
            tb.deleteMark(saveMark);
        }, cast(ConnectFlags)1);
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

            if(Project.TargetType == TARGET.EMPTY)CurrentPath(mFullName.dirName());
            return false;

        });
        getBuffer.getUndoManager.addOnCanUndoChanged(delegate void (SourceUndoManagerIF manager)
        {
            auto unAction = GetAction("ActUndo");
            unAction.setSensitive(manager.canUndo);
        });
        getBuffer.getUndoManager.addOnCanRedoChanged(delegate void (SourceUndoManagerIF manager)
        {
            auto reAction = GetAction("ActRedo");
            reAction.setSensitive(manager.canRedo);
        });



        getBuffer().createTag("HiLiteAllSearchBack", "background", Config.GetValue("document", "hiliteallsearchback", "white"));
        getBuffer().createTag("HiLiteAllSearchFore", "foreground", Config.GetValue("document", "hiliteallsearchfore", "black"));

        getBuffer().createTag("HiLiteSearchBack", "background", Config.GetValue("document", "hilitesearchback", "darkgreen"));
        getBuffer().createTag("HiLiteSearchFore", "foreground", Config.GetValue("document", "hilitesearchfore", "yellow"));

        mUndoManager = getBuffer.getUndoManager();

        mFirstScroll = true;
        GdkRectangle xrec;
        getVisibleRect(xrec);


        auto SrcMrkAttribs = new SourceMarkAttributes;
        SrcMrkAttribs.setPixbuf(new Pixbuf(SystemPath(Config.GetValue("docman", "nav_point_icon", "resources/pin-small.png"))));
        setMarkAttributes("NavPoints", SrcMrkAttribs, 1);


        Config.Changed.connect(&WatchConfigChange);
    }

    void WatchConfigChange(string Sec, string key)
    {
        if (Sec != "document") return;

        switch (key)
        {
            case "style_scheme" :
                string StyleID = Config.GetValue("document", "style_scheme", "mnml");
                getBuffer().setStyleScheme(SourceStyleSchemeManager.getDefault().getScheme(StyleID));
                return;
            default : Configure();
        }
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
        setSmartHomeEnd(SmartHomeEnd ? SmartHomeEndType.BEFORE : SmartHomeEndType.DISABLED);

        setHighlightCurrentLine(Config.GetValue("document", "hilite_current_line", false));
        setShowLineNumbers(Config.GetValue("document", "show_line_numbers",true));
        setShowRightMargin(Config.GetValue("document", "show_right_margin", true));
        getBuffer.setHighlightSyntax(Config.GetValue("document", "hilite_syntax", true));
        getBuffer.setHighlightMatchingBrackets(Config.GetValue("document", "match_brackets", true));
        setRightMarginPosition(Config.GetValue("document", "right_margin", 120));
        setIndentWidth(Config.GetValue("document", "indentation_width", 4));
        setTabWidth(Config.GetValue("document", "tab_width", 4));
        //setBorderWindowSize(GtkTextWindowType.BOTTOM, 5);
        setBorderWindowSize(GtkTextWindowType.BOTTOM, Config.GetValue("document", "bottom_border_size", 5));
        setPixelsBelowLines(Config.GetValue("document", "pixels_below_line", 1));
        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.GetValue("document", "font", "Monospace 13")));

        //adding gutter stuff for code coverage 
        auto gutter = getGutter(TextWindowType.LEFT);
        mGutterRendererText = new SourceGutterRendererText();

        
        mGutterRendererText.addOnQueryData(delegate void(TextIter tiStart, TextIter tiEnd, GtkSourceGutterRendererState state, SourceGutterRenderer sgr)
        {   
            //sourcemarks lead to infinite loop ... trying textmarks
            mGutterRendererText.setText("", "".length);
            auto listmarks = tiStart.getMarks();            
            if(listmarks is null) return;
            auto marks = listmarks.toArray!TextMark;
            if(marks.length < 1) return;
            string txtName;
            foreach(mark; marks)
            {
                txtName = mark.getName();
                if(txtName.startsWith("cov-"))break;
                txtName = "";
            }
            if(txtName.strip().length == 0) return;
            sgr.setVisible(true);
            
            int xlen, ylen;        
            string thefinalstring;
            auto sgrt = cast(SourceGutterRendererText)sgr;
            
            
            thefinalstring = "[" ~mCodeCoverage[txtName] ~ "]";
            sgrt.measure(thefinalstring, xlen, ylen);
            if(xlen > sgrt.getSize()) sgrt.setSize(xlen);
            sgrt.setText(thefinalstring, cast(int)thefinalstring.length);
        
            return;
        });
        mGutterRendererText.setVisible(false);
        mGutterRendererText.setAlignment(1.0, -1);
        gutter.insert(mGutterRendererText, 1);
        
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

    @property void  Name(string nuname)
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


    @property bool  Virgin()
    {
        return mVirgin;
    }
    @property void  Virgin(bool nuVirgin)
    {
        mVirgin = nuVirgin;
    }

    @property bool  Modified()
    {
        return cast(bool) getBuffer.getModified();
    }
    @property void  Modified(bool nuModified)
    {
        getBuffer().setModified(nuModified);
    }

    int     Line()
    {
        auto ti = Cursor();
        return ti.getLine();
    }

    int     Column()
    {
        auto ti = Cursor();
        return ti.getLineIndex();
    }
    string LineText()
    {
        auto tiStart = Cursor();
        auto tiEnd = tiStart.copy();
        tiStart.setLineOffset(0);
        tiEnd.forwardToLineEnd();
        return tiStart.getText(tiEnd);
    }

    bool RefreshCoverage()
    {
        scope(failure) return false;
        
        auto covFileName =  mFullName.tr("/", "-").setExtension("lst");
        if(!covFileName.exists())return false;
        auto covFile = std.stdio.File(covFileName);
        int idx;
        foreach(xline; covFile.byLineCopy())
        {
            if(xline.canFind("|"))
            {
                TextIter ti;
                TextMark sm;
                string covstr, waste;                
                getBuffer().getIterAtLine(ti, idx);                
                sm = getBuffer().createMark("cov-"~idx.to!string, ti, false);
                auto rv = formattedRead(xline, "%s| %s", &covstr, &waste);
                mCodeCoverage[sm.getName()] = covstr.strip();
            }
            idx++;
        }
        mGutterRendererText.setVisible(true);
        return true;
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
                        //break;
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


    /*string Word()
    {
        string rv;
        auto ti = Cursor();

        if(ti.insideWord())
        {
            auto tiEnd = ti.copy();
            TextIter tiCheckUnderScore;
            tiEnd.forwardWordEnds(1);
            ti.backwardWordStarts(1);
            rv = ti.getText(tiEnd);
        }
        return rv;
    }*/

    string Word(string AtMarkName )
    {
        string rv;
        bool foundStart;
        auto buff = getBuffer();

        auto ti = new TextIter;
        buff.getIterAtMark(ti, buff.getMark(AtMarkName));

        if(!(ti.insideWord() || ti.endsWord())) return rv;

        dchar lastChar = ti.getChar();
        dchar thisChar;

        //go to start
        while(ti.backwardChar())
        {
            thisChar = ti.getChar();

            if(lastChar.isWordStartChar() && !thisChar.isWordChar())
            {
                ti.forwardChar();
                foundStart = true;
                break;
            }
            if(!thisChar.isWordChar()) break;
            lastChar = thisChar;
        }
        if(foundStart == false) return rv;
        auto tiEnd = ti.copy();
        while(tiEnd.getChar().isWordChar())tiEnd.forwardChar();
        rv = ti.getText(tiEnd);
        return rv;

    }

    //fix this for unicode. D 'words' can take "universal alphas"
    int WordLength(int Partial)
    {
        int ctr;
        auto ti = Cursor;
        while(ti.backwardChar())
        {
            switch(ti.getChar())
            {
                case 'A' : .. case 'Z' :
                case 'a' : .. case 'z' :
                case '0' : .. case '9' :
                case '_' :
                case '.' : ctr++; break;
                default  : return ctr;
            }
        }
        return ctr;
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

    dchar GetChar()
    {
        return Cursor().getChar();
    }

    void GotoLine(int LineNo, int LinePos = 1)
    {
        mStaticHorizontalCursorPosition = -1;
        scope(exit)
        {
            mFirstScroll = false;
            SetBusyCursor(false);
            grabFocus();
        }

        if((LineNo < 1) && mFirstScroll)return;
        if(LinePos < 0) LinePos = 0;


        DocMan.PreCursorJump.emit(this, Line, Column);

        TextIter   insIter = new TextIter;
        GdkRectangle  insLoc, visLoc, nulLoc;

        int inside;

        auto tiline = new TextIter;
        getBuffer().getIterAtLine(tiline, LineNo);
        if(LinePos > tiline.getCharsInLine())LinePos = 0;
        getBuffer().getIterAtLineIndex(tiline, LineNo, LinePos);
        getBuffer().placeCursor(tiline);

        SetBusyCursor(true);

        do
        {
            ui.MainWindow.setSensitive(0);
            auto insMark = getBuffer().getInsert();
            getBuffer().getIterAtMark(insIter, insMark);
            getIterLocation(insIter, insLoc);
            getVisibleRect(visLoc);
            if(insLoc.width < 1)insLoc.width = 1;

            inside = gdk.Rectangle.intersect(&visLoc, &insLoc, nulLoc);
            scrollToMark(insMark, 0.0, true, 0.75, 0.25);
            Main.iteration();
            if( mFirstScroll && (insLoc.y == 0)) inside = 0;
        }while(!inside);
        ui.MainWindow.setSensitive(1);

        DocMan.CursorJump.emit(this, LineNo, Column);

    }

    string GetText(){return getBuffer.getText();}
    void SetText(string txt){getBuffer.setText(txt);}
    void InsertText(string txt)
    {
        getBuffer.beginUserAction();
        getBuffer.insertAtCursor(txt);
        getBuffer.endUserAction();
    }

    void    Save()
    {
        try
        {
            string savetext = getBuffer.getText();
            if(!savetext.endsWith("\n"))savetext ~= "\n";
            std.file.write(Name,savetext);
            Modified = false;
            mFileTimeStamp = timeLastModified(Name);
            mVirgin = false;
            mDeletedFile = false;
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
        if(mDeletedFile) return;
        SysTime currentTimeStamp;

        if(!Name.exists())
        {
            mDeletedFile = true;
            getBuffer.setModified(true);
            auto userChoice = ShowMessage("Warning", Name ~ "\nCan not be found on disk.\nYou are in danger of losing data.\nHow do you wish to proceed?",["Save", "Ignore", "Close"]);
            if(userChoice == 0)
            {
                Save();
                return;
            }
            if(userChoice == 1)
            {
                return;
            }
            if(userChoice == 2)
            {
                DocMan.Close(this);
                return;
            }
        }

        currentTimeStamp = timeLastModified(Name);

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
        auto BytesInLine = tiStart.getBytesInLine;
        if( (BytesInLine <= Start) || (BytesInLine <= End) ) return;

        //tiStart.setLineOffset(Start);
        //getBuffer().getIterAtLineOffset(tiEnd, LineNo, End);

        tiStart.setLineIndex(Start);
        getBuffer().getIterAtLineIndex(tiEnd, LineNo, End);

        getBuffer().applyTagByName("HiLiteSearchBack", tiStart, tiEnd);
        getBuffer().applyTagByName("HiLiteSearchFore", tiStart, tiEnd);
    }

    void HiliteAllSearchResults(int LineNo, int Start, int End)
    {
        auto tiStart = new TextIter;
        auto tiEnd = new TextIter;

        getBuffer.getIterAtLine(tiStart, LineNo);
        auto BytesInLine = tiStart.getBytesInLine();
        if( (BytesInLine <= Start) || (BytesInLine <=End) )return;
        getBuffer().getIterAtLineIndex(tiStart, LineNo, Start);
        getBuffer().getIterAtLineIndex(tiEnd, LineNo, End);

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
        if(tiStart.endsWord())
        {
            auto tiEnd = tiStart.copy();
            tiStart.backwardWordStarts(1);getBuffer().beginUserAction();
            getBuffer().delet(tiStart, tiEnd);
            getBuffer().insert(tiStart, newText);
            getBuffer().endUserAction();
            return;
        }
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
        GdkRectangle strong, weak;

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

    RECTANGLE GetMarkRectangle(string MarkName)
    {
        RECTANGLE RV;
        auto mark = getBuffer().getMark(MarkName);
        if(mark is null) return RV;

        auto ti = new TextIter;

        getBuffer().getIterAtMark(ti, mark);

        int x, y;
        int x2, y2;
        GdkRectangle strong, weak;

        getCursorLocations (ti, strong,  weak);
        bufferToWindowCoords (TextWindowType.WIDGET, strong.x, strong.y, x, y);
        getWindow(TextWindowType.WIDGET).getOrigin(x2, y2);
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

    int GetCursorByteIndex()
    {
        auto tiOffset = Cursor();
        int offsetnotbytes = tiOffset.getLineIndex();
        while(tiOffset.backwardLine())offsetnotbytes += tiOffset.getBytesInLine();
        return offsetnotbytes;
    }

    void ScrollUp(int Steps)
    {
        auto ScrAdj = getVadjustment();
        ScrAdj.setValue(ScrAdj.getValue() - ScrAdj.getMinimumIncrement());

    }

    void ScrollDown(int Steps)
    {
        auto ScrAdj = getVadjustment();
        ScrAdj.setValue(ScrAdj.getValue() + ScrAdj.getMinimumIncrement());
    }

    void ScrollCenterCursor()
    {
        scrollToMark(getBuffer().getMark("insert"), 0.0, true, .80, 0.5);
    }


    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    //movement


    bool MoveLeft(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        ti.backwardChars(Reps);

        SetMoveIter(ti, selection_bound);

        return true;
    }

    bool MoveRight(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        ti.forwardChars(Reps);

        SetMoveIter(ti, selection_bound);

        return true;
    }

    bool MoveUp(int Reps, bool selection_bound)
    {
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        int charOffset;
        if(mStaticHorizontalCursorPosition < 0)
        {
            mStaticHorizontalCursorPosition  = ti.getLineOffset();
        }

        charOffset = mStaticHorizontalCursorPosition;

        ti.backwardLines(Reps);

        auto linelength = ti.getCharsInLine();
        if(charOffset >= linelength) charOffset = linelength-1;
        if(charOffset < 1)charOffset = 0;
        ti.setLineOffset(charOffset);

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveDown(int Reps, bool selection_bound)
    {
        int charOffset;
        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        if(mStaticHorizontalCursorPosition < 0)
        {
            mStaticHorizontalCursorPosition = ti.getLineOffset();
        }
        charOffset = mStaticHorizontalCursorPosition;

        ti.forwardLines(Reps);

        auto linelength = ti.getCharsInLine();
        if(charOffset >= linelength) charOffset = linelength-1;
        if(charOffset < 1)charOffset = 0;
        ti.setLineOffset(charOffset);

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveLineStart(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        if( (Reps == 1) && (ti.getLineOffset() ==0) )
        {
            do
            {
                auto tichar = ti.getChar();
                if(tichar == '\n')break;
                if(tichar.isWhite()) continue;
                break;
            }while(ti.forwardChar());
        }
        else
        {
            ti.setLineOffset(0);
            if(Reps > 1) ti.backwardLines(Reps-1);
        }

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveLineEnd(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);


        if( (Reps == 1) && (ti.getChar() == '\n')) return false;
        foreach(ctr;0..Reps)ti.forwardToLineEnd();

        SetMoveIter(ti, selection_bound);
        return true;
    }
    bool MoveStart(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto buff = getBuffer();

        auto ti = new TextIter;
        getBuffer.getStartIter(ti);
        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveEnd(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto buff = getBuffer();
        auto ti = new TextIter;
        getBuffer.getEndIter(ti);
        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePageUp(int Reps, bool selection_bound)
    {
        GdkRectangle rect;

        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        getIterLocation(ti, rect);



        auto vadj = getVadjustment();
        double currentYpos = vadj.getValue();
        auto Pages = cast(int) (vadj.getPageIncrement() * Reps);
        vadj.setValue(currentYpos - Pages);

        auto ti_out = new TextIter;
        getIterAtLocation( ti_out, rect.x, rect.y - Pages);

        SetMoveIter(ti_out, selection_bound);
        return true;
    }

    bool MovePageDown(int Reps, bool selection_bound)
    {
        GdkRectangle rect;

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        getIterLocation(ti, rect);

        auto vadj = getVadjustment();
        double currentYpos = vadj.getValue();
        auto Pages = cast(int) (vadj.getPageIncrement() * Reps);
        vadj.setValue(currentYpos + Pages);

        auto ti_out = new TextIter;
        getIterAtLocation( ti_out, rect.x, rect.y + Pages);

        SetMoveIter(ti_out, selection_bound);
        return true;
    }

    bool MoveNextWordStart(int Reps, bool  selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        dchar ch;
        bool lastCharWasNotAWordChar;
        bool foundstart;

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);


        foreach(ctr;0..Reps)
        {
            ch = ti.getChar();
            lastCharWasNotAWordChar = !ch.isWordChar();
            while(ti.forwardChar())
            {
                ch = ti.getChar();
                if(ch.isWordStartChar() && lastCharWasNotAWordChar)
                {
                    foundstart = true;
                    break;
                }

                lastCharWasNotAWordChar = !ch.isWordChar();
            }
        }

        if(!foundstart) return false;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePrevWordStart(int Reps, bool  selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        dchar lastChar;
        dchar thisChar;
        bool foundstart;

        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        foreach(x;0..Reps)
        {
            lastChar = '0';
            while(ti.backwardChar())
            {
                thisChar = ti.getChar();

                if(lastChar.isWordStartChar() && !thisChar.isWordChar())
                {
                    ti.forwardChar();
                    foundstart = true;
                    break;
                }
                lastChar = thisChar;
            }
        }

        if(!foundstart) return false;
        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveNextWordEnd(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        dchar lastChar;
        dchar thisChar;
        bool foundend;

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        foreach(ctr; 0..Reps)
        {
            lastChar = ti.getChar();

            while(ti.forwardChar())
            {
                thisChar = ti.getChar();

                if(!thisChar.isWordChar() && lastChar.isWordChar())
                {
                    foundend = true;
                    break;
                }
                lastChar = thisChar;
            }
        }

        if(!foundend) return false;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePrevWordEnd(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        dchar lastChar;
        dchar thisChar;
        bool foundend;

        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        foreach(x;0..Reps)
        {
            lastChar = 'a';
            while(ti.backwardChar())
            {
                thisChar = ti.getChar();
                if(thisChar.isWordChar() && !lastChar.isWordChar())
                {
                    ti.forwardChar();
                    foundend = true;
                    break;
                }
                lastChar = thisChar;
            }

        }
        if(!foundend) return false;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveNextStatementStart(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        dchar tichar;

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        foreach(ctr; 0..Reps)
        {

            while(ti.forwardChar())
            {
                auto context_classes = getBuffer().getContextClassesAtIter(ti);
                if(context_classes.canFind("string")) continue;
                if(context_classes.canFind("comment")) continue;

                tichar = ti.getChar();

                if((tichar == ';') || (tichar == '{') || (tichar == '}') || (tichar == ':'))
                {
                    while(true)
                    {
                        context_classes = getBuffer().getContextClassesAtIter(ti);
                        if( (tichar == ';') || (tichar == '{') || (tichar == '}') || context_classes.canFind("comment") || tichar.isWhite()  || (tichar == ':'))
                        {
                            ti.forwardChar();
                            tichar = ti.getChar();
                            continue;
                        }
                        break;
                    }
                    break;
                }
            }
        }
        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveNextStatementEnd(int Reps, bool selection_bound)
    {
        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);


        TextIter Endti;

        foreach(i; 0.. Reps)
        {
            auto originalti = ti.copy();
            NextEnd:
            auto tichar = ti.getChar();

            while( !((tichar == ';') || (tichar == '{') || (tichar == '}') || (tichar == ':')))
            {
                if(!ti.forwardChar()) return false;
                if(IterInCommentBlock(ti) || IterInQuote(ti)) continue;
                tichar = ti.getChar();
            }
            Endti = ti.copy();
            Endti.forwardChar();
            //tichar == ; or { or }
            if( (tichar == ';') || (tichar == '}') || (tichar == ':'))ti.forwardChar();
            if(tichar == '{')
            {
                do { ti.backwardChar(); }while(ti.getChar().isWhite());
                ti.forwardChar();
            }
            if(ti.compare(originalti) <= 0)
            {
                ti = Endti.copy();
                goto NextEnd;
            }

        }
        SetMoveIter(ti, selection_bound);
        return true;
    }
    bool MovePrevStatementEnd(int Reps, bool selection_bound)
    {
        MovePrevStatementStart(2, selection_bound);
        MoveNextStatementEnd(1, selection_bound);
        return true;
    }

    bool MovePrevStatementStart(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        dchar tichar;
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        TextIter Endti;

        foreach(ctr; 0..Reps)
        {
            auto originalti = ti.copy();
            ExtraRun:
            while(ti.backwardChar())
            {
                auto context_classes = getBuffer().getContextClassesAtIter(ti);
                if(context_classes.canFind("string")) continue;
                if(context_classes.canFind("comment")) continue;

                tichar = ti.getChar();
                if( (tichar == ';') || (tichar == '{') || (tichar == '}') || (tichar == ':'))
                {
                    Endti = ti.copy();
                    do
                    {
                        ti.forwardChar();
                    }while( (ti.getChar().isWhite()) || (ti.getChar() == '}') || (IterInCommentBlock(ti)) || (IterInQuote(ti)));
                    break;
                }
            }

            if(ti.compare(originalti) >= 0)
            {
                if(Endti is null)return false;
                ti = Endti.copy();
                goto ExtraRun;
            }
        }
        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePrevScope(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        bool rv;

        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        while(ti.backwardChar())
        {
            if(ti.getChar() == '{')
            {
                rv = true;
                break;
            }

        }

        if(rv == false) return rv;

        SetMoveIter(ti, selection_bound);
        return true;
    }
    bool MoveNextScope(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        bool rv;

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);


        if(ti.getChar() == '{') ti.forwardChar();
        do
        {
            if(ti.getChar() == '{')
            {
                rv = true;
                break;
            }

        }while(ti.forwardChar());

        if(rv == false) return rv;


        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePrevBlockStart(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        bool rv;
        dstring openBlock = "({[";

        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        while(ti.backwardChar())
        {
            if(openBlock.canFind(ti.getChar()))
            {
                rv = true;
                break;
            }

        }

        if(rv == false) return rv;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveNextBlockStart(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        bool rv;
        dstring openBlock = "({[";

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        if(openBlock.canFind(ti.getChar())) ti.forwardChar();
        do
        {
            if(openBlock.canFind(ti.getChar()))
            {
                rv = true;
                break;
            }

        }while(ti.forwardChar());

        if(rv == false) return rv;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePrevBlockEnd(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        bool rv;
        dstring closeBlock = ")}]";

        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        while(ti.backwardChar())
        {
            if(closeBlock.canFind(ti.getChar()))
            {
                rv = true;
                break;
            }

        }

        if(rv == false) return rv;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveNextBlockEnd(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        bool rv;
        dstring openBlock = "({[";
        dstring closeBlock = ")}]";

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        if(closeBlock.canFind(ti.getChar())) ti.forwardChar();
        do
        {
            if(closeBlock.canFind(ti.getChar()))
            {
                rv = true;
                break;
            }

        }while(ti.forwardChar());

        if(rv == false) return rv;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveUpperScope(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        bool foundScope;
        dchar tichar;
        long ctr_scope;
        foreach(ctr_reps; 0..Reps)
        {
            foundScope = false;
            while (ti.backwardChar())
            {
                tichar = ti.getChar();
                if(tichar == '{')
                {
                    if(++ctr_scope > 0)
                    {
                        foundScope = true;
                        break;
                    }
                }
                if(tichar == '}') ctr_scope--;
            }
            if(!foundScope) return false;
        }

        SetMoveIter(ti, selection_bound);
        return true;
    }
    bool MoveLowerScope(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        bool foundScope;
        dchar tichar;
        long ctr_scope;
        foreach(ctr_reps; 0..Reps)
        {
            foundScope = false;
            while (ti.forwardChar())
            {
                tichar = ti.getChar();
                if(tichar == '{')
                {
                    if(++ctr_scope > 0)
                    {
                        foundScope = true;
                        break;
                    }
                }
                if(tichar == '}')break;
            }
            if(!foundScope) return false;
        }
        SetMoveIter(ti, selection_bound);
        return true;
    }


    bool MovePrevCurrentChar(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        auto theChar = ti.getChar();
        int Ctr;

        while(ti.backwardChar())
        {
            if(theChar == ti.getChar()) Ctr++;
            if(Ctr >= Reps)break;
        }

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveNextCurrentChar(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        int Ctr;
        auto theChar = ti.getChar();

        while(ti.forwardChar())
        {
            if(theChar == ti.getChar())Ctr++;
            if(Ctr >= Reps)break;
        }

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveNextStringBoundary(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        bool origOnString = getBuffer().iterHasContextClass(ti, "string");
        bool foundBoundary;

        foreach(i; 0 .. Reps)
        {
            while(ti.forwardChar())
            {
                if(getBuffer().iterHasContextClass(ti,"string") != origOnString)
                {
                    foundBoundary = true;
                    break;
                }
            }
        }
        if(!foundBoundary)return false;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePrevStringBoundary(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);
        auto tistart = ti.copy();

        bool origOnString = getBuffer().iterHasContextClass(ti, "string");
        if(tistart.backwardChar())
        {
            if(getBuffer().iterHasContextClass(tistart, "string") != origOnString)
            {
                origOnString = !origOnString;
            }
        }
            
        bool foundBoundary;

        foreach(i; 0 .. Reps)
        {
            while(ti.backwardChar())
            {
                if(getBuffer().iterHasContextClass(ti,"string") != origOnString)
                {   
                    ti.forwardChar();
                    foundBoundary = true;
                    break;
                }
            }
        }
        if(!foundBoundary)return false;

        SetMoveIter(ti, selection_bound);
        return true;
    }


    bool MoveNextCommentBoundary(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        bool origOnString = getBuffer().iterHasContextClass(ti, "comment");
        bool foundBoundary;

        foreach(i; 0 .. Reps)
        {
            while(ti.forwardChar())
            {
                if(getBuffer().iterHasContextClass(ti,"comment") != origOnString)
                {
                    foundBoundary = true;
                    break;
                }
            }
        }
        if(!foundBoundary)return false;

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePrevCommentBoundary(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);
        auto tistart = ti.copy();

        bool origOnComment = getBuffer().iterHasContextClass(ti, "comment");
        bool foundBoundary;
        
        if(tistart.backwardChar())
        {
            if(getBuffer().iterHasContextClass(tistart, "comment") != origOnComment)
            {
                origOnComment = !origOnComment;
            }
        }
                

        foreach(i; 0 .. Reps)
        {
            while(ti.backwardChar())
            {
                if(getBuffer().iterHasContextClass(ti,"comment") != origOnComment)
                {
                    ti.forwardChar();
                    foundBoundary = true;
                    break;
                }
            }
        }
        if(!foundBoundary)return false;

        SetMoveIter(ti, selection_bound);
        return true;
    }


    bool IterInCommentBlock(TextIter ti)
    {
        if(ti is null) return false;

        auto context_classes = getBuffer().getContextClassesAtIter(ti);
        if(context_classes.canFind("comment"))return true;
        return false;
    }
    bool IterInQuote(TextIter ti)
    {
        if(ti is null) return false;
        auto context_classes = getBuffer().getContextClassesAtIter(ti);
        if(context_classes.canFind("string"))return true;
        return false;
    }

    bool IterInParens(TextIter ti)
    {
        if(ti is null) return false;

        auto buff = getBuffer();
        auto startti = new TextIter;
        buff.getStartIter(startti);


        bool CheckInside(immutable dchar OpenLeft, immutable dchar CloseRight)
        {
            long balanced;
            while (startti.forwardChar())
            {
                if(startti.equal(ti))break;

                auto context_classes = buff.getContextClassesAtIter(startti);
                if(context_classes.canFind("string")) continue;
                if(context_classes.canFind("comment")) continue;

                if(startti.getChar() == OpenLeft) balanced++;
                if(startti.getChar() == CloseRight) balanced--;

            }
            if(balanced > 0) return true;
            return false;
        }

        if(CheckInside('(',')')) return true;
        return false;

    }

    bool IterInBlock(TextIter ti, immutable dchar OpenBlock = '{', immutable dchar CloseBlock = '}')
    {
        if(ti is null) return false;

        auto buff = getBuffer();
        auto startti = new TextIter;
        buff.getStartIter(startti);


        bool CheckInside(immutable dchar OpenLeft, immutable dchar CloseRight)
        {
            long balanced;
            while (startti.forwardChar())
            {
                if(startti.equal(ti))break;

                auto context_classes = buff.getContextClassesAtIter(startti);
                if(context_classes.canFind("string")) continue;
                if(context_classes.canFind("comment")) continue;

                if(startti.getChar() == OpenLeft) balanced++;
                if(startti.getChar() == CloseRight) balanced--;

            }
            if(balanced > 0) return true;
            return false;
        }

        if(CheckInside(OpenBlock,CloseBlock)) return true;
        return false;

    }

    bool IndentLines(int Reps)
    {
        mStaticHorizontalCursorPosition = -1;
        auto startTi = new TextIter;
        auto endTi = new TextIter;
        auto buff = getBuffer();

        buff.beginUserAction();
        scope(exit)buff.endUserAction();
        string indentSpaces;

        auto x = getIndentWidth() * Reps;

        foreach(ctr;0..x)indentSpaces ~= " ";

        buff.getSelectionBounds(startTi, endTi);
        startTi.setLineOffset(0);
        endTi.forwardLine();

        auto endMark = buff.createMark("endmark", endTi, true);
        auto startMark = buff.createMark("currentmark", startTi, true);

        //setmarks on each line
        do
        {
            buff.moveMark(endMark, endTi);
            buff.moveMark(startMark, startTi);

            buff.insert(startTi, indentSpaces);

            buff.getIterAtMark(startTi, startMark);
            buff.getIterAtMark(endTi, endMark);

            startTi.forwardLine();
        }while(startTi.compare(endTi) != 0);

        buff.deleteMarkByName("currentmark");
        buff.deleteMarkByName("endmark");
        return true;
    }

    bool UnIndentLines(int Reps)
    {
        mStaticHorizontalCursorPosition = -1;
        auto startTi = new TextIter;
        auto endTi = new TextIter;
        auto buff = getBuffer();

        buff.beginUserAction();
        scope(exit)buff.endUserAction();

        string indentSpaces;


        buff.getSelectionBounds(startTi, endTi);
        startTi.setLineOffset(0);
        endTi.forwardLine();

        auto endMark = buff.createMark("endmark", endTi, true);
        auto startMark = buff.createMark("currentmark", startTi, true);

        //setmarks on each line
        do
        {
            buff.moveMark(endMark, endTi);
            buff.moveMark(startMark, startTi);

            //get indent (not line) text and find current indent 'size'
            auto currIndTi = startTi.copy();
            do
            {
                auto tmpChar = currIndTi.getChar();
                if(tmpChar == '\n')break;
                if(tmpChar.isWhite())continue;
                if(tmpChar.isSpace())continue;
                //currIndTi.backwardChar();
                break;
            } while(currIndTi.forwardChar());
            auto text = buff.getSlice(startTi, currIndTi, true);
            long col = cast(long)text.column(getTabWidth);
            //if(col == 0) return false;

            col = col - (getTabWidth() * Reps);
            if(col < 1) col = 0;
            //silly way to create new indentation
            indentSpaces.length = 0;
            foreach(ctr; 0 .. col)indentSpaces ~= " ";


            //chop off current indents
            buff.delet(startTi, currIndTi);

            //insert new indents ... startTi is still valid as per gtk docs
            buff.insert(startTi, indentSpaces);

            buff.getIterAtMark(startTi, startMark);
            buff.getIterAtMark(endTi, endMark);

            startTi.forwardLine();
        }while(startTi.compare(endTi) != 0);

        buff.deleteMarkByName("currentmark");
        buff.deleteMarkByName("endmark");
        return true;
    }


    bool MoveBracketMatch(bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        dstring openMatches = "({[<";
        dstring closeMatches =")}]>";
        auto ti = GetMovementIter(selection_bound, DIRECTION.UNKOWN);

        dchar toMatch = ti.getChar();
        bool inclusive;
        int ctr;

        long indx = openMatches.indexOf(toMatch);
        if(indx < 0)
        {
            ti.backwardChar();
            toMatch = ti.getChar();
            ti.forwardChar();
            indx = openMatches.indexOf(toMatch);
            inclusive = false;
        }
        else inclusive = true;
        if(indx > -1)
        {
            //search forward
            while(ti.forwardChar())
            {
                auto context_classes = getBuffer().getContextClassesAtIter(ti);
                if(context_classes.canFind("string"))continue;
                if(context_classes.canFind("comment"))continue;
                if(ti.getChar() == openMatches[indx]) ctr++;
                if(ti.getChar() == closeMatches[indx]) ctr--;

                if(ctr < 0)
                {
                    if(inclusive)ti.forwardChar();
                    SetMoveIter(ti, selection_bound);
                    return true;
                }
            }
            return false;
        }
        toMatch = ti.getChar();
        indx = closeMatches.indexOf(toMatch);
        if(indx < 0)
        {
            ti.backwardChar();
            toMatch = ti.getChar();
            indx = closeMatches.indexOf(toMatch);
            inclusive = true;
        }
        else inclusive = false;
        if(indx > -1)
        {
            //search backward
            while(ti.backwardChar())
            {
                auto context_classes = getBuffer().getContextClassesAtIter(ti);
                if(context_classes.canFind("string"))continue;
                if(context_classes.canFind("comment"))continue;
                if(ti.getChar() == openMatches[indx])ctr--;
                if(ti.getChar() == closeMatches[indx])ctr++;

                if(ctr < 0)
                {
                    if(!inclusive)ti.forwardChar();
                    SetMoveIter(ti, selection_bound);
                    return true;
                }
            }
            return false;
        }
        return false;
    }


    bool MovePrevSymbol(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        bool foundSymbol;
        auto buff = getBuffer();
        TextIter ti;
        TextIter tiOrig;

        tiOrig = Cursor();

        ti = new TextIter;
        buff.getIterAtMark(ti, buff.getMark("selection_bound"));


        auto text = Word("selection_bound");
        if(text.length == 0) return false;


        while(MovePrevWordStart(1, selection_bound))
        {
            buff.getIterAtMark(ti, buff.getMark("selection_bound"));
            if(text == Word("selection_bound"))
            {
                foundSymbol = true;
                break;
            }
        }
        if(foundSymbol == false)
        {
            buff.placeCursor(tiOrig);
            scrollMarkOnscreen(buff.getMark("insert"));
            return false;
        }

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MoveNextSymbol(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        bool foundSymbol;
        auto buff = getBuffer();
        TextIter ti;
        TextIter tiOrig;

        tiOrig = Cursor();

        ti = new TextIter;
        buff.getIterAtMark(ti, buff.getMark("selection_bound"));


        auto text = Word("selection_bound");
        if(text.length == 0) return false;


        while(MoveNextWordStart(1, selection_bound))
        {
            buff.getIterAtMark(ti, buff.getMark("selection_bound"));
            if(text == Word("selection_bound"))
            {
                foundSymbol = true;
                break;
            }
        }
        if(!foundSymbol)
        {
            buff.placeCursor(tiOrig);
            scrollMarkOnscreen(buff.getMark("insert"));
            return false;
        }

        SetMoveIter(ti, selection_bound);
        return true;
    }

    bool MovePrevParameterStart(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;
        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);

        if(!IterInParens(ti)) return false;

        auto tiOpen = ti.copy();
        bool IsIterAtParameterStart = true;

        SkipToOpenParen(tiOpen);
        auto tichar = ti.getChar();

        foreach(i; 0..Reps)
        {
            if(tichar == ',')tichar = '\0';
            while(tichar != ',')
            {
                ti.backwardChar();
                if(ti.equal(tiOpen))break;
                auto context_classes = getBuffer().getContextClassesAtIter(ti);
                if(context_classes.canFind("string"))continue;
                if(context_classes.canFind("comment"))continue;

                tichar = ti.getChar();
                if(tichar == ')')
                {
                    SkipToOpenParen(ti);
                    tichar = ti.getChar();
                }
                if((IsIterAtParameterStart) && (tichar == ',')) tichar = '\0';
                IsIterAtParameterStart = false;
            }
            ti.forwardChar();
        }
        SetMoveIter(ti, selection_bound);
        return true;

    }
    bool MovePrevParameterEnd(int Reps, bool selection_bound)
    {
        foreach(i; 0..Reps)
        {
            MovePrevParameterStart(2, selection_bound);
            MoveNextParameterEnd(1, selection_bound);
        }
        return true;
    }
    bool MoveNextParameterEnd(int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        if(!IterInParens(ti)) return false;

        auto tiClose = ti.copy();

        SkipToCloseParen(tiClose);
        auto tichar = ti.getChar();
        foreach(i; 0..Reps)
        {
            if(tichar == ',') tichar = '_';
            while(!tiClose.equal(ti))
            {
                if(ti.forwardChar() == 0)break;
                tichar = ti.getChar();
                auto context_classes = getBuffer().getContextClassesAtIter(ti);
                if(context_classes.canFind("string"))
                {
                    tichar = '_';
                    continue;
                }
                if(context_classes.canFind("comment"))
                {
                    tichar = '_';
                    continue;
                }

                if(tichar == '(')
                {
                    SkipToCloseParen(ti);
                    continue;
                }
                if(tichar == ',')break;

            }
        }

        SetMoveIter(ti, selection_bound);
        return true;
    }
    bool MoveNextParameterStart(int Reps, bool selection_bound)
    {
        foreach(i; 0..Reps)
        {
            MoveNextParameterEnd(2, selection_bound);
            MovePrevParameterStart(1,selection_bound);
        }
        return true;
    }

    void SkipToOpenParen(ref TextIter ti)
    {
        auto buff = getBuffer();
        int ctr;
        if(ti.getChar() == ')')ctr = 1;
        if(ti.getChar() == '(')ctr = -1;

        do
        {
            auto context_classes = buff.getContextClassesAtIter(ti);
            if(context_classes.canFind("string"))continue;
            if(context_classes.canFind("comment"))continue;
            if(ti.getChar() == '(')ctr++;
            if(ti.getChar() == ')')ctr--;
            if(ctr > 0) break;
        }while(ti.backwardChar());
    }

    void SkipToCloseParen(ref TextIter ti)
    {
        auto buff = getBuffer();
        int ctr;
        if(ti.getChar() == '(') ctr = -1;
        do
        {
            auto context_classes = buff.getContextClassesAtIter(ti);
            if(context_classes.canFind("string"))continue;
            if(context_classes.canFind("comment"))continue;
            if(ti.getChar() == '(')ctr++;
            if(ti.getChar() == ')')ctr--;
            if( (ctr < 0) && (ti.getChar() == ')')) break;
        }while(ti.forwardChar());
    }


    void MoveObjectNext(TEXT_OBJECT Object, int Reps, bool selection_bound)
    {
        mStaticHorizontalCursorPosition = -1;

        auto ti = GetMovementIter(selection_bound, DIRECTION.FORWARD);

        auto searchSettings = new SourceSearchSettings();
        auto searchContext = new SourceSearchContext(getBuffer, searchSettings);

        searchContext.setHighlight(false);
        searchSettings.setCaseSensitive(true);
        searchSettings.setRegexEnabled(true);
        searchSettings.setWrapAround(false);
        searchSettings.setSearchText(Object.mRegex);

        TextIter StartTi, EndTi;
        bool result_forward;

        foreach(ctr; 0..Reps)
        {
            if(searchContext.forward(ti, StartTi, EndTi))
            {
                if(ti.equal(StartTi))
                {
                    if(ti.forwardChar())
                    {
                         if(searchContext.forward(ti, StartTi, EndTi))
                        {
                            ti = StartTi.copy();
                        }
                    }
                }
                else
                {
                    ti = StartTi.copy();
                }
            }
        }
        //if(!result_forward) return; //otherwise StartTi and/or EndTi will be "bad" and cause a seg fault in SetMoveIter.
            
        SetMoveIter(ti, selection_bound);
        
        //if(Place == TEXT_OBJECT_MARK.START)SetMoveIter(StartTi, selection_bound);
        //if(Place == TEXT_OBJECT_MARK.END) SetMoveIter(EndTi,selection_bound);
        //if(Place == TEXT_OBJECT_MARK.CURSOR) SetMoveIter(StartTi, false);

    }
    void MoveObjectPrev(TEXT_OBJECT Object, int Reps, bool selection_bound)
    {

        mStaticHorizontalCursorPosition = -1;

        auto ti = GetMovementIter(selection_bound, DIRECTION.BACKWARD);


        auto searchContext = new SourceSearchContext(getBuffer, null);

        auto searchSettings = searchContext.getSettings();
        searchContext.setHighlight(false);
        searchSettings.setCaseSensitive(true);
        searchSettings.setRegexEnabled(true);
        searchSettings.setWrapAround(false);

        searchSettings.setSearchText(Object.mRegex);
        
        TextIter StartTi, EndTi;
        bool result_forward;

        foreach(ctr; 0..Reps)
        {
            if(searchContext.backward(ti, StartTi, EndTi))
            {
                if(ti.equal(StartTi))
                {
                    if(ti.backwardChar())
                    {
                         if(searchContext.backward(ti, StartTi, EndTi))
                        {
                            ti = StartTi.copy();
                        }
                    }
                }
                else
                {
                    ti = StartTi.copy();
                }
            }
        }            
        SetMoveIter(ti, selection_bound);

    }


}








