module braceindent_elem;

import elements;
import dcore;
import ui;
import document;
import ui_preferences;

import gtk.TextIter;
import gtk.TextMark;
import gtk.TextBuffer;


import std.string;
import std.range;
import std.uni;
import std.algorithm:canFind;


extern (C) string GetClassName()
{
    return "braceindent_elem.BRACE_INDENT";
}


class BRACE_INDENT : ELEMENT
{
    private :

    int mIndentationSize;
    bool mUseSpaces;
    char[] mIndentationSpaces;

    void ConfigChanged(string Sec, string Name)
    {
        Configure();
    }

    void WatchForTextInsertion(void* void_ti, string text, int len, void* void_self)
    {
        auto ti = cast(TextIter)void_ti;
        auto self = cast(SourceBuffer)void_self;

        string OpenLineText;
        string CloseLineText;

        auto tiCloneForStarting = new TextIter;
        tiCloneForStarting = ti.copy();
        auto tiForEndings = new TextIter;

        if(text == "\n")
        {
            //save the current iter or things get really screwy
            auto saveTIMark = new TextMark("saveTI", 1);
            saveTIMark = self.createMark("saveTI", ti, 1);

            scope(exit)
            {
                self.getIterAtMark(ti, saveTIMark);
                self.deleteMark(saveTIMark);
            }


            //get openlinetext
            tiCloneForStarting.backwardLine();
            tiForEndings = tiCloneForStarting.copy();
            tiForEndings.forwardToLineEnd();
            OpenLineText = self.getText(tiCloneForStarting, tiForEndings, false);
            //see if last non white space char is an open brace "{"
            string strippedRightOpenLineText = OpenLineText.stripRight();
            if(strippedRightOpenLineText.length < 1) return;
            if(strippedRightOpenLineText[$-1] != '{') return;
            //add some spaces
            string indentwhitespaces;
            if(mUseSpaces)foreach(i; iota(mIndentationSize)) indentwhitespaces ~= " ";
            else indentwhitespaces = "\t";
            self.insert(ti, indentwhitespaces);
            return;
        }

        if(text == "}")
        {
            //save the current iter or things get really screwy
            auto saveTIMark2 = new TextMark("saveTI2", 1);
            self.addMark(saveTIMark2, ti);

            scope(exit)
            {
                self.getIterAtMark(ti, saveTIMark2);
                self.deleteMark(saveTIMark2);
            }

            //is this "}" first non whitespace on line
            tiCloneForStarting.backwardChar();
            while(tiCloneForStarting.getLineOffset() > 0)
            {
                tiCloneForStarting.backwardChar();
                if(tiCloneForStarting.getChar().isSpace() || tiCloneForStarting.getChar.isWhite())continue;

                //there are none whitespace characters between our } and line start so lets ignore indentation
                else return;
            }

            //now tiCloneForStarting should be at line offset zero
            //so lets set tiForEndings to the end
            tiForEndings = tiCloneForStarting.copy();
            tiForEndings.forwardToLineEnd();
            //and the actual text for the line with our }
            CloseLineText = self.getText(tiCloneForStarting, tiForEndings, false);


            //finding the matching open brace
            auto tiMatchOpenBrace = ti.copy();
            int braceCtr = 0;
            do
            {
                auto moved = tiMatchOpenBrace.backwardChar();
                if(moved == 0) return; //aint no match ... unbalanced braces (at least up to our }) so bail
                if(self.getContextClassesAtIter(tiMatchOpenBrace).canFind("string","comment")) continue;
                if(tiMatchOpenBrace.getChar == '}') braceCtr++;
                if(tiMatchOpenBrace.getChar == '{') braceCtr--;
            }while(braceCtr > 0);

            //still here? then tiMatchOpenBrace is on the matching brace :)

            //ok lets get the whole text of the line matching brace is on
            auto tiMatchEndLine = tiMatchOpenBrace.copy();
            tiMatchEndLine.forwardToLineEnd();
            tiMatchOpenBrace.setLineOffset(0);
            OpenLineText = self.getText(tiMatchOpenBrace, tiMatchEndLine, false);

            //here is the indentation (aka starting whitespace right?)
            string OpenLineTextIndentChars;
            foreach(ch; OpenLineText) 
                if (ch.isWhite ||  ch.isSpace) OpenLineTextIndentChars ~= ch;
                else break;
            auto IndentedColOpen = OpenLineTextIndentChars.column(mIndentationSize); //should not this be tab_width ??

            string CloseLineTextIndentChars;
            foreach(ch; CloseLineText) if (ch.isWhite || ch.isSpace) CloseLineTextIndentChars ~= ch;
            auto IndentedColClose = CloseLineTextIndentChars.column(mIndentationSize);

            auto tmpMark = new TextMark("brace_tmp", 1);
            self.addMark(tmpMark, tiCloneForStarting);


            ti.backwardChar();

            self.delet(tiCloneForStarting, ti);

            tiCloneForStarting = new TextIter;
            self.getIterAtMark(tiCloneForStarting, tmpMark);
            if(OpenLineTextIndentChars.length > 0)self.insert(tiCloneForStarting, OpenLineTextIndentChars);

            self.deleteMark(tmpMark);
            return;
        }
    }



    public :

    string Name(){return "Brace Indentation";}
    string Info(){return "Simply adds a level of indentation following a line ending with '{'.  And removes one level of indentation on a line beginning with '}'";}
    string Version() {return "00.01";}
    string CopyRight() {return "Anthony Goins © 2014";}
    string License() {return "New BSD license";}
    string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}


    void Configure()
    {

        mIndentationSize = Config.GetValue("document", "indentation_width", 4);

        mUseSpaces = Config.GetValue("document", "spaces_for_tabs", false);

        mIndentationSpaces.length = mIndentationSize;
        mIndentationSpaces[] = ' ';
    }


    void Engage()
    {
        Configure();
        Config.Changed.connect(&ConfigChanged);
        DocMan.Insertion.connect(&WatchForTextInsertion);
        Log.Entry("Engaged");
    }



    void Disengage()
    {
        mIndentationSize = 0;
        mUseSpaces = false;
        DocMan.Insertion.disconnect(&WatchForTextInsertion);
        Config.Changed.disconnect(&ConfigChanged);
        Log.Entry("Disengaged");
    }

    PREFERENCE_PAGE PreferencePage() {return null;}
}
