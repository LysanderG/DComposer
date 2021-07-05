module curly_indent;

import std.string;

import qore;
import ui;
import elements;

extern(C) string GetElementName()
{
    return "curly_indent.CURLY_INDENT";
}


class CURLY_INDENT : ELEMENT
{

    void Engage()
    {
        Log.Entry("Engaged");
    }
    void Mesh()
    {
        Transmit.DocInsertText.connect(&WatchForText);
        Log.Entry("Meshed");
    }
    void Disengage()
    {
        Transmit.DocInsertText.disconnect(&WatchForText);
        
        Log.Entry("Disengaged");
        
    }

    void Configure(){Log.Entry("Configure");}

    string Name(){return "Curly Brackets".idup;}
    string Info(){return "Indents curly brackets... or braces(whatever)".idup;}
    string Version(){return "0.00".idup;}
    string License(){return "to be determined".idup;}
    string CopyRight(){return "2021 Anthony Goins".idup;}
    string Authors(){return "Lysander".idup;}

    Dialog SettingsDialog()
    {

        return new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.OTHER, ButtonsType.CLOSE, "Hey this is working");
    }
    
    void WatchForText(DOC_IF self, TextIter ti, string text)
    {
        if(text.length > 1) return;
        DOCUMENT doc = cast(DOCUMENT)self;
        TextIter startTi = ti.copy();
        TextIter endTi = ti.copy();
        TextMark SaveTiPos = doc.getBuffer.createMark("oldti", ti, true);
        scope(exit)
        {
            ti = new TextIter;
            doc.getBuffer.getIterAtMark(ti, SaveTiPos);
            doc.getBuffer.deleteMark(SaveTiPos);            
        }
        
        if (text == "\n")
        {
            startTi.backwardLine();                      
            auto lastline = doc.getBuffer.getText(startTi, endTi, false);
            lastline = lastline.stripRight();
            if(lastline.length < 1)return;
            if(lastline[$-1] != '{')return;
            foreach(i; 0 .. doc.getIndentWidth())doc.getBuffer.insert(ti, " ");  
            return;         
        }
        
        TextIter OpenBracketLineStart;
        TextIter OpenBracketLineEnd;
        if(text == "}")
        {
            startTi.setLineOffset(0);
            endTi.forwardToLineEnd();
            auto thisline = doc.getBuffer.getText(startTi, endTi, false);
            thisline = thisline.stripLeft();
            assert (thisline.length > 0);
            if(thisline[0] != '}')return;
            //find line with matching bracket
            OpenBracketLineStart = ti.copy();
            int counter = 1;
            while(OpenBracketLineStart.backwardChar())
            {
                assert(OpenBracketLineStart.getChar() != 0);
                if(OpenBracketLineStart.getChar() == '}') counter++;
                if(OpenBracketLineStart.getChar() == '{') counter--;
                if(counter == 0) break;
            }
            //get the 'indentation' string oblstart and oblend
            OpenBracketLineStart.setLineOffset(0);
            OpenBracketLineEnd = OpenBracketLineStart.copy();
            while((OpenBracketLineEnd.getChar == ' ') || (OpenBracketLineEnd.getChar == '\t')) OpenBracketLineEnd.forwardChar();
            string iString = doc.getBuffer.getText(OpenBracketLineStart, OpenBracketLineEnd, true);
            if(iString.length == 0) return;
            //delete current
            endTi = startTi.copy();
            while(endTi.forwardChar())
            {
                if((endTi.getChar() == ' ') || (endTi.getChar() == '\t')) continue;
                break;
            }
            TextMark preDeleteMark = doc.getBuffer.createMark("ok", ti, false);
            if(startTi.compare(endTi) != 0)doc.getBuffer.delete_(startTi, endTi);
            ti = new TextIter;
            doc.buff.getIterAtMark(ti, preDeleteMark);
            doc.getBuffer.insert(ti, iString);
            
        }
    }
    
}
    
