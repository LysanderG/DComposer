module braceclose;

import dcore;
import elements;
import document;

import std.uni;

import gtk.TextMark;
import gtk.TextIter;




extern (C) string GetClassName()
{
    return "braceclose.BRACE_CLOSE";
}

class BRACE_CLOSE: ELEMENT
{
    private:
    
    void WatchForKeyDown(uint keyval, uint keymod)
    {
	if(DocMan.IsDocumentKeyPressBlocked()) return;
        switch (keyval)
        {
            case 123 :
            {
                DocMan.SetBlockDocumentKeyPress();
                auto self = DocMan.Current();                
                self.InsertText("{}");
                self.MoveLeft(1, false);            
                return;   
            }
            case 125:
            {
                auto self = cast(DOCUMENT)DocMan.Current();
                auto lineTi = self.Cursor();
                
                if(self.GetChar() != '}') return;
                DocMan.SetBlockDocumentKeyPress();                
                self.MoveRight(1, false);
                lineTi.backwardChar();
                while(lineTi.getLineOffset() > 0)
                {
                    lineTi.backwardChar();
                    if(lineTi.getChar().isSpace() || lineTi.getChar.isWhite())continue;
                    //there are none whitespace characters between our } and line start so lets ignore indentation
                    else return;
                }
                
                self.UnIndentLines(1);
                return;
            
            }
            
            default : return;
        }
        
        
    }
    
    void WatchForText2(void* void_ti, string text, int len, void* void_self)
    {
      
        switch(text)
        {
            case "{":
            {
                DocMan.SetBlockDocumentKeyPress();
                auto ti = cast(TextIter)void_ti;
                auto ti2 = new TextIter;
                ti2 = ti.copy();
                auto self = cast(SourceBuffer)void_self;
        
                auto saveTiMark = new TextMark("saveTix", 1);
                saveTiMark = self.createMark("saveTix", ti, 1);   
                
                self.insert(ti, "}"); 
                ti2 = ti.copy(); 
                ti2.backwardChar();  
                self.placeCursor(ti2);
                
                self.getIterAtMark(ti, saveTiMark);
                self.deleteMark(saveTiMark);
                return;
            }
            case "}":
            {
                auto self = cast(DOCUMENT)void_self;
  
                self.MoveRight(2, true);
                //self.ReplaceSelection("");
                //self.MoveRight(1,false);
                /*DocMan.SetBlockDocumentKeyPress();
                auto ti = cast(TextIter)void_ti;
                auto ti2 = new TextIter;
                ti2 = ti.copy();
                auto self = cast(SourceBuffer)void_self;
        
                auto saveTiMark = new TextMark("saveTix", 1);
                saveTiMark = self.createMark("saveTix", ti, 1); 
                if(saveTiMark is null)
                {
                    dwrite(ti, ti2);   
                    return;
                }
                
                ti.backwardChar();
                if(ti2.getChar() == '}')
                {
                    self.backspace(ti2, 0, 1);
                    
                    self.getIterAtMark(ti,saveTiMark);                   
                    ti2.forwardChar();
                    self.placeCursor(ti2);
                    
                    self.getIterAtMark(ti, saveTiMark);
                    self.deleteMark(saveTiMark);                    
                }*/
                
                return;     
            }
            default : return;
        }
 
     }

    public:
    
    void Engage()
    {
        //DocMan.Insertion.connect(&WatchForText2);
        DocMan.DocumentKeyDown.connect(&WatchForKeyDown);
        Log.Entry("Engaged");
    }
    void Disengage()
    {
        //DocMan.Insertion.disconnect(&WatchForText2);
        DocMan.DocumentKeyDown.disconnect(&WatchForKeyDown);
        Log.Entry("Disengaged");
    }

    void Configure(){}

    string Name(){return "Auto brace close";}
    string Info(){return `Automatically adds a closing character to brace after the cursor`;} 
    string Version(){return "00.01";}
    string License(){return "unknown";}
    string CopyRight(){return "Anthony Goins © 2018";}
    string[] Authors(){return ["Anthony Goins <neontotem@gmail.com>"];}

    PREFERENCE_PAGE PreferencePage(){return null;}
}
