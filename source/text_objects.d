module text_objects;

import std.path;
import std.regex;
import std.typecons;

import config;
import docman;
import log;


import gtk.TextIter;
import gsv.SourceSearchContext;
import gsv.SourceSearchSettings;



TEXT_OBJECT_IF_2[string] mTextObject;
private CONFIG           mConfigRegexObjects;


void EngageTextObjects()
{
    mConfigRegexObjects = new CONFIG;
    mConfigRegexObjects.SetCfgFile(buildPath(findResource("text_objects"),"text_objects"));
    mConfigRegexObjects.Load();
    dwrite(mConfigRegexObjects.GetValue("config","this_file", "undefined!!"));
    dwrite(mConfigRegexObjects.GetKeys("text_objects"));
    foreach(key; mConfigRegexObjects.GetKeys("text_objects"))
        CreateTextRegexObject(key, mConfigRegexObjects.GetArray!string("text_objects", key)[0..3]);
    
    Log.Entry("Engaged");
}
void MeshTextObjects()
{

    Log.Entry("Meshed");
}
void DisengageTextObjects()
{
    Log.Entry("Disengaged");
}



void CreateTextRegexObject(string UniqueObjectName, string[3] definitions)
{
    TEXT_OBJECT_REGEX_2 nubee = new TEXT_OBJECT_REGEX_2;
    nubee.SetRegexDefinition(definitions);
    mTextObject[UniqueObjectName] = nubee;
}

void AddTextObject(string UniqueObjectName, TEXT_OBJECT_IF_2 textObject)
{
    mTextObject[UniqueObjectName] = textObject;
}


interface TEXT_OBJECT_IF
{
    bool SetRegexDefinition(string definition);
    bool SelectNext(DOCUMENT Doc);
    bool SelectPrev(DOCUMENT Doc);
    
    bool StartNext(DOCUMENT Doc);
    bool StartPrev(DOCUMENT Doc);
    
    bool EndNext(DOCUMENT Doc);
    bool EndPrev(DOCUMENT Doc);
}
interface TEXT_OBJECT_IF_2
{
    bool SetRegexDefinition(string[3] definitions);
    toSelection SelectNext(DOCUMENT Doc);
    toSelection SelectPrev(DOCUMENT Doc);
    
    toSelection StartNext(DOCUMENT Doc);
    toSelection StartPrev(DOCUMENT Doc);
    
    toSelection EndNext(DOCUMENT Doc);
    toSelection EndPrev(DOCUMENT Doc);

}


class TEXT_OBJECT_REGEX : TEXT_OBJECT_IF
{
    private:
    string      mRegexDefinition;
    
    public:
    
    bool SetRegexDefinition(string definition)
    {
        mRegexDefinition = definition;
        return true;
    }   
    
    bool SelectNext(DOCUMENT Doc)
    {
        SourceSearchContext context = Doc.GetSearchContext();
        SourceSearchSettings settings = context.getSettings();
        settings.setCaseSensitive(true);
        settings.setRegexEnabled(true);
        settings.setWrapAround(false);
        settings.setSearchText(mRegexDefinition);
        context.setHighlight(false);
        
        TextIter ti, tiStart, tiEnd, tiStartX, tiEndX;
        ti = new TextIter;
        ti = Doc.Cursor().copy;
        bool hasWrapped;
        bool found;
        
        // this is to select the current object ... not going to do it for 
        // selectPrev!
        bool backedUp = context.backward(ti, tiStartX, tiEndX, hasWrapped);
        if(backedUp)
        {
            context.forward(tiEndX, tiStartX, tiEndX, hasWrapped);
            if( (ti.compare(tiStartX) == 1) && (ti.compare(tiEndX) == -1 ))
            {                // selecting current object
                Doc.getBuffer.selectRange(tiStartX,tiEndX);
                Doc.scrollToIter(tiStartX, 0.05, true, 0.05, 0.95);
                return true;
            }  
        }      
        found = context.forward(Doc.Cursor, tiStart, tiEnd, hasWrapped);
        if(found)
        {
            if(ti.compare(tiStart) == 0) 
            {
                ti = tiEnd.copy();
                found = context.forward(ti, tiStart, tiEnd, hasWrapped);          
            }
        }
        if(found)
        {
            Doc.getBuffer.selectRange(tiStart, tiEnd);
            Doc.scrollToMark(Doc.buff.getMark("insert"), 0.05, false, 0.0, 0.0);
        }
        return found;        
    }
    
    bool SelectPrev(DOCUMENT Doc)
    {
        SourceSearchContext context = Doc.GetSearchContext();
        SourceSearchSettings settings = context.getSettings();
        settings.setCaseSensitive(true);
        settings.setRegexEnabled(true);
        settings.setWrapAround(false);
        settings.setSearchText(mRegexDefinition);
        context.setHighlight(false);
        
        TextIter ti, tiStart, tiEnd;
        bool hasWrapped;
        
        bool found = context.backward(Doc.Cursor, tiStart, tiEnd, hasWrapped);
        if(found)
        {
            Doc.getBuffer.selectRange(tiStart, tiEnd);
            Doc.scrollToIter(tiStart, 0.05, false, 0.0, 0.0);
        }
        return found;        
    }
    
