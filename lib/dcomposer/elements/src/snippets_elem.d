module snippets_elem;

import std.regex;
import std.conv;
import std.typecons;
import std.file;
import std.path;
import std.string;
import gdk.Keysyms;
import std.algorithm;

import ui;
import dcore;
import elements;
import document;

extern (C) string GetClassName()
{
    return "snippets_elem.SNIPPETS";
}


class SNIPPETS : ELEMENT
{
    string Name(){return "Snippets";}
    string Info(){return "The most awesome snippet engine for dcomposer(aka the only snippet thingy for a naive ide)";}
    string Version(){return "00.01a";}
    string License(){return "Unspecified as of yet";}
    string CopyRight(){return "Anthony Goins © 2015";}
    string[] Authors(){return ["Anthony Goins"];}

    void Engage()
    {
        DocMan.SnippetTrigger.connect(&WatchSnippetTrigger);
        
        DocMan.DocumentKeyDown.connect(&WatchDocKeyDown);
        DocMan.DocumentKeyUp.connect(&WatchDocKeyUp);

        mActiveStartMark = new TextMark("snip_start", true);
        mActiveEndMark = new TextMark("snip_end", false);
        
        mStatusLabel = new Label("hi");
        mStatusLabel.setMarkup("<span background=\"black\" foreground=\"yellow\">Snippet Mode</span>");
        
        AddStatusBox(mStatusLabel,false, true, 0);
        
        
        LoadSnippets();
        Log.Entry("Engaged");
    }
    void Disengage()
    {
        
        RemoveStatusBox(mStatusLabel);
        DocMan.DocumentKeyUp.disconnect(&WatchDocKeyUp);
        DocMan.DocumentKeyDown.disconnect(&WatchDocKeyDown);
        DocMan.SnippetTrigger.disconnect(&WatchSnippetTrigger);
        Log.Entry("Disengaged");
    }

