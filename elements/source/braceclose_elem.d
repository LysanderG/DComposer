module braceclose;

import dcore;
import elements;
import document;

import std.uni;

import gtk.TextMark;
import gtk.TextIter;
import gdk.Keysyms;



extern (C) string GetClassName()
{
    return "braceclose.BRACE_CLOSE";
}

class BRACE_CLOSE: ELEMENT
{
    private:

    bool CloseParens;
    bool CloseBracket;
    bool CloseAngle;
    
    void WatchForKeyDown(uint keyval, uint keymod)
    {
        if(DocMan.IsDocumentKeyPressBlocked()) return;
        switch (keyval)
        {
            
            case GdkKeysyms.GDK_bracketleft:
            {
                dwrite("okay [");
                if(!CloseBracket)return;
                DocMan.SetBlockDocumentKeyPress();
                auto self = DocMan.Current();                
                self.InsertText("[]");
                self.MoveLeft(1, false);            
                return; 
            }
            case GdkKeysyms.GDK_bracketright:
            {
                if(!CloseBracket)return;
                Close(']');
                return;
            }
            case GdkKeysyms.GDK_less:
            {
                dwrite("okay <");
                if(!CloseAngle)return;
                DocMan.SetBlockDocumentKeyPress();
                auto self = DocMan.Current();                
                self.InsertText("<>");
                self.MoveLeft(1, false);            
                return; 
            }
            case GdkKeysyms.GDK_greater:
            {
                if(!CloseAngle)return;
                Close('>');
                return;
            }

            case 40: //(
            {
                if(!CloseParens)return;
                DocMan.SetBlockDocumentKeyPress();
                auto self = DocMan.Current();                
                self.InsertText(")");
                self.MoveLeft(1, false);
                self.InsertText("(");            
                return; 
            }
            case 41: //)
            {
                if(!CloseParens)return;
                Close(')');
                return;
            }
            case 123 : //{
            {
                DocMan.SetBlockDocumentKeyPress();
                auto self = DocMan.Current();                
                self.InsertText("{}");
                self.MoveLeft(1, false);            
                return;   
            }
            case 125: //}
            {
                Close('}');
                return;
            }
            default : return;
        }
        
    }

    void Close(char closeChar)
    {
        auto self = cast (DOCUMENT)DocMan.Current();
        auto lineTi = self.Cursor();
        
        if(self.GetChar() != closeChar) return;
        DocMan.SetBlockDocumentKeyPress();                
        self.MoveRight(1, false);
        lineTi.backwardChar();
        while(lineTi.getLineOffset() > 0)
        {
            lineTi.backwardChar();
            if(lineTi.getChar().isSpace() || lineTi.getChar.isWhite())continue;
            //there are no whitespace characters between our } and line start so lets ignore indentation
            else return;
        }
        self.UnIndentLines(1);
        return;
    }

    public:
    
    void Engage()
    {
        CloseParens = Config.GetValue("brace_close", "close_parens", true);
        CloseAngle = Config.GetValue("brace_close", "close_angles", true);
        CloseBracket = Config.GetValue("brace_close", "close_brackets", true);
        DocMan.DocumentKeyDown.connect(&WatchForKeyDown);
        Log.Entry("Engaged");
    }
    void Disengage()
    {
        DocMan.DocumentKeyDown.disconnect(&WatchForKeyDown);
        Log.Entry("Disengaged");
    }

    void Configure()
    {
        CloseParens = Config.GetValue("brace_close", "close_parens", true);
        CloseAngle = Config.GetValue("brace_close", "close_angles", true);
        CloseBracket = Config.GetValue("brace_close", "close_brackets", true);
    }

    string Name(){return "Auto brace close";}
    string Info(){return `Automatically adds a closing character to brace after the cursor`;} 
    string Version(){return "00.01";}
    string License(){return "unknown";}
    string CopyRight(){return "Anthony Goins © 2018";}
    string[] Authors(){return ["Anthony Goins <neontotem@gmail.com>"];}

    PREFERENCE_PAGE PreferencePage()
    {
        return new BRACE_CLOSE_PREFERENCE_PAGE;
    }
}

final class BRACE_CLOSE_PREFERENCE_PAGE : PREFERENCE_PAGE
{
    import gtk.ToggleButton;
    import gtk.CheckButton;
    import gtk.Label;
    import gtk.Box;

    CheckButton Parens;
    CheckButton Angles;
    CheckButton Brackets;
    Label       ALittleHelp;


    this()
    {
        ALittleHelp = new Label("Also Close ...");

        Parens = new CheckButton("Parenthesis");
        Angles = new CheckButton("Angle Brackets (actually just greater and less than characters)");
        Brackets = new CheckButton("Brackets");

        Parens.setActive(Config.GetValue("brace_close", "close_parens", false));
        Angles.setActive(Config.GetValue("brace_close", "close_angles", false));
        Brackets.setActive(Config.GetValue("brace_close", "close_brackets", false));

        Parens.addOnToggled(delegate void(ToggleButton Checked)
        {
            Config.SetValue("brace_close", "close_parens", Checked.getActive());
        });
        
        Angles.addOnToggled(delegate void(ToggleButton Checked)
        {
            Config.SetValue("brace_close", "close_angles", Checked.getActive());
        });
        
        Brackets.addOnToggled(delegate void(ToggleButton Checked)
        {
            Config.SetValue("brace_close", "close_brackets", Checked.getActive());
        });

        Title = "Brace Close Preferences";
        auto Content = new Box(GtkOrientation.VERTICAL, 3);

        Content.packStart(ALittleHelp , 1, 1, 1);
        Content.packStart(Parens , 1, 1, 1);
        Content.packStart(Angles , 1, 1, 1);
        Content.packStart(Brackets , 1, 1, 1);

        ContentWidget = Content;
        ContentWidget.showAll();
    }
}