    bool StartNext(DOCUMENT Doc)
    {
        SourceSearchContext context = Doc.GetSearchContext();
        SourceSearchSettings settings = context.getSettings();
        settings.setCaseSensitive(true);
        settings.setRegexEnabled(true);
        settings.setWrapAround(false);
        settings.setSearchText(mRegexDefinition);
        context.setHighlight(false);        
        
        TextIter ti, tiStart, tiEnd;
        ti = Doc.Cursor.copy();
        bool hasWrapped;
        
        bool found = context.forward(ti, tiStart, tiEnd, hasWrapped);
        if(found)
        {
            if(ti.compare(tiStart) == 0)
            {
                ti = tiEnd.copy();
                found = context.forward(ti, tiStart, tiEnd, hasWrapped);
                if(!found) return false;
            }
            Doc.getBuffer.placeCursor(tiStart);
            Doc.scrollToIter(ti, 0.05, false, 0.0, 0.0);
        }
        return found;
    }    
    bool StartPrev(DOCUMENT Doc)
    {
        SourceSearchContext context = Doc.GetSearchContext();
        SourceSearchSettings settings = context.getSettings();
        settings.setCaseSensitive(true);
        settings.setRegexEnabled(true);
        settings.setWrapAround(false);
        settings.setSearchText(mRegexDefinition);
        context.setHighlight(false);
        
        TextIter ti, tiStart, tiEnd;
        ti = Doc.Cursor.copy();
        bool hasWrapped;
        
        //try not skipping first prev Start ??? that's not confusing
        if(context.forward(ti, tiStart, tiEnd, hasWrapped))
        {
            ti = tiStart.copy();
        }        
        bool found = context.backward(ti, tiStart, tiEnd, hasWrapped);
        if(found)
        {
            Doc.getBuffer.placeCursor(tiStart);
            Doc.scrollToIter(ti, 0.05, false, 0.0, 0.0);
        }
        return found;        
    }
    bool EndNext(DOCUMENT Doc)
    {
        SourceSearchContext context = Doc.GetSearchContext();
        SourceSearchSettings settings = context.getSettings();
        settings.setCaseSensitive(true);
        settings.setRegexEnabled(true);
        settings.setWrapAround(false);
        settings.setSearchText(mRegexDefinition);
        context.setHighlight(false);        
        
        TextIter ti, tiStart, tiEnd;
        ti = Doc.Cursor.copy();
        bool hasWrapped;
        
        //STOP THE CRAZY SKIPPING !!!
        if(context.backward(ti, tiStart,tiEnd, hasWrapped))
        {
            ti = tiEnd.copy();
        }
        
        bool found = context.forward(ti, tiStart, tiEnd, hasWrapped);
        if(found)
        {
            Doc.getBuffer.placeCursor(tiEnd);
            Doc.scrollToIter(tiEnd, 0.05, false, 0.0, 0.0);
        }
        return found;        
    }
    bool EndPrev(DOCUMENT Doc)
    {
        SourceSearchContext context = Doc.GetSearchContext();
        SourceSearchSettings settings = context.getSettings();
        settings.setCaseSensitive(true);
        settings.setRegexEnabled(true);
        settings.setWrapAround(false);
        settings.setSearchText(mRegexDefinition);
        context.setHighlight(false);        
        
        TextIter ti, tiStart, tiEnd;
        ti = Doc.Cursor.copy();
        bool hasWrapped;
        
        bool found = context.backward(ti, tiStart, tiEnd, hasWrapped);
        if(found)
        {
            if(ti.compare(tiEnd) == 0)
            {
                ti = tiStart.copy();
                found = context.backward(ti, tiStart, tiEnd, hasWrapped);
                if(!found) return false;
            }
            Doc.getBuffer.placeCursor(tiEnd);
            Doc.scrollToIter(tiEnd, 0.05, false, 0.0, 0.0);
        }
        return found;
        
    }
}

alias toSelection = Tuple!(bool ,"found", TextIter, "start", TextIter, "end");
class TEXT_OBJECT_REGEX_2: TEXT_OBJECT_IF_2
{
    private:
    
    string rgxStart;
    string rgxEnd;
    string rgxDefinition;
    
    TextIter tiCursor;
    TextIter tiStart;
    TextIter tiEnd;
    
    SourceSearchContext mTmpContext;
    SourceSearchSettings mTmpSettings;
    
    void Setup(DOCUMENT doc)
    {
        mTmpContext =  doc.GetSearchContext();
        mTmpSettings = mTmpContext.getSettings();
        
        mTmpSettings.setCaseSensitive(true);
        mTmpSettings.setRegexEnabled(true);
        mTmpSettings.setWrapAround(false);
        mTmpContext.setHighlight(false);        
        tiStart = new TextIter;
        tiEnd = new TextIter;
        tiCursor = doc.Cursor().copy;
    }
    
    public:
    
    //this(string definition, string start, string end)
    //{
    //    rgxStart = start;
    //    rgxEnd = end;
    //    rgxDefinition = definition;
    //}   

