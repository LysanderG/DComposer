module document;

import std.algorithm;
import std.conv;
import std.datetime;
import std.file;
import std.format;
import std.path;
import std.uni;
import std.utf;

import ui;
import qore;
import docman;
import text_objects;
import completion_words;//wordstest
import ui_contextmenu;
import ui_search;


import gsv.SourceBuffer;
import gsv.SourceCompletion;
import gsv.SourceFile;
import gsv.SourceFileLoader;
import gsv.SourceFileSaver;
import gsv.SourceLanguage;
import gsv.SourceLanguageManager;
import gsv.SourceMark;
import gsv.SourceSearchContext;
import gsv.SourceSearchSettings;
import gsv.SourceStyleSchemeManager;
import gsv.SourceUndoManagerIF;
import gsv.SourceView;
import gsv.Tag;


import pango.PgFontDescription;



class DOCUMENT : SourceView, DOC_IF
{
    alias       buff = getBuffer;
private:
    string      mFullPathName;
    bool        mVirgin;
    Box         mTabWidget;
    Label       mTabLabel;
    SourceFile  mFile;
    SysTime     mFileTimeStamp;
    
    SourceSearchContext     mSearchContext;
    SourceCompletion        mCompletion;        
    
    void WatchConfigChange(string section, string key)
    {
        if(section == "document") Reconfigure();
    }
        

public:
    this()
    {
        super();
    }
    string FullName(){return mFullPathName;}
    string Name(){return baseName(mFullPathName);}
    void   Name(string nuFileName)
    {
        mFullPathName = nuFileName;
        UpdateTabWidget();
        Transmit.DocStatusLine.emit(GetStatusLine());
        Transmit.DocEvent.emit(this, DOC_EVENT.NAME, mFullPathName);        
    }
    
    bool Virgin(){return mVirgin;}
    void VirginReset()
    {
        mVirgin = true;
        Transmit.DocEvent.emit(this, DOC_EVENT.REVIRGINED, "true");
    }
    
    SysTime TimeStamp(){return mFileTimeStamp;}
    void TimeStamp(SysTime nutime){mFileTimeStamp = nutime;}
    
