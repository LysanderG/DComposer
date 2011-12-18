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
import docpop;

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


import gtk.Label;
import gtk.Widget;
import gtk.HBox;
import gtk.Button;
import gtk.TextBuffer;
import gtk.MessageDialog;
import gtk.Clipboard;
import gtk.TextIter;




class DOCUMENT : SourceView, DOCUMENT_IF
{
    private:

    Label       mTabLabel;
    string      mFullName;

    SysTime     mTimeStamp;
    bool        mVirgin;

    void ModifyTabLabel(TextBuffer tb)
    {
        if(IsModified()) mTabLabel.setMarkup(`<span foreground="black" > [* </span> <b>` ~ DisplayName ~ `</b><span foreground="black"  > *]</span>`);
        else mTabLabel.setMarkup(DisplayName);
        mTabLabel.setTooltipText(FullName);
        
    }

    //check for external modification ... stupid name I was like "what the hell is that" and I named it!
    bool CheckExtMod(GdkEventFocus* Event, Widget widget)
    {
        if(IsVirgin) return false;

        if(mTimeStamp < timeLastModified(FullName))
        {
            auto msg = new MessageDialog(dui.GetWindow, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, true,null);
            msg.setMarkup(FullName ~ " has been modified externally.\nWould you like to reload it with any changes\nor ignore changes?");
            msg.addButton("Reload", 1000);
            msg.addButton("Ignore", 2000);

            auto rv = msg.run();
            msg.destroy();
            if(rv == 1000)Open(FullName);
            else mTimeStamp = timeLastModified(FullName);
        }
        return false;
    }

    void SetBreakPoint(TextIter ti, GdkEvent * event, SourceView sv)
    {
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

    

    public:

    @property string DisplayName(){return baseName(mFullName);}
    @property string FullName(){return mFullName;}
    @property void FullName(string NuName){mFullName = NuName; mTabLabel.setMarkup(DisplayName);}

    this()
    {
        mTabLabel = new Label("untitled");
        
        getBuffer().addOnModifiedChanged(&ModifyTabLabel);

        addOnKeyPress(&dui.GetDocPop.CatchKey);
        addOnButtonPress(&dui.GetDocPop.CatchButton);    

        addOnFocusIn(&CheckExtMod);
    }
    
    bool Create(string identifier)
    {
        FullName = identifier;
        mVirgin = true;

        SetupSourceView();
        
        return true;
    }

    bool Open(string FileName, ulong LineNo = 1)
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

        //if(DocText is null) return false;

        
        
        getBuffer.beginNotUndoableAction();
        getBuffer.setText(DocText);
        getBuffer.endNotUndoableAction();
        FullName = FileName;
        mTimeStamp = timeLastModified(FullName);
        mVirgin = false;
        getBuffer.setModified(false);

        SetupSourceView();
        return true;
    }

    
    bool    Save()
    {
        if(IsVirgin()) return false;

        if(!IsModified) return false; //no need to save

        string saveText = getBuffer.getText();

        std.file.write(FullName, saveText);

        getBuffer.setModified(0);
        mTimeStamp = timeLastModified(FullName);
        mVirgin = false;
                
        return true;
    }
    bool    SaveAs(string NewName)
    {
        FullName = NewName;
        string saveText = getBuffer.getText();

        std.file.write(FullName, saveText);

        getBuffer.setModified(0);
        mTimeStamp = timeLastModified(FullName);
        mVirgin = false;
        ModifyTabLabel(getBuffer);
                
        return true;
    }
    bool    Close(bool Quitting = false)
    {
        if(!IsModified())return true;

        auto ToSaveDiscardOrKeepOpen = new MessageDialog(dui.GetWindow(), DialogFlags.DESTROY_WITH_PARENT, GtkMessageType.INFO, ButtonsType.NONE, true, null); 
        ToSaveDiscardOrKeepOpen.setMarkup("Closing a modified file :" ~ DisplayName ~ "\nWhat do you wish to do?");
        ToSaveDiscardOrKeepOpen.addButton("Save Changes", cast(GtkResponseType) 1);
        ToSaveDiscardOrKeepOpen.addButton("Discard Changes", cast(GtkResponseType) 2);
        if(!Quitting)ToSaveDiscardOrKeepOpen.addButton("Do not Close", cast(GtkResponseType) 3);

        int rVal = cast(int) ToSaveDiscardOrKeepOpen.run();
        ToSaveDiscardOrKeepOpen.destroy();

        switch(rVal)
        {
            case 1: if(mVirgin)SaveAs(DisplayName); else Save();return true;
            case 2: return true;
            case 3: return false;
            default : Log().Entry("Bad ResponseType from Confirm CloseFileDialog", "Error");
        }

        return true;

    }