    bool SetRegexDefinition(string[3] definitions)
    {
        rgxStart = definitions[0];
        rgxEnd = definitions[1];
        rgxDefinition = definitions[2];
        return true;
    }
    
    toSelection SelectNext(DOCUMENT doc)
    {
        Setup(doc);
        bool hasWrapped;
        
        bool moved;
        TextIter tiXstart, tiXend;
        
        mTmpSettings.setSearchText(rgxDefinition);
        
        //backup to get "current" object
        moved = mTmpContext.backward(tiCursor, tiXstart, tiXend, hasWrapped);
        if(moved)
        {
	        if(mTmpContext.forward(tiXend, tiXstart, tiXend, hasWrapped))
	        {
		        if(tiCursor.compare(tiXstart) == 1 && tiCursor.compare(tiXend) == -1)
		        {
			        doc.getBuffer.selectRange(tiXstart, tiXend);
			        doc.scrollToIter(tiXstart, 0.05, false,  0.0, 0.0);
			        return toSelection(true, tiXstart, tiXend);
                }
                
            }
	    }
	    moved = mTmpContext.forward(tiCursor, tiStart, tiEnd, hasWrapped);
	    if(moved)
	    {
		    if(tiCursor.compare(tiStart) == 0)
		    {
			    if(!mTmpContext.forward(tiEnd, tiStart, tiEnd, hasWrapped))
			    	return toSelection(false, tiCursor, tiCursor.copy());
            }
		    doc.getBuffer().selectRange(tiStart, tiEnd);
		    doc.scrollToIter(tiStart, 0.05, false, 0.0, 0.0);
		    return toSelection(false, tiStart, tiEnd);
        }
	    return toSelection(false, tiCursor, tiCursor.copy());
        
    }
    
    toSelection SelectPrev(DOCUMENT doc)
    {
        Setup(doc);
        bool hasWrapped;
        mTmpSettings.setSearchText(rgxDefinition);
        
        if(mTmpContext.backward(tiCursor, tiStart, tiEnd, hasWrapped))
        {
            doc.getBuffer.selectRange(tiStart, tiEnd);
            doc.scrollToIter(tiStart, 0.05, false, 0.0, 0.0);
            return toSelection(true, tiStart, tiEnd);
        }
        return toSelection(false, tiStart, tiEnd);
    }
    
    toSelection StartNext(DOCUMENT doc)
    {
        Setup(doc);
        bool hasWrapped;
        mTmpSettings.setSearchText(rgxStart);
        
        if(mTmpContext.forward(tiCursor, tiStart, tiEnd, hasWrapped))
        {
	        if(tiCursor.compare(tiStart) == 0)
	        { 
		        dwrite("startnext ",tiCursor.getLineOffset, "/", tiStart.getLineOffset, "/", tiEnd.getLineOffset);
		    	if(!mTmpContext.forward(tiEnd, tiStart, tiEnd, hasWrapped)) 
		    	    return toSelection(false, tiCursor, tiCursor);
		    }
            doc.getBuffer.placeCursor(tiStart);
            doc.scrollToIter(tiStart, 0.05, false, 0.0, 0.0);
            return toSelection(true, tiStart, tiStart);
        }
        return toSelection(false, tiStart, tiStart);
    }
    toSelection StartPrev(DOCUMENT doc)
    {
        Setup(doc);
        bool hasWrapped;
        mTmpSettings.setSearchText(rgxStart);
        
        if(mTmpContext.backward(tiCursor, tiStart, tiEnd, hasWrapped))
        {
            doc.getBuffer.placeCursor(tiStart);
            doc.scrollToIter(tiStart, 0.05, false, 0.0, 0.0);
            return toSelection(true, tiStart, tiStart);
        }
        return toSelection(false, tiStart, tiStart);
    }
    
    toSelection EndNext(DOCUMENT doc)
    {
        Setup(doc);
        bool hasWrapped;
        mTmpSettings.setSearchText(rgxEnd);
        
        if(mTmpContext.forward(tiCursor, tiStart, tiEnd, hasWrapped))
        {
            if(tiCursor.compare(tiStart) == 0)
            {
                if(!mTmpContext.forward(tiEnd, tiStart, tiEnd,hasWrapped))
                    return toSelection(false, tiCursor, tiCursor);
            }
            doc.getBuffer.placeCursor(tiEnd);
            doc.scrollToIter(tiStart, 0.05, false, 0.0, 0.0);
            return toSelection(true, tiEnd, tiEnd);
        }
        return toSelection(false, tiEnd, tiEnd);        
    }
    
    toSelection EndPrev(DOCUMENT doc)
    {
        Setup(doc);
        bool hasWrapped;
        mTmpSettings.setSearchText(rgxEnd);
        
        if(mTmpContext.backward(tiCursor, tiStart, tiEnd, hasWrapped))
        {
            doc.getBuffer.placeCursor(tiEnd);
            doc.scrollToIter(tiStart, 0.05, false, 0.0, 0.0);
            return toSelection(true, tiStart, tiEnd);
       }
       return toSelection(false, tiStart, tiEnd);
    }
    
}
