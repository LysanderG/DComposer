module curly_indent;

import std.string;
import std.uni;

import qore;
import ui;
import elements;
import document;

extern(C) string GetElementName()
{
    return "curly_indent.CURLY_INDENT";
}


class CURLY_INDENT : ELEMENT
{

    void Engage()
    {
        mCurlyClose = Config.GetValue("element","curly_indent_close", true);
        
        mPrefDialog = new Dialog("Curly Indent Preferences", mMainWindow, DialogFlags.MODAL,["Finished"],[ResponseType.CLOSE]);
        CheckButton cb = new CheckButton("Auto Close Curly Brace?", delegate void(CheckButton cbtn)
        {
            mCurlyClose = cbtn.getActive();
            Config.SetValue("element","curly_indent_close", mCurlyClose);
            Configure();
        });
        cb.setActive(true);
        cb.showAll();
        mPrefDialog.getContentArea.packStart(cb, true, true, 3);
        Configure();
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
        destroy(mPrefDialog);
        Log.Entry("Disengaged");        
    }

    void Configure()
    {
        mCurlyClose = Config.GetValue("element", "curly_indent_close", true);
        Log.Entry("Configure");
    }

    string Name(){return "Curly Brackets".idup;}
    string Info(){return "Indents curly brackets... or braces(whatever)".idup;}
    string Version(){return "0.00".idup;}
    string License(){return "to be determined".idup;}
    string CopyRight(){return "2021 Anthony Goins".idup;}
    string Authors(){return "Lysander".idup;}

    Dialog SettingsDialog()
    {

        return mPrefDialog;
    }
    
    /*void WatchForText_old(DOC_IF self, TextIter ti, string text)
    {
        if(text.length > 1) return;
        DOCUMENT doc = cast(DOCUMENT)self;
        TextIter startTi = ti.copy();
        TextIter endTi = ti.copy();
        
        scope(exit)
        {
            ti = new TextIter;
            doc.getBuffer.getIterAtMark(ti, doc.getBuffer.getMark("transmitInsert"));
            doc.getBuffer.getIterAtMark(endTi, doc.getBuffer.getMark("transmitInsert"));            
            doc.getBuffer.getIterAtMark(startTi, doc.getBuffer.getMark("transmitInsert"));            
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
            if(!FindMatchingBrace(ti, OpenBracketLineStart))return;
            
            //find line with matching bracket
            //OpenBracketLineStart = ti.copy();
            //int counter = 0;
            //while(OpenBracketLineStart.backwardChar())
           // {
            //    assert(OpenBracketLineStart.getChar() != 0);
            //    dwrite(OpenBracketLineStart.getChar(), " ", counter);
            //    if(OpenBracketLineStart.getChar() == '}') counter++;
            //    if(OpenBracketLineStart.getChar() == '{') counter--;
            //    if(counter == 0) break;
            //}
            //get the 'indentation' string oblstart and oblend
            OpenBracketLineStart.setLineOffset(0);
            OpenBracketLineEnd = OpenBracketLineStart.copy();
            bool moveBack;
            while((OpenBracketLineEnd.getChar == ' ') || (OpenBracketLineEnd.getChar == '\t'))
            {
                OpenBracketLineEnd.forwardChar();
                moveBack = true;
            }
            if(moveBack)OpenBracketLineEnd.backwardChar(); 
            
            string iString = doc.getBuffer.getText(OpenBracketLineStart, OpenBracketLineEnd, true);
            dwrite("lines? ", OpenBracketLineStart.getLine, "/",OpenBracketLineEnd.getLine);
            dwrite ("from:",OpenBracketLineStart.getLineOffset, " to:",OpenBracketLineEnd.getLineOffset);
            dwrite("ident size = ",iString.length);
            //if(iString.length == 0) return;
            //delete current
            endTi = startTi.copy();
            moveBack = false;
            while((endTi.getChar() == ' ') || (endTi.getChar() == '\t'))
            {
                endTi.forwardChar();
                moveBack = true;
            }
            if(moveBack)endTi.backwardChar();
            if(OpenBracketLineEnd.getLineOffset() == 0) endTi.forwardChar();
            doc.getBuffer.delete_(startTi, endTi);
            ti = new TextIter;
            doc.buff.getIterAtMark(ti, doc.buff.getMark("transmitInsert"));
            if(iString.length == 0)return;
            ti.backwardChar();
            doc.getBuffer.insert(ti, iString);
            dwrite("ok");
            doc.getBuffer.getIterAtMark(OpenBracketLineEnd, doc.getBuffer.getMark("transmitInsert"));
            doc.getBuffer.getIterAtMark(OpenBracketLineStart, doc.getBuffer.getMark("transmitInsert"));
        }
    }*/
    
    void WatchForText(DOC_IF docIf, TextIter ti, string text)
    {
        auto doc = cast(DOCUMENT)docIf;
        SetValidationMark(doc, ti);
        scope(exit)
        {

            ValidateTextIters(doc, ti);
        }
        if(text == "\n")
        {
            scope TextIter lastTi;
            lastTi = ti.copy();
            lastTi.backwardLine();               
            string lastline = doc.GetLineText(lastTi);
            lastline = lastline.stripRight();
            if(lastline.length < 1)return;
            if(lastline[$-1] != '{')return;            
            AddIndentationLevel(doc, ti);
            
            ValidateTextIters(doc, ti);
            if(mCurlyClose)
            {
                int ctr = 0;
                string ws;
                while(lastline[ctr++] == ' ')ws ~= " ";
                ws = "\n" ~ ws ~ "}";
                doc.buff.insert(ti, ws);
                ti.backwardChars(cast(int)ws.length);
                doc.buff.placeCursor(ti);
                SetValidationMark(doc, ti);
            }
            return;            
        }
        //==================================================
        if(text == "}")
        {
            
            if(mCurlyClose)
            {
                TextIter skipCloseTi = ti.copy();
                scope TextIter deleteAnchorTi = ti.copy();
                while(skipCloseTi.forwardChar())
                {
                    dwrite("continue ", skipCloseTi.getChar());
                    if(isWhite(skipCloseTi.getChar()))continue;
                    if(skipCloseTi.getChar() == '}')
                    {
                        skipCloseTi.forwardChar();
                        doc.buff.createMark("xxx", skipCloseTi, false);
                        ti.backwardChar();
                        doc.buff.delete_(ti, deleteAnchorTi);
                        doc.buff.getIterAtMark(ti, doc.buff.getMark("xxx"));
                        doc.buff.placeCursor(ti);
                        dwrite(ti.getLine());
                        //dwrite(skipCloseTi.getLine());
                        return;
                    }
                    break;
                }
            }
            if(stripLeft(GetLineText(doc, ti))[0] != '}')return;
            doc.unindentLines(ti, ti);
        }
    }
    
private:
    bool mCurlyClose;
    Dialog mPrefDialog;
    
}
        
