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
        mCurlyClose = Config.GetValue("element".idup,"curly_indent_close".idup, true);
        
        mPrefDialog = new Dialog("Curly Indent Preferences", mMainWindow, DialogFlags.MODAL,["Finished"],[ResponseType.CLOSE]);
        CheckButton cb = new CheckButton("Auto Close Curly Brace?", delegate void(CheckButton cbtn)
        {
            mCurlyClose = cbtn.getActive();
            Config.SetValue("element".idup,"curly_indent_close".idup, mCurlyClose);
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
        mCurlyClose = Config.GetValue("element".idup, "curly_indent_close".idup, true);
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
                    if(isWhite(skipCloseTi.getChar()))continue;
                    if(skipCloseTi.getChar() == '}')
                    {
                        skipCloseTi.forwardChar();
                        doc.buff.createMark("xxx", skipCloseTi, false);
                        ti.backwardChar();
                        doc.buff.delete_(ti, deleteAnchorTi);
                        doc.buff.getIterAtMark(ti, doc.buff.getMark("xxx"));
                        doc.buff.placeCursor(ti);

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
        