    string  GetDisplayName(){return mFullName;}
    string  GetFullFileName(){return mFullName;}
    bool    IsModified(){return cast(bool)getBuffer().getModified();}
    
    bool    IsVirgin(){return mVirgin;}
    Widget  GetTab()
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
        
        mTabLabel.setTooltipText(FullName);
        Tab.showAll();
        
        return Tab;
    }
    Widget  GetPage(){return this;}


    void TabXButton(Button x)
    {
        dui.GetDocMan().CloseDoc(mFullName);
    }

    void GrabFocus()
    {
        grabFocus();
    }


    void SetupSourceView()
    {
        auto Language = SourceLanguageManager.getDefault().guessLanguage(FullName,null);
        if(Language!is null) getBuffer.setLanguage(Language);

        string StyleId = Config().getString("DOCMAN","style_scheme");
        getBuffer().setStyleScheme(SourceStyleSchemeManager.getDefault().getScheme(StyleId));

        setTabWidth(Config().getInteger("DOCMAN", "tab_width"));

        setInsertSpacesInsteadOfTabs(Config().getBoolean("DOCMAN","spaces_for_tabs"));
        setAutoIndent(true);
        setShowLineNumbers(true);
        modifyFont("Anonymous Pro", 12);

        setSmartHomeEnd(SourceSmartHomeEndType.AFTER);
        
        setShowLineMarks(true);
        setMarkCategoryIconFromStock ("breakpoint", "gtk-yes");
        addOnLineMarkActivated(&SetBreakPoint);
        BreakPoint.connect(&Debugger.CatchBreakPoint);

        getBuffer.createTag("hiliteback", "background", "green");
        getBuffer.createTag("hilitefore", "foreground", "yellow");

        getBuffer.addOnInsertText(&OnInsertText, cast(GConnectFlags)1);
    }

    void Edit(string Verb)
    {
        Log.Entry("Edit action received --- "~ Verb,"Debug");

        switch (Verb)
        {
            case "UNDO"  :   getBuffer.undo();   break;
            case "REDO"  :   getBuffer.redo();   break;
            case "CUT"   :   getBuffer.cutClipboard(Clipboard.get(cast(GdkAtom)69),1); break;
            case "COPY"  :   getBuffer.copyClipboard(Clipboard.get(cast(GdkAtom)69)); break;
            case "PASTE" :   getBuffer.pasteClipboard(Clipboard.get(cast(GdkAtom)69),null, 1); break;
            case "DELETE":   getBuffer.deleteSelection(1,1);break;

            default : Log.Entry("Currently unavailable function :"~Verb,"Debug");
        }
            
    }

    void GotoLine(int Line)
    {
        TextIter ti = new TextIter;

        getBuffer.getIterAtLine(ti, Line);

        getBuffer.placeCursor(ti);

        auto mark = getBuffer.createMark("scroller", ti, 1);
        //scrollToIter(ti , 0.25, true, 0.0, 0.0);
        //scrollMarkOnscreen(mark);
        scrollToMark (mark, 0.00, true , 0.000, 0.000); 
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

        getBuffer.getIterAtMark(ti, mark);       
        
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
        writeln("Ascii Encoding");
        transcode(TryAsc, myUtfString);
        
        return myUtfString;
    }    

    Latin1String TryLatin = cast(Latin1String)data;
    if(TryLatin.isValid())
    {
        
        TryLatin = sanitize(TryLatin);
        writeln("Latin Encoding");
        transcode(TryLatin, myUtfString);
        return myUtfString;
    }

    return null;
}
*/    
        
