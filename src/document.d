//      document.d
//      
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//      
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//      
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//      
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.


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
import gtkc.gtk;

import gdk.Event;

import gobject.ObjectG;
import gobject.ParamSpec;

import pango.PgFontDescription;


class DOCUMENT : SourceView, DOCUMENT_IF
{
    private:

    Label       mTabLabel;
    string      mFullName;

    SysTime     mTimeStamp;
    bool        mVirgin;

    bool        mPasting; //completion/calltips/scopelist screw up pasting operations that include a ".", "(" so if pasting dont do those ops

    DOC_TYPE    mType;

    void ModifyTabLabel(TextBuffer tb)
    {
        if(Modified()) mTabLabel.setMarkup(`<span foreground="black" > [* </span> <b>` ~ DisplayName ~ `</b><span foreground="black"  > *]</span>`);
        else mTabLabel.setMarkup(DisplayName);
        mTabLabel.setTooltipText(FullPathName);
        
    }

    bool CheckForExternalChanges(GdkEventFocus* Event, Widget widget)
    {
        if(Virgin) return false;

        if(mTimeStamp < timeLastModified(FullPathName))
        {
            auto msg = new MessageDialog(dui.GetWindow, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, true,null);
            msg.setMarkup(FullPathName ~ " has been modified externally.\nWould you like to reload it with any changes\nor ignore changes?");
            msg.addButton("Reload", 1000);
            msg.addButton("Ignore", 2000);

            auto rv = msg.run();
            msg.destroy();
            if(rv == 1000)Open(FullPathName);
            else mTimeStamp = timeLastModified(FullPathName);
        }
        return false;
    }

    void SetBreakPoint(TextIter ti, GdkEvent * event, SourceView sv)
    {
        scope(failure){Log.Entry("Error setting/removing breakpoint.","Error");return;}
        
        auto x = getBuffer.getSourceMarksAtIter(ti,"breakpoint");
        if(x is null)
        {
            getBuffer.createSourceMark(null, "breakpoint", ti);
            BreakPoint.emit("add", DisplayName, ti.getLine());
            return;
        }
        getBuffer.removeSourceMarks(ti, ti, "breakpoint");
        BreakPoint.emit("remove", DisplayName, ti.getLine());
    }        

    void TabXButton(Button x)
    {
        dui.GetDocMan().CloseDoc(mFullName);
    }

