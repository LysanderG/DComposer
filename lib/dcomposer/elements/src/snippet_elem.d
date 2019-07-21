module snippet_elem;

import std.regex;
import std.file;
import std.conv;
import std.path;

import etc.linux.memoryerror;

import ui;
import elements;
import docman;
import document; 
import dcore;

extern (C) string GetClassName()
{
    return "snippet_elem.SNIPPETS";
}



class MIRROR
{
    TextMark            mMirrorMarkStart;
    TextMark            mMirrorMarkEnd;
}

struct TAB_STOP
{
    int                 mId;
    string              mText;
    
    TextMark            mTStopMarkStart;
    TextMark            mTStopMarkEnd;
    
    MIRROR[]            mMirrors;   
    
    this(int id, string deftext, TextMark start, TextMark end)
    {
        mId = id;
        mText = deftext;
        mTStopMarkStart = start;
        mTStopMarkEnd = end;
        registerMemoryErrorHandler();
    }
    
    void AddMirror(TextMark start, TextMark end)
    {
        auto mirror = new MIRROR;
        mMirrors ~= mirror;
        mMirrors[$-1].mMirrorMarkStart = start;
        mMirrors[$-1].mMirrorMarkEnd = end;
    }
    
    void ReflectMirrors()
    {
        if(mMirrors.length < 1) return;
        
        auto doc = cast(DOCUMENT)DocMan.Current();
        auto buffer = doc.getBuffer();
        
        TextIter tiStart, tiEnd;
        buffer.getIterAtMark(tiStart, mTStopMarkStart);
        buffer.getIterAtMark(tiEnd, mTStopMarkEnd);
        bool movedForward = tiEnd.forwardChar();
        if(!doc.Cursor().inRange(tiStart, tiEnd))return;
        if(movedForward)tiEnd.backwardChar();

        auto text = buffer.getText(tiStart, tiEnd, true);
        
        TextIter tiTstart, tiTend;
        foreach(mirror; mMirrors)
        {
            buffer.getIterAtMark(tiTstart, mirror.mMirrorMarkStart);
            buffer.getIterAtMark(tiTend, mirror.mMirrorMarkEnd);
            
            buffer.delet(tiTstart, tiTend);
            
            buffer.insert(tiTend, text); 
            
            buffer.moveMark(mirror.mMirrorMarkEnd, tiTend);           
        }
    }
    
    void AdjustEndMark()
    {
        TextIter ti = new TextIter;
        TextMark temp ;
        auto doc = cast(DOCUMENT)DocMan.Current();
        auto buff = doc.getBuffer();
        
        buff.getIterAtMark(ti, mTStopMarkEnd);
        temp  = new TextMark(cast(string)null, false);
        buff.addMark(temp, ti);
        
        buff.deleteMark(mTStopMarkEnd);
        mTStopMarkEnd.unref();
        
        mTStopMarkEnd = temp;
    }
        
    
}


struct SNIP
{
    string              mTrigger;
    string              mDescription;
    string              mBody;
    
    TextMark            mSnipMarkStart;
    TextMark            mSnipMarkEnd;
    
    TAB_STOP[int]       mTabStops;
    
    this(string trigger, string description, string corpse)
    {
        mTrigger = trigger;
        mDescription = description;
        mBody = corpse;
    }
    