    void Configure()
    {
    }

    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }
    
    
    
    void InsertSnippet(string Trigger, Flag!"eraseTrigger" eraseTrigger = Flag!"eraseTrigger".yes)
    {
        if(Trigger !in mSnips) return;
        DocMan.SetBlockDocumentKeyPress();
        
        scope(exit)uiCompletion.Enable();
        uiCompletion.Disable();
        
        auto doc = cast(DOCUMENT)DocMan.Current();
        auto buffer = doc.getBuffer();
        
        RemoveTabStops(); 
        string selection = doc.Selection();   
        
        if(eraseTrigger)
        {
            doc.MoveLeft(cast(int)Trigger.length,true);   
        }
        doc.ReplaceSelection("");
        string expanded = mSnips[Trigger].replaceAll(regex(`\$\{VISUAL\}`), selection);

        auto cap = expanded.matchFirst(regex(`((\$\{0)|(\$0))`));
        if(cap.empty)expanded ~= "${0}";
        
        
        //handle \$\d+ and nested tabstops ie ${1: ${2:var} = ${$3:value}}
        auto xstop = matchFirst(expanded, regex(`(\$\{[^}]*\})|(\$\d+)`));
        buffer.beginUserAction();
        buffer.addMark(mActiveStartMark, doc.Cursor);
        
        while(xstop)
        {
            //doc.insertText(xstop.pre);
            foreach (c; xstop.pre)
            {
                doc.insertText([c]);
                while(Main.eventsPending()){Main.iteration();}
            }
            //foreach(line; xstop.pre.lineSplitter!(KeepTerminator.yes, string))
            //{
            //   doc.insertText("\n");
            //    doc.insertText(line);
            //}
            auto StrId = matchFirst(xstop.hit, regex(`\d+`));
            int IntId = StrId.hit.to!int;
            auto defvalue = matchFirst(xstop.hit,regex(`(?<=:)[^}]+`));
            string defText = (defvalue) ? defvalue.hit : "";
            
            
            if(IntId in mTabStops) //this is a mirror
            {
                if(!defvalue.empty)mTabStops[IntId].AddDefaultText(defText);
                mTabStops[IntId].AddMirror(doc.Cursor());
            }
            else //main or first tabstop
            {
                mTabStops[IntId] = TAB_STOP(StrId.hit, doc.Cursor(), buffer, defText);                
            }
            auto trail = xstop.post;       
            xstop = matchFirst(xstop.post, regex(`(\$\{[^}]*\})|(\$\d+)`)); 
            if(xstop.empty)
            {//doc.insertText(trail); 
                foreach (c; trail)
                {
                    doc.insertText([c]);
                    while(Main.eventsPending()){Main.iteration();}
                }    
            } 
                           
        }        
        buffer.addMark(mActiveEndMark, doc.Cursor);
        AdvanceTabStop(Flag!"firstStop".yes);
        buffer.endUserAction();
    }
    @property bool Mode()
    {
        return mSnippetMode;
    }
    private:
    
    SNIPS[string]   mSnips;    
    bool            mSnippetMode;
    TextMark[int]   mMarks;
    TAB_STOP[int]   mTabStops;
    int             mCurrentTabStopIndex;
    Label           mStatusLabel;
    TextMark        mActiveStartMark;
    TextMark        mActiveEndMark;
        
    void LoadSnippets()
    {
        mSnips.clear;
        auto rgx = regex(`^snippet (?P<trigger>[\w]+)(.)+\n(?P<body>(.|\n)+?(?=endsnippet$))`, "mg");
        
        void ParseSnippets(string stext)
        {
            foreach(match; matchAll(stext, rgx))
            {
                mSnips[match["trigger"]] = match["body"];               
            }
            
        }
        
        string resourcePath = SystemPath(Config.GetValue("snippets", "paths", "elements/resources/"));
        
        foreach(string filename; dirEntries(resourcePath, SpanMode.shallow))
        {
            if(filename.extension() != ".snippets")continue;
            if(!filename.isFile) continue;
            auto fileText = readText(filename);
            ParseSnippets(fileText);
        }
            
        
    }
        
    
    @disable void ProcessSnippetKeys(int keyval, int modKeyFlag)
    {
        if(!Mode) return;
        
        auto uniKey   = cast(char)Keymap.keyvalToUnicode(keyval);
        bool ctrlKey  = cast(bool)(modKeyFlag & GdkModifierType.CONTROL_MASK);
        bool shiftKey = modKeyFlag & GdkModifierType.SHIFT_MASK;
        
        if(uniKey == '\t')
        {
            DocMan.SetBlockDocumentKeyPress();
            AdvanceTabStop();
            return;
        }
        
        TextIter tiAs, tiAe;
        auto buff = (cast(DOCUMENT)(DocMan.Current)).getBuffer();
        buff.getIterAtMark(tiAs, mActiveStartMark);
        buff.getIterAtMark(tiAe, mActiveEndMark);
        
        auto ti = (cast(DOCUMENT)(DocMan.Current)).Cursor();
        
        if(!ti.inRange(tiAs, tiAe))
        {
            Mode = false;
            return;
        }
        
        foreach(tstop; mTabStops)
        {
            if(tstop.InRange(ti))
            {
                //tstop.ReflectMirrors();
                break;
            }
        }
        
    }
    
    void WatchDocKeyDown(uint keyval, uint modifier)
    { 
        if(Mode)
        { 
            TextIter tiAs, tiAe;
            auto buff = (cast(DOCUMENT)(DocMan.Current)).getBuffer();
            buff.getIterAtMark(tiAs, mActiveStartMark);
            buff.getIterAtMark(tiAe, mActiveEndMark);
            
            auto ti = (cast(DOCUMENT)(DocMan.Current)).Cursor();
            
            if(!ti.inRange(tiAs, tiAe))
            {
                Mode = false;
                return;
            }
                
            if(keyval == GdkKeysyms.GDK_Tab)
            {
                DocMan.SetBlockDocumentKeyPress();
                AdvanceTabStop();
            }
            return;
        }
        if(keyval == GdkKeysyms.GDK_Tab)
        {
            auto trigger = DocMan.Current.Word();
            //DocMan.SetBlockDocumentKeyPress();
            InsertSnippet(trigger);
        }                    
    }
    
    void WatchDocKeyUp(uint keyval, uint modifier)
    {
        if(Mode)
        {
            foreach(tstop; mTabStops)
            {
                tstop.ReflectMirrors();
            }
        }
    }
    
    void WatchSnippetTrigger(DOC_IF doc, string trigger)
    {
        if(Mode) return;
        InsertSnippet(trigger, Flag!"eraseTrigger".no);  
    }
    
    
    void RemoveTabStops()
    {
        foreach(ref stop; mTabStops)
        {
            stop.KillMe();
        }
        mTabStops.clear();
        
        auto buff = (cast(DOCUMENT)DocMan.Current()).getBuffer();
        buff.deleteMark(mActiveStartMark);
        buff.deleteMark(mActiveEndMark);
    }
    
    void AdvanceTabStop(Flag!"firstStop" firstStop = Flag!"firstStop".no)
    {
        scope(success)DocMan.Current.ScrollCenterCursor();
        
        TextIter ti;
        auto buffer = (cast(DOCUMENT)DocMan.Current).getBuffer();

        if(firstStop)
        {
            Mode = true;
            mCurrentTabStopIndex = 0;            
        }
        
        mCurrentTabStopIndex++;
        if(mCurrentTabStopIndex in mTabStops)
        {
            buffer.getIterAtMark(ti, mTabStops[mCurrentTabStopIndex].mMarkBound);
            buffer.moveMarkByName("selection_bound", ti );
            
            buffer.getIterAtMark(ti, mTabStops[mCurrentTabStopIndex].mMarkInsert);
            ti.forwardChar();
            buffer.moveMarkByName("insert", ti );
            
            return;
        }    
        if(0 in mTabStops)
        {
            mCurrentTabStopIndex = 0;
            
            buffer.getIterAtMark(ti, mTabStops[0].mMarkBound);
            buffer.moveMarkByName("selection_bound", ti );
            
            buffer.getIterAtMark(ti, mTabStops[0].mMarkInsert);
            ti.forwardChar();
            buffer.moveMarkByName("insert", ti );
        }
        Mode = false;     
        return;   
    }        
    
    @property void Mode(bool NewMode)
    {
        mSnippetMode = NewMode;
        mStatusLabel.setVisible(NewMode);
        if(Mode == false)
        {
            RemoveTabStops();
        }   
    }
}