    void SetupSourceView()
    {
        auto Language = SourceLanguageManager.getDefault().guessLanguage(FullPathName,null);
        mType = DOC_TYPE.TEXT;
        if(Language!is null)
        {
            getBuffer.setLanguage(Language);
            if(Language.gtkSourceLanguageGetName() == "D") mType = DOC_TYPE.D_SOURCE;
        }

        string StyleId = Config.getString("DOCMAN","style_scheme", "cobalt");
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

        //modifyFont(Config.getString("DOCMAN", "font", "mono 18"), "");
        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.getString("DOCMAN", "font", "mono 18")));

        //string fontname = Config.getString("DOCMAN", "font_name", "Anonymous Pro");
        //int fontsize = Config.getInteger("DOCMAN", "font_size", 12);
        //modifyFont(fontname,fontsize);

        
        setShowLineMarks(true);
        setMarkCategoryIconFromStock ("breakpoint", "gtk-yes");
        setMarkCategoryIconFromStock ("lineindicator", "gtk-go-forward");
        addOnLineMarkActivated(&SetBreakPoint);
        BreakPoint.connect(&Debugger.CatchBreakPoint);

        getBuffer.createTag("hiliteback", "background", "green");
        getBuffer.createTag("hilitefore", "foreground", "yellow");

        setHasTooltip(true);

        getBuffer.addOnInsertText(&OnInsertText, cast(GConnectFlags)1);

        //clipboard edit enable disable stuff
        auto TheClipBoard = Clipboard.get(cast(GdkAtom)69);

        //addOnNotify(&SetUpEditSensitivity, cast(ConnectFlags)1);
        //addOn(delegate bool (Event x, Widget w) {SetUpEditSensitivity();return false;}, cast(ConnectFlags)1);
        addOnKeyRelease(delegate bool(GdkEventKey* k, Widget w){SetUpEditSensitivity();return false;});
        addOnButtonRelease( delegate bool(GdkEventButton* b, Widget w){SetUpEditSensitivity();return false;}); 
    }

    void SetUpEditSensitivity(ParamSpec ps = null, ObjectG og = null)
    {
        auto Clpbd = Clipboard.get(cast(GdkAtom)69);

        dui.Actions.getAction("PasteAct").setSensitive(Clpbd.waitIsTextAvailable());
        dui.Actions.getAction("CutAct").setSensitive(getBuffer.getHasSelection());
        dui.Actions.getAction("CopyAct").setSensitive(getBuffer.getHasSelection());
        return ;
    }


    void PopulateContextMenu(GtkMenu* gtkBigMenu, TextView ThisOne)
    {
        
        Menu X = new Menu(gtkBigMenu);

        Action[] ActionItems = dui.GetDocMan.ContextActions();

        foreach(action; ActionItems)X.prepend(action.createMenuItem());
    }

    bool Finalize()
    {
        BreakPoint.disconnect(&Debugger.CatchBreakPoint);
        Config.Reconfig.disconnect(&SetupSourceView);
        return true;
    }

    void Reconfigure()
    {
        auto Language = SourceLanguageManager.getDefault().guessLanguage(FullPathName,null);
        mType = DOC_TYPE.TEXT;
        if(Language!is null)
        {
            getBuffer.setLanguage(Language);
            if(Language.gtkSourceLanguageGetName() == "D") mType = DOC_TYPE.D_SOURCE;
        }

        string StyleId = Config.getString("DOCMAN","style_scheme", "cobalt");
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

        //modifyFont(Config.getString("DOCMAN", "font", "mono 18"), "");
        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.getString("DOCMAN", "font", "mono 18")));
    }

    public:

    @property string    DisplayName(){return baseName(mFullName);}
    @property void      DisplayName(string DisplayName){}
    @property string    FullPathName(){return mFullName;}
    @property void      FullPathName(string NuName){mFullName = NuName; mTabLabel.setMarkup(DisplayName);}
    @property bool      Virgin(){return mVirgin;}
    @property void      Virgin(bool still){if (still == false)mVirgin = false;}
    @property bool      Modified() {return cast(bool)getBuffer.getModified();}
    @property void      Modified(bool modded){getBuffer.setModified(modded);}
    @property DOC_TYPE  GetType(){return mType;}

    ubyte[] RawData(){ return cast(ubyte[]) getBuffer.getText();}



    this()
    {
        mTabLabel = new Label("untitled");
        
        getBuffer().addOnModifiedChanged(&ModifyTabLabel);
        getBuffer.addOnPasteDone (delegate void (Clipboard cb, TextBuffer tb) {mPasting = false;});

        
        addOnPopulatePopup (&PopulateContextMenu); 
        addOnFocusIn(&CheckForExternalChanges);

        Config.Reconfig.connect(&Reconfigure);
        
    }
    
    bool Create(string identifier)
    {
        FullPathName = identifier;
        mVirgin = true;
        SetupSourceView();
        return true;
    }


    //LineNo parameter is completely unused
    //must either remove it or implement it
    //calling functions are now using doc.open(filename); doc.GotoLine(x);
    //if I recall scroll to mark (and similiar functions) were a real headache
    //not working as I anticipated.
    bool Open(string FileName, ulong LineNo = 0)
    {
        string DocText;
        try
        {
            DocText = readText(FileName);
        }
        catch (UtfException e)
        {
            auto msg = new MessageDialog(dui.GetWindow(), GtkDialogFlags.MODAL, GtkMessageType.ERROR, ButtonsType.OK,
            false, "DComposer offers its most sincere apologies.\nThis development version is currently limited\n to opening valid UTF files.");

            msg.setTitle("Invalid UTF File");
            msg.run();
            msg.destroy();
            
            //DocText = MultiRead(FileName);
            DocText = null;
            return false;
        }        
        
        getBuffer.beginNotUndoableAction();
        getBuffer.setText(DocText);
        getBuffer.endNotUndoableAction();
        FullPathName = FileName;
        mTimeStamp = timeLastModified(FullPathName);
        mVirgin = false;
        getBuffer.setModified(false);

        SetupSourceView();
        
        return true;
    }
    
    bool    Save()
    {
        dui.Status.push(8690, "Saving ...");
        scope (exit)dui.Status.pop(8690);
                
        if(Virgin) return false;

        if(!Modified) return false; //no need to save

        string saveText = getBuffer.getText();

        std.file.write(FullPathName, saveText);

        getBuffer.setModified(0);
        mTimeStamp = timeLastModified(FullPathName);
        mVirgin = false;

        
        return true;
    }
    bool    SaveAs(string NewName)
    {
        FullPathName = NewName;
        string saveText = getBuffer.getText();

        std.file.write(FullPathName, saveText);

        getBuffer.setModified(0);
        mTimeStamp = timeLastModified(FullPathName);
        mVirgin = false;
        ModifyTabLabel(getBuffer);
                
        return true;
    }
    bool    Close(bool Quitting = false)
    {
        if(!Modified())return Finalize();

        auto ToSaveDiscardOrKeepOpen = new MessageDialog(dui.GetWindow(), DialogFlags.DESTROY_WITH_PARENT, GtkMessageType.INFO, ButtonsType.NONE, true, null); 
        ToSaveDiscardOrKeepOpen.setMarkup("Closing a modified file :" ~ DisplayName ~ "\nWhat do you wish to do?");
        ToSaveDiscardOrKeepOpen.addButton("Save Changes", cast(GtkResponseType) 1);
        ToSaveDiscardOrKeepOpen.addButton("Discard Changes", cast(GtkResponseType) 2);
        if(!Quitting)ToSaveDiscardOrKeepOpen.addButton("Do not Close", cast(GtkResponseType) 3);

        int rVal = cast(int) ToSaveDiscardOrKeepOpen.run();
        ToSaveDiscardOrKeepOpen.destroy();

        switch(rVal)
        {
            case 1: if(mVirgin)SaveAs(DisplayName); else Save();return Finalize();
            case 2: return Finalize();
            case 3: return false;
            case GtkResponseType.GTK_RESPONSE_DELETE_EVENT : return Finalize();
            default : Log().Entry("Bad ResponseType from Confirm CloseFileDialog", "Error");
        }

        return Finalize();
    }    

    Widget TabWidget()
    {
        HBox Tab = new HBox(0,1);
        Button xbtn = new Button(StockID.CLOSE, &TabXButton, true);
        xbtn.setBorderWidth(2);
        xbtn.setRelief(ReliefStyle.NONE);
        xbtn.setSizeRequest(20,20);
    
        mTabLabel.setText(DisplayName);
        Tab.add(mTabLabel);
        Tab.add(xbtn);
        Tab.setChildPacking (mTabLabel, 1, 1,0, GtkPackType.START);
        Tab.setChildPacking (xbtn, 1, 1,0, GtkPackType.END);
        
        mTabLabel.setTooltipText(FullPathName);
        Tab.showAll();
        
        return Tab;
    }
    Widget  GetWidget(){return this;}
    Widget  GetPage(){return getParent();}
    bool IsPasting(){return mPasting;}

    void Focus()
    {
        grabFocus();
    }

    void Edit(string Verb)
    {
        //Log.Entry("Edit action received --- "~ Verb,"Debug");

        switch (Verb)
        {
            case "UNDO"  :   getBuffer.undo();   break;
            case "REDO"  :   getBuffer.redo();   break;
            case "CUT"   :   getBuffer.cutClipboard(Clipboard.get(cast(GdkAtom)69),1); break;
            case "COPY"  :   getBuffer.copyClipboard(Clipboard.get(cast(GdkAtom)69)); break;
            case "PASTE" :   mPasting = true; getBuffer.pasteClipboard(Clipboard.get(cast(GdkAtom)69),null, 1); break;
            case "DELETE":   getBuffer.deleteSelection(1,1);break;

            default : Log.Entry("Currently unavailable function :"~Verb,"Debug");
        }            
    }
    void GotoLine(uint Line)
    {
        TextIter ti = new TextIter;

        getBuffer.getIterAtLine(ti, Line);

        getBuffer.placeCursor(ti);

        auto mark = getBuffer.createMark("scroller", ti, 1);
        //scrollToIter(ti , 0.25, true, 0.0, 0.0);
        //scrollMarkOnscreen(mark);
        scrollToMark (mark, 0.1, true , 0.000, 0.2500);
        TextIter tistart, tiend;
        tistart = new TextIter;
        tiend = new TextIter;
        getBuffer.getStartIter(tistart);
        getBuffer.getEndIter(tiend);
        getBuffer.removeSourceMarks(tistart, tiend, "lineindicator");
        getBuffer.createSourceMark(null, "lineindicator", ti);
        
    }

    void HiliteFindMatch(int Line, int start, int len)
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

    void OnInsertText(TextIter ti, string text, int len, TextBuffer huh)
    {
        auto mark = huh.createMark("huhx", ti, 0);

        if(text == "\n") NewLine.emit(ti, text, getBuffer);
        if(text == "}" ) CloseBrace.emit(ti, text, getBuffer);

        TextInserted.emit(this, ti, text, getBuffer);

        //getBuffer.getIterAtMark(ti, mark);       
        
    }

    string GetCurrentWord()
    {
        TextIter ti = new TextIter;
        
        
        getBuffer.getIterAtMark(ti, getBuffer.getInsert());

        if(!ti.insideWord)return "";

        TextIter tiend  = ti.copy();
        tiend.forwardWordEnd();
        ti.backwardWordStart();

        return ti.getSlice(tiend);
        
        
    }

    
    mixin Signal!(TextIter, string, TextBuffer) NewLine;
    mixin Signal!(TextIter, string, TextBuffer) CloseBrace;
    mixin Signal!(DOCUMENT, TextIter, string, SourceBuffer) TextInserted;
    mixin Signal!(string, string, int) BreakPoint;
}

//multiread as in multiple encoding schemes
string MultiRead(string FileName)
{
    //return null;
    void[] data = read(FileName);
    
    string rv = cast(string)(data);
    
    rv = rv.toUTF8;
    
    return (rv.isValid) ? rv : null;
}

/*
string MultiRead(string FileName)
{
    string myUtfString;
    ubyte[] data = cast(ubyte[])read(FileName);

    AsciiString TryAsc = cast(AsciiString) data;

    if(TryAsc.isValid())
    {
        TryAsc = sanitize(TryAsc);
        transcode(TryAsc, myUtfString);
        
        return myUtfString;
    }    

    Latin1String TryLatin = cast(Latin1String)data;
    if(TryLatin.isValid())
    {
        
        TryLatin = sanitize(TryLatin);
        transcode(TryLatin, myUtfString);
        return myUtfString;
    }
    return null;
}
*/    
 //notice how I have no idea what I am doing with text encoding?       
