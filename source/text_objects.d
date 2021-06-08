module text_objects;

import std.path;
import std.regex;

import config;
import docman;
import log;


import gtk.TextIter;
import gsv.SourceSearchContext;
import gsv.SourceSearchSettings;



TEXT_OBJECT_IF[string] mTextObject;
private CONFIG                 mConfigRegexObjects;


void EngageTextObjects()
{
    mConfigRegexObjects = new CONFIG;
    mConfigRegexObjects.SetCfgFile(buildPath(findResource("text_objects"),"text_objects"));
    mConfigRegexObjects.Load();
    dwrite(mConfigRegexObjects.GetValue("config","this_file", "undefined!!"));
    dwrite(mConfigRegexObjects.GetKeys("objects"));
    foreach(key; mConfigRegexObjects.GetKeys("objects"))
        CreateTextRegexObject(key, mConfigRegexObjects.GetValue!string("objects", key));
    
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



void CreateTextRegexObject(string UniqueObjectName, string definition)
{
    TEXT_OBJECT_REGEX nubee = new TEXT_OBJECT_REGEX;
    nubee.SetRegexDefinition(definition);
    mTextObject[UniqueObjectName] = nubee;
}

void AddTextObject(string UniqueObjectName, TEXT_OBJECT_IF textObject)
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