alias SNIPS=string;
    
    
struct TAB_STOP
{
    string      mStringId;
    TextMark    mMarkBound;
    TextMark    mMarkInsert;
    TextMark[]  mMirrorsBound;
    TextMark[]  mMirrorsInsert;
    string      mDefaultText = "";
    TextBuffer  mBuffer;
    
    this(string Id,  TextIter Where, TextBuffer buffer, string defaultValue = "")
    {
        auto Position = Where.copy(); 
        mStringId = Id;
        mBuffer = buffer;
        mDefaultText = defaultValue;
                
        mMarkBound = buffer.createMark(mStringId ~ "_bound", Position, true);

        
        buffer.insert(Position, mDefaultText);
        Position.backwardChar();
        mMarkInsert = buffer.createMark(mStringId, Position, false);
        mMarkInsert.setVisible(true);
        mMarkBound.setVisible(true);
        

             
    }
    
    void AddMirror(TextIter Position)
    {
        string number = (mMirrorsBound.length).to!string;    
        mMirrorsBound ~= mBuffer.createMark(mStringId ~ "_" ~ number ~ "_bound", Position, true);
        mBuffer.insert(Position, mDefaultText);
        Position.backwardChar();
        mMirrorsInsert ~= mBuffer.createMark(mStringId ~ "_" ~ number ~ "_insert", Position, false);
        mMirrorsBound[$-1].setVisible(true);
        mMirrorsInsert[$-1].setVisible(true);
    }
     
    
    void AddDefaultText(string DefaultText)
    {
        if(mDefaultText.length < 2) mDefaultText = DefaultText;
    }
    
    void KillMe()
    {
        mMarkInsert.setVisible(false);
        mMarkBound.setVisible(false);
        mBuffer.deleteMark(mMarkInsert);
        mBuffer.deleteMark(mMarkBound);
        foreach(mark; mMirrorsInsert)
        {
            mark.setVisible(false);
            mBuffer.deleteMark(mark);
        }
        foreach(mark; mMirrorsBound)
        {
            mark.setVisible(false);
            mBuffer.deleteMark(mark);
        }
    }
    
    bool InRange(TextIter ti)
    {
        TextIter tiStart, tiEnd;
        mBuffer.getIterAtMark(tiStart, mMarkBound);
        mBuffer.getIterAtMark(tiEnd, mMarkInsert);
        tiEnd.forwardChar();        
        return ti.inRange(tiStart, tiEnd);
    }
    
    void ReflectMirrors()
    {
        TextIter tiStart, tiEnd;
        mBuffer.getIterAtMark(tiStart, mMarkBound);
        mBuffer.getIterAtMark(tiEnd, mMarkInsert);
        tiEnd.forwardChar();
        
        auto text = mBuffer.getText(tiStart, tiEnd, true);
        
        TextIter tiMBound, tiMInsert;
        if(mMirrorsBound.length < 1)return;
        foreach(index; 0 .. mMirrorsBound.length)
        {
            mBuffer.getIterAtMark(tiMBound, mMirrorsBound[index]);
            mBuffer.getIterAtMark(tiMInsert, mMirrorsInsert[index]);
            tiMInsert.forwardChar();


            mBuffer.delet(tiMBound, tiMInsert);
            mBuffer.getIterAtMark(tiMBound, mMirrorsBound[index]);
            mBuffer.getIterAtMark(tiMInsert, mMirrorsInsert[index]);
            //tiMInsert.forwardChar();
            
            mBuffer.insert(tiMInsert, text);
            
         }
    }
}