    bool Modified(){return getBuffer.getModified();}
    
    
    void Reconfigure()
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
        setShowLineMarks(Config.GetValue("document", "show_line_marks", true));
        setShowRightMargin(Config.GetValue("document", "show_right_margin", true));
        getBuffer.setHighlightSyntax(Config.GetValue("document", "hilite_syntax", true));
        getBuffer.setHighlightMatchingBrackets(Config.GetValue("document", "match_brackets", true));
        setRightMarginPosition(Config.GetValue("document", "right_margin", 120));
        setIndentWidth(Config.GetValue("document", "indent_width", 4));
        setTabWidth(Config.GetValue("document", "tab_width" , 4));
        setShowLineMarks(Config.GetValue("document", "show_line_marks", true));
        setSmartBackspace(Config.GetValue("document", "smart_backspace", true));
        setBorderWindowSize(GtkTextWindowType.BOTTOM, Config.GetValue("document", "bottom_border_size", 5));
        setPixelsBelowLines(Config.GetValue("document", "pixels_below_line", 1));
        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.GetValue("document", "font", "Monospace 13")));
        setWrapMode(Config.GetValue("document","wrap_mode", WrapMode.NONE));
        setMonospace(true); 
        Transmit.DocEvent.emit(this, DOC_EVENT.RECONFIGURED, "");  
    }
    
    void Init(string nuFileName = null)
    {
        mVirgin = true;
        mTabWidget = new Box(Orientation.HORIZONTAL,0);
        mTabLabel = new Label(mFullPathName, false);        
        
        mSearchContext = new SourceSearchContext(buff, null);
                
        //use an Image because buttons are too damn large. Who wants a giant sized tab row.
        //auto tabXButton = new Image(Config.GetValue("document","close_button_icon", "resources/cross-circle-frame.png"));
        auto tabXButton = new Image(Config.GetResource("document","close_button_icon","resources", "cross-circle-frame.png"));
        
        tabXButton.setSizeRequest(8, 8);
        tabXButton.addEvents(EventMask.BUTTON_RELEASE_MASK);
        auto stupidEventBox = new EventBox();
        stupidEventBox.add(tabXButton);
        stupidEventBox.setAboveChild(false);
        stupidEventBox.setVisibleWindow(false);
        stupidEventBox.setEvents(EventMask.BUTTON_RELEASE_MASK);
        stupidEventBox.addOnButtonRelease(delegate bool(Event ev, Widget w)
        {
            if(ev.button.button != GDK_BUTTON_PRIMARY) return false;
            Transmit.DocClose.emit(this);
            return true;
        });
        
        mTabWidget.packStart(mTabLabel,false,false,0);
        mTabWidget.packStart(stupidEventBox,false,false,2);
        mTabWidget.showAll();
        getBuffer().addOnModifiedChanged(delegate void (TextBuffer Buf){UpdateTabWidget();});
        if(nuFileName is null)Name = NameMaker();
        else Name = nuFileName;        Config.Reconfigure.connect(&Reconfigure);
        Config.Changed.connect(&WatchConfigChange);
        Reconfigure();
        setBackgroundPattern(BackgroundPatternType.GRID);
        
        addOnPopulatePopup(delegate void(Widget w, TextView self)
        {
            Menu cMenu = cast(Menu)w;
            foreach(item; GetContextItems())
            {
                cMenu.append(item);
            }            
            w.showAll();           
            
        });
        
        addOnKeyPress(delegate bool(Event keyEvent, Widget self)
        {
            uint keyvalue;
            keyEvent.getKeyval(keyvalue);
            if (keyvalue == Keysyms.GDK_bar)
            {
                //mTextObject["word"].EndPrev(this);
                mTextObject["line"].EndNext(this);
                return true;
            }
            return false;
        });
        
        mCompletion = getCompletion();//wordstest
        mCompletion.addProvider(Words.mWords);
        
        docman.AddDoc(this);
        
        Transmit.SigUpdateAppPreferencesOptions.connect(&Reconfigure);
       
    }
    void Load(string fileName)
    {
        Init(fileName);
        if(!fileName.exists)
        {
            Log.Entry("Document " ~ fileName ~ " does not exist, continuing as empty document.");
            return;
        }
        mFileTimeStamp = timeLastModified(fileName);
        mVirgin = false;
        mFile = new SourceFile();
        mFile.setLocation(FileIF.parseName(fileName));
        auto dfileloader = new SourceFileLoader(getBuffer, mFile);
        dfileloader.loadAsync(G_PRIORITY_DEFAULT, null, null, null, null, &FileLoaded, cast(void*)dfileloader);
        Name =  fileName;
    }

    void Save()
    {
        try
        {
            string savetext = getBuffer.getText();
            if(!savetext.endsWith("\n"))savetext ~= "\n";
            std.file.write(mFullPathName,savetext);
            mFileTimeStamp = timeLastModified(mFullPathName);
            getBuffer.setModified = false;
            mVirgin = false;
            
        }
        catch(FileException fe)
        {
            Log.Entry(fe.msg,"Error");
            //ui.ShowMessage("File Error", fe.msg);
        }

    }
    void SaveAs(string newFileName)
    {
        if(mFile is null) mFile = new SourceFile();
        mFile.setLocation(FileIF.parseName(newFileName));
        Name = newFileName;
        Save();
    }
    void Close()
    {
        dwrite("aaaaggggggghhhhhh");
    }
    void SaveCopy(string copyFileName)
    {
    }

    void* PageWidget()
    {
        Widget pops = this.getParent();
        return cast(void*) pops;
    }
    void* TabWidget(){return cast(void*)mTabWidget;}
    void UpdateTabWidget()
    {
        if(mTabLabel is null) return;
        if(getBuffer.getModified())
        {
            mTabLabel.setMarkup(`<span foreground="red" >[* `~ Name ~` *]</span>`);
        }
        else mTabLabel.setText(Name);
        mTabWidget.setTooltipText(FullName);
    }
    
    string GetStatusLine()
    {
        string rv;
        string fore_color = "white";
        string back_color = "black";
        string mod_fore_color = "yellow";
        string mod_back_color = "red";
        string fore = (Modified)? mod_fore_color:fore_color;
        string back = "black";
        string docname = format(`<span foreground="%s">%s</span>`,fore,Name());
        string virgin = (Virgin)? "(virgin)": "(filed)";
        int col = Cursor.getLineOffset();
        int line = Cursor.getLine() + 1;
        int totalLines = getBuffer.getLineCount();
        string cursorpos = format("%s[%3s:%3s]",col, line, totalLines);

        
        
        rv = format(`<span background="%s">%-100s %s %s</span>`,
            back,docname, cursorpos, virgin);
        
        return rv;
    }
    
    void Goto(int line, int col, bool focus)
    {
        TextIter ti;
        buff.getIterAtLineOffset(ti, line, col);
        buff.placeCursor(ti);
        //scrollToIter(ti, 0.75, true, 0, false);
        if(focus)grabFocus();
        scrollToIter(ti, .25, false, .25, false);
        
    }    
    TextIter Cursor()
    {
        //auto ti = new TextIter;
        TextIter ti;
        auto x = getBuffer();
        x.getIterAtMark(ti, x.getInsert());
        return ti;
    }
    
    SourceSearchContext GetSearchContext()
    {
        return mSearchContext;
    }
    
    bool FindForward(string regexNeedle)
    {
        bool rv;

        SourceSearchSettings sSettings = mSearchContext.getSettings();
        sSettings.setRegexEnabled(true);
        sSettings.setWrapAround(true);
        sSettings.setSearchText(regexNeedle);
        
        TextIter ti, tiStart, tiEnd;
        ti = new TextIter;
        tiStart = new TextIter;
        tiEnd = new TextIter;
        bool wrapped;
        buff.getIterAtMark(ti, buff.getMark("insert"));
        
        rv = mSearchContext.forward(ti, tiStart, tiEnd, wrapped);
        if(rv == false) return rv;        
        if(tiStart is null)return rv;//end of file ??
        if(ti.compare(tiStart) == 0)
        {
            ti = tiEnd.copy();
            rv = mSearchContext.forward(ti, tiStart,tiEnd, wrapped);
            if(rv == false) return rv;
        }
        
        buff.placeCursor(tiStart);
        scrollToIter(tiStart, .25, true, .25, .25);
        grabFocus();
        mSearchContext.setHighlight(true);
        return rv;
    }
    bool FindBackward(string regexNeedle)
    {
        bool rv;

        SourceSearchSettings sSettings = mSearchContext.getSettings();
        sSettings.setRegexEnabled(true);
        sSettings.setWrapAround(true);
        sSettings.setSearchText(regexNeedle);
        
        TextIter ti, tiStart, tiEnd;
        ti = new TextIter;
        tiStart = new TextIter;
        tiEnd = new TextIter;
        bool wrapped;
        buff.getIterAtMark(ti, buff.getMark("insert"));
        
        rv = mSearchContext.backward(ti, tiStart, tiEnd, wrapped);
        if(rv == false) return rv;        
        if(tiStart is null)return rv;//end of file ??
        if(ti.compare(tiEnd) == 0)
        {
            ti = tiStart.copy();
            rv = mSearchContext.forward(ti, tiStart,tiEnd, wrapped);
            if(rv == false) return rv;
        }
        
        buff.placeCursor(tiStart);
        scrollToIter(tiStart, .1, false, .5, .5);
        grabFocus();
        mSearchContext.setHighlight(true);
        return rv;
    }
    
    bool Replace(string regexNeedle, string replacementText)
    {
        bool rv;
        SourceSearchSettings sSettings = mSearchContext.getSettings();
        sSettings.setRegexEnabled(true);
        sSettings.setWrapAround(true);
        sSettings.setSearchText(regexNeedle);
        
        TextIter ti, tiStart, tiEnd;
        ti = new TextIter;
        tiStart = new TextIter;
        tiEnd = new TextIter;
        bool wrapped;
        buff.getIterAtMark(ti, buff.getMark("insert"));
        
        rv = mSearchContext.forward(ti, tiStart, tiEnd, wrapped);
        if(rv == false) return rv;        
        
        
        buff.placeCursor(tiStart);
        scrollToIter(tiStart, .25, true, .25, .25);
        rv = mSearchContext.replace(tiStart, tiEnd, replacementText, replacementText.length.to!int);
        
        
        grabFocus();
        mSearchContext.setHighlight(true);
        return rv;
        
    }
    void ReplaceAll(string replacementText)
    {
        mSearchContext.replaceAll(replacementText, replacementText.length.to!int);
    }
    
    void SetSearchHilite(bool state)
    {
        //SourceSearchContext sContext = new SourceSearchContext(buff,null);
        mSearchContext.setHighlight(state);
    }
    bool GetSearchHilite()
    {
        return mSearchContext.getHighlight();
    }

    string Text()
    {
        return getBuffer.getText();
    }
    void Text(string nuText)
    {
        getBuffer.setText(nuText);
    }
    
    string Selection()
    {
        string rv;
        
        if(!buff.getHasSelection()) return rv;
        TextIter tiStart, tiEnd;
        buff.getSelectionBounds(tiStart, tiEnd);
        
        rv = buff.getText(tiStart, tiEnd, true);
        return rv;
    }
    
    ///Returns current Identifier at cursor or an empty string
    string Identifier(string markName)
    {
        string rv;
        
        TextIter Initial = new TextIter;
        TextIter Start;
        TextIter End;
        auto buff = getBuffer();
        
        buff.getIterAtMark(Initial, buff.getMark(markName));
        if( (!Initial.insideWord()) || (Initial.endsWord)) return rv; //empty        
        Start = Initial.copy();
        End = Initial.copy();
        
        
        dchar letter;
        bool backfail = true; //faster than calling isStart??
        bool forefail = true;
        while(Start.backwardChar)
        {
            letter = Start.getChar();
            if(letter.isIdentifierChar) continue;
            backfail = false;
            break;
        }
        
        if(!backfail) Start.forwardChar();
        if(!Start.getChar.isIdentifierStartChar()) return rv; //not on a valid identifier
        
        while(End.forwardChar)
        {
            letter = End.getChar();
            if(letter.isIdentifierChar) continue;
            if(letter.isIdentifierStartChar)continue;
            //End.backwardChar();
            forefail = false;
            break;            
        }
        if((forefail) && (!letter.isIdentifierChar())) return rv;
        
        rv = buff.getSlice(Start, End, true);
        return rv;
    }
    
    string Word(string markName)
    {
        string rv;
        TextIter initial = new TextIter;
        TextIter start;
        TextIter end;
        buff.getIterAtMark(initial, buff.getMark("insert"));
        
        if(!initial.insideWord) return rv;
        start = initial.copy();
        end = initial.copy();
        do
        {
            if(start.startsWord)break;
        }while(start.backwardChar());
        do
        {
            if(end.endsWord)break;
        }while(end.forwardChar());
        rv = buff.getText(start,end, true);
        return rv;
    }
    
    void CompleteSymbol(string chosenSymbol)
    {
        TextIter tiStart, tiEnd;
        TextIter tiCursor;
        
        tiCursor = Cursor();    
        MoveWordBack();
        buff.insertAtCursor(chosenSymbol);
          
    }
    
    
    //================= 
    void MoveWordBack()
    {
        dchar lastChar;
        dchar thisChar;
        bool  foundstart;

        auto ti = Cursor;

        lastChar = '0';
        while(ti.backwardChar())
        {
            thisChar = ti.getChar();

            if(lastChar.isIdentifierStartChar() && !thisChar.isIdentifierChar())
            {
                ti.forwardChar();
                buff.placeCursor(ti);
                break;
            }
            lastChar = thisChar;
        }

    }

    

}

string NameMaker()
{
    static int suffixNumber = 0;
    scope(exit)suffixNumber++;
    
    string baseName = getcwd() ~ "/dcomposer%0s.d";
    return format(baseName, suffixNumber);
}


extern (C)
{
    import gio.AsyncResultIF;
    import gio.Task;
    void FileLoaded(GObject *source_object, GAsyncResult *res, void * user_data)
    {
        try
        {
            auto dfile = cast(SourceFileLoader)user_data;
            auto theTask = new Task(cast(GTask*)res);  
            if(!dfile.loadFinish(theTask))
            {
                Log.Entry("File load error");
            }
        }
        catch(Exception oops)
        {
            Log.Entry(oops.msg, "-Error");
        }
    }   
    void FileSaved(GObject *source_object, GAsyncResult *res, void * user_data)
	{   
    	
    }
}


bool isIdentifierStartChar( dchar letter)
{
    return ( (letter.isAlpha()) || (letter == '_'));
}
bool isIdentifierChar(dchar letter)
{
    return ( (letter.isAlphaNum) || (letter == '_' ));
}