    void Insert(SNIPPETS snippet, bool eraseTrigger = true)
    {
        TextMark startmark, endmark;
        scope(exit)uiCompletion.Enable();
        uiCompletion.Disable();
        
        auto doc = cast(DOCUMENT)DocMan.Current();
        auto buffer = doc.getBuffer();
        
        auto selText = doc.Selection();
        
        if(eraseTrigger)
        {
            doc.MoveLeft(cast(int)mTrigger.length, true);   
        }
        doc.ReplaceSelection("");
        string BodyText  = mBody.replaceAll(regex(`\$\{VISUAL\}`), selText);

        auto zeroTabMatch = BodyText.matchFirst(regex(`((\$\{0)|(\$0))`));
        if(zeroTabMatch.empty)BodyText ~= "${0}";
        
        scope(exit)buffer.endUserAction();
        buffer.beginUserAction();
        
        auto tstopMatch = matchFirst(BodyText, regex(`(\$\{[^}]*\})|(\$\d+)`));
        
        mSnipMarkStart = buffer.createMark(null, doc.Cursor, true);
        mSnipMarkStart.setVisible(true);
        
        while(tstopMatch)
        {		
            //DocMan.DocumentKeyDown.disconnect(&snippet.WatchKeyDown);
            foreach(c; tstopMatch.pre)
            {
                doc.insertText([c]);
		//doc.InsertText([c]);
		//buffer.insertAtCursor([c]);
                while(Main.eventsPending()){Main.iteration();}
            }
            //DocMan.DocumentKeyDown.connect(&snippet.WatchKeyDown);
            
            auto tstopIdMatch = matchFirst(tstopMatch.hit, regex(`\d+`));
            auto id = tstopIdMatch.hit.to!int;
            auto tstopDefTextMatch = matchFirst(tstopMatch.hit, regex(`(?<=:)[^}]+`));
            //auto DefText = (tstopDefTextMatch) ? tstopDefTextMatch.hit : "";
            string DefText;
            if(tstopDefTextMatch.empty) DefText = "";
            else DefText = tstopDefTextMatch.hit;
            auto ti = doc.Cursor();
            startmark =  buffer.createMark(null, ti, true);
            startmark.setVisible(true);
            
            if(id in mTabStops) //mirror
            {         
                //DocMan.DocumentKeyDown.disconnect(&snippet.WatchKeyDown);
                foreach(c; mTabStops[id].mText)
                {
                    doc.insertText([c]);
		    //doc.InsertText([c]);
                    while(Main.eventsPending()){Main.iteration();}
                }
                //DocMan.DocumentKeyDown.connect(&snippet.WatchKeyDown);
                
                buffer.getIterAtMark(ti, buffer.getMark("insert"));
                endmark = buffer.createMark(null, ti, true);
                endmark.setVisible(true);
                mTabStops[id].AddMirror(startmark, endmark);
            }
            else //new tabstop
            {
                
                //DocMan.DocumentKeyDown.disconnect(&snippet.WatchKeyDown);
                foreach(c; DefText)
                {
                    doc.insertText([c]);
		    //doc.InsertText([c]);
                    while(Main.eventsPending()){Main.iteration();}
                }
                //DocMan.DocumentKeyDown.connect(&snippet.WatchKeyDown);
                
                buffer.getIterAtMark(ti, buffer.getMark("insert"));
                endmark = buffer.createMark(null, ti, true);
                endmark.setVisible(true);
                
                mTabStops[id] = TAB_STOP(id, DefText, startmark, endmark);
            }
            
            string trailing = tstopMatch.post;
            tstopMatch = matchFirst(tstopMatch.post, regex(`(\$\{[^}]*\})|(\$\d+)`));
            if(tstopMatch.empty())
            {
                //DocMan.DocumentKeyDown.disconnect(&snippet.WatchKeyDown);
                foreach(c; trailing)
                {
                    doc.insertText([c]);
		    //doc.InsertText([c]);
		    //buffer.insertAtCursor([c]);
                    while(Main.eventsPending()){Main.iteration();}
                }
                //DocMan.DocumentKeyDown.connect(&snippet.WatchKeyDown);
            }
        } 
        
        mSnipMarkEnd = buffer.createMark(null, doc.Cursor(), true);
        doc.scrollMarkOnscreen(mSnipMarkEnd);
        
        foreach(ref ts; mTabStops)
        {
            ts.AdjustEndMark();
        }

    }
    
    void GotoTabStop(int tab)
    {
        auto doc = cast(DOCUMENT)DocMan.Current();
        auto buffer = doc.getBuffer();
        
        TextIter ti = new TextIter;
        buffer.getIterAtMark(ti, mTabStops[tab].mTStopMarkStart);
        buffer.moveMarkByName("selection_bound", ti );
        
        buffer.getIterAtMark(ti, mTabStops[tab].mTStopMarkEnd);
        buffer.moveMarkByName("insert", ti );
        doc.scrollMarkOnscreen(mTabStops[tab].mTStopMarkEnd);
    }
    
    void Clear()
    {
        auto doc = cast(DOCUMENT)DocMan.Current();
	if(doc is null) return;
        auto buffer = doc.getBuffer();

        if(mSnipMarkStart)
        {
            mSnipMarkStart.setVisible(false);
            buffer.deleteMark(mSnipMarkStart);
        }
        if(mSnipMarkEnd)
        {
            mSnipMarkEnd.setVisible(false);
            buffer.deleteMark(mSnipMarkEnd);
        }
        
        foreach(ts; mTabStops)
        {
           ts.mTStopMarkStart.setVisible(false);
           buffer.deleteMark(ts.mTStopMarkStart);
           ts.mTStopMarkEnd.setVisible(false);
           buffer.deleteMark(ts.mTStopMarkEnd);
           foreach(mirror; ts.mMirrors)
           {
               mirror.mMirrorMarkStart.setVisible(false);
               buffer.deleteMark(mirror.mMirrorMarkStart);
               mirror.mMirrorMarkEnd.setVisible(false);
               buffer.deleteMark(mirror.mMirrorMarkEnd);
           }
        }
    }
   
}


class SNIPPETS : ELEMENT
{
    public:
    
    string Name(){return "Snippet";}
    string Info(){return "Snippets for DComposer :)";}
    string Version(){return "00.01a";}
    string License(){return "Unspecified as of yet";}
    string CopyRight(){return "Anthony Goins © 2016";}
    string[] Authors(){return ["Anthony Goins"];}

    void Engage()
    {
        DocMan.SnippetTrigger.connect(&WatchTrigger);
        DocMan.DocumentKeyDown.connect(&WatchKeyDown);
        DocMan.DocumentKeyUp.connect(&WatchKeyUp);


        mStatusText = `<span background="dark gray" color="black">Snippet Mode :</span> `;
        mStatusLabel = new Label(mStatusText);
        mStatusLabel.setMarkup(mStatusText);
        AddStatusBox(mStatusLabel,false, false, 1);
                


	mMarkStart = new TextMark("snippet_start", true);
	mMarkEnd = new TextMark("snippet_end", true);

        
        mCurrentTabStop = 0;
        
        LoadSnippetFiles();
        Log.Entry("Engaged");
    }
    
