module doc_utils;

import qore;
import ui;
import document;


//stuff I want
//---------------
//setValidMark
//validateTextIters
//find matching {} () [] 
//get indent level
//get line text
//get line number
//get column number
//get identifier
//go/delete/select  next object (ObjX.start, ObjX.end)
//go/delete/select  prev object
//get  selection text
//get  selection range


immutable ValidationMark = "validationMark";
void SetValidationMark(DOCUMENT doc, TextIter ti)
{
    auto tm = doc.buff.getMark(ValidationMark);
    if(tm is null) doc.buff.createMark(ValidationMark, ti, false);
    else doc.buff.moveMarkByName(ValidationMark, ti);
}

void ValidateTextIters(DOCUMENT doc, TextIter[] iters...)
{
    foreach(ref TextIter ti; iters)
    {
        ti = new TextIter;
        doc.buff.getIterAtMark(ti, doc.buff.getMark(ValidationMark));
    }
}



string GetLineText(DOCUMENT doc, TextIter lineTi)
{
    scope TextIter lineEndTi;
    scope TextIter lineStartTi;
    lineStartTi = lineTi.copy();
    lineEndTi = lineTi.copy();
    lineStartTi.setLineOffset(0);
    lineEndTi.forwardToLineEnd();
    string rv = doc.buff.getText(lineStartTi, lineEndTi, true);
    return rv;
}


bool FindMatchingBrace(DOCUMENT doc, TextIter ti, out TextIter match)
{
    dchar toMatch;
    dchar fromChar = ti.getChar();
    switch (fromChar)
    {
        case '{' : return doc.FindClosing("{}", ti, match);
        case '}' : return doc.FindOpening("}{", ti, match);
        case '(' : return doc.FindClosing("()", ti, match);
        case ')' : return doc.FindOpening(")(", ti, match);
        case '[' : return doc.FindClosing("[]", ti, match);
        case ']' : return doc.FindOpening("][", ti, match);
        default  : return false;
    }
}

bool FindClosing(DOCUMENT doc, dchar[2] gate, TextIter ti, out TextIter match)
{
    int counter;
    dchar checker;
    match = ti.copy();    
    do
    {
           checker = match.getChar();
           if (checker == 0) return false;
           if(checker == gate[0]) counter++;
           if(checker == gate[1]) counter--;
           if(counter == 0) return true;           
    } while(match.forwardChar());
    return false;    
}

bool FindOpening(DOCUMENT doc, dchar[2] gate, TextIter ti, out TextIter match)
{
    int counter;
    dchar checker;
    match = ti.copy();
    do
    {
        checker = match.getChar();
        if(checker == gate[0]) counter++;
        if(checker == gate[1]) counter--;
        if(counter == 0) return true;
    }while(match.backwardChar());
    return false;
}

int GetLineIndentationLevel(DOCUMENT doc, TextIter lineTi)
{
    lineTi.setLineOffset(0);
    while((lineTi.getChar() == ' ') || (lineTi.getChar() == '\t'))
        lineTi.forwardChar();
    return lineTi.getLineOffset()/doc.getIndentWidth(); //i predict problems with this     
}

@disable void SetLineIndentation(DOCUMENT doc, TextIter lineTi, int indentationLevel)
{
    string istring;
    TextIter sameLineTi = lineTi.copy();
    SetValidationMark(doc, lineTi);
    lineTi.setLineOffset(0);
    auto oldIndent = GetLineIndentationLevel(doc, lineTi);
    foreach(ctr; 0..oldIndent)doc.unindentLines(lineTi, sameLineTi);
    dwrite(oldIndent,"/",indentationLevel*4);
    foreach(ctr; 0..(indentationLevel*4))istring ~= " ";
    doc.buff.insert(lineTi, istring);
    ValidateTextIters(doc, lineTi, sameLineTi);
}

void AddIndentationLevel(DOCUMENT doc, TextIter ti)
{
    SetValidationMark(doc, ti);
    doc.buff.insert(ti, "    ");
    ValidateTextIters(doc, ti);
    
}