    void Disengage()
    {
        SetMode(false);
        DocMan.DocumentKeyUp.disconnect(&WatchKeyUp);
        DocMan.DocumentKeyDown.disconnect(&WatchKeyDown);
        DocMan.SnippetTrigger.disconnect(&WatchTrigger);
        RemoveStatusBox(mStatusLabel);
    }

    void Configure()
    {
    }
    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }
    
    private:
    
    bool                mMode;
    bool                mExeFromTrigger;
    
    SNIP[string]        mSnips;
    SNIP                mCurrentSnip;
    int                 mCurrentTabStop;
    
    TextMark            mMarkStart;
    TextMark            mMarkEnd;
    
    Label               mStatusLabel;
    string              mStatusText;
    
  
    void LoadSnippetFiles()
    {
        mSnips.Clear;
        auto rgx = regex(`^snippet (?P<trigger>[\w]+) (?P<description>[^\n]+)\n(?P<body>(.|\n)+?(?=endsnippet$))`, "mg");
        void ParseSnippets(string stext)
        {
            foreach(match; matchAll(stext, rgx))
            {
                if(match["trigger"] in mSnips)Log.Entry("Conflict " ~ match["trigger"], "Error");
                mSnips[match["trigger"]] = SNIP(match["trigger"],match["description"],match["body"]);               
            }
            
        }
        
        foreach(resPath; ElementPaths())
        {
            if(!buildPath(resPath,"resources").exists())continue;
            foreach(string filename; dirEntries(buildPath(resPath,"resources"), SpanMode.shallow))
            {
                if(filename.extension() != ".snippets")continue;
                if(!filename.isFile) continue;
                auto fileText = readText(filename);
                ParseSnippets(fileText);
                Log.Entry(filename ~ " read");
            }
        }
    }
    
    void ExecuteSnippet(string trigger, bool eraseTrigger = true)
    {
        if(trigger !in mSnips) return;
        mCurrentSnip = mSnips[trigger];
        SetMode(true);
        mCurrentSnip.Insert(this, eraseTrigger);
        AdvanceTabStop();
        DocMan.SetBlockDocumentKeyPress();
    }
    
    void AdvanceTabStop()
    {
        mCurrentTabStop++;
        
        if(mCurrentTabStop !in mCurrentSnip.mTabStops)
        {
            mCurrentTabStop = 0; //zero should always be a tabstop 
        }
        mCurrentSnip.GotoTabStop(mCurrentTabStop);
        
        if(mCurrentTabStop == 0)
        {
            SetMode(false);
        }               
    }
    
    //SNIP AddSnippet(string snipText)
    //{
    //}
    
    void SetMode(bool newMode)
    {
        if(newMode == false)
        {
            mCurrentTabStop = 0;
            mCurrentSnip.Clear();
            mMode = false;
            mStatusLabel.setVisible(false);
        }
        else
        {
            mCurrentTabStop = 0;
            mMode = true;
            mStatusText = `<span background="dark gray" color="black">Snippet Mode : ` ~ mCurrentSnip.mDescription ~ ` </span> `;
            mStatusLabel.setMarkup(mStatusText);
            mStatusLabel.setVisible(true);
        }
    }
    
    void WatchTrigger(DOC_IF doc, string trigger)
    {
        if(mMode) return;
        mExeFromTrigger = true;
        ExecuteSnippet(trigger, false);
    }
    
    void WatchKeyDown(uint keyval, uint modifier)
    {
	if(DocMan.IsDocumentKeyPressBlocked()) return;
        if(mMode)
        {
            if(uiCompletion.GetState() == COMPLETION_STATUS.ACTIVE)return;
            TextIter tiAs, tiAe;
            auto doc = cast(DOCUMENT)DocMan.Current();
            auto buff = doc.getBuffer();
            buff.getIterAtMark(tiAs, mCurrentSnip.mSnipMarkStart);
            buff.getIterAtMark(tiAe, mCurrentSnip.mSnipMarkEnd);

            auto ti = doc.Cursor();
            

            if(!ti.inRange(tiAs, tiAe))
            {
                SetMode(false);
                return;
            }
                
            if(keyval == GdkKeysyms.GDK_Tab)
            {
                if(mExeFromTrigger)
                {
                    mExeFromTrigger = false;
                    return;
                }
                DocMan.SetBlockDocumentKeyPress();
                AdvanceTabStop();
            }
            return;
        }
        //ok not in snippet mode
        if(keyval == GdkKeysyms.GDK_Tab)
        {
            auto trigger = DocMan.Current.Word();
            ExecuteSnippet(trigger);
        }            
    }
    
    void WatchKeyUp(uint keyval, uint mod)
    {
        if(mMode)
        {
            foreach(tstop; mCurrentSnip.mTabStops)
            {
                tstop.ReflectMirrors();
            }
        }
    }
}
    
