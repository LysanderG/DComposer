module dcd_tool;

import std.conv;
import std.format;
static import std.process;
import std.string;


import qore;
import ui;
import elements;
extern(C) string GetElementName()
{
    return "dcd_tool.DCD_TOOL";
}

class DCD_TOOL: ELEMENT
{
    void Engage()
    {
        mServer = Config.GetValue("element_dcd_tool", "server", "dcd-server".idup);
        mClient = Config.GetValue("element_dcd_tool", "client", "dcd-client".idup);
        mImportPaths = Config.GetArray("element_dcd_tool", "import_paths", ["/usr/include/dmd/phobos".idup, "/usr/include/dmd/druntime".idup]);
        mMinChars = Config.GetValue("element_dcd_tool", "min_char_lookup", 3);
        
        
        Transmit.DocInsertText.connect(&WatchForInsert);
        //Transmit.ProjectEvent.connect(&WatchForProjectImports);
        
        StartServer();    
        Log.Entry("Engaged");
    }
    void Mesh()
    {
        Log.Entry("Meshed");
    }
    void Disengage()
    {
        StopServer();
        //Transmit.ProjectEvent.disconnect(&WatchForProjectImports);
        Transmit.DocInsertText.disconnect(&WatchForInsert);
        Log.Entry("Disengaged");
    }

    void Configure()
    {
    }

    string Name()
    {
        return "dcd_tools".idup;
    }
    string Info()
    {
        return "Auto completion, call tips, go to definition, Documentation".idup;
    }
    string Version()
    {
        return "unversioned".idup;
    }
    string License()
    {
        return "unspecified".idup;
    }
    string CopyRight()
    {
        return "Anthony Goins © 2021".idup;
    }
    string Authors()
    {
        return "Anthony Goins".idup;
    }

    Dialog SettingsDialog()
    {
        return new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.INFO, ButtonsType.CLOSE, "nothing to see here.");
    }
    
    private:
    
    
    string      mServer;
    string      mClient;
    string[]    mImportPaths;
    int         mMinChars;
    bool        mDcomposerStartedServer;
    
    void StopServer()
    {
        if(mDcomposerStartedServer)
            std.process.execute([mClient, "--shutdown"]);
    }
    
    void StartServer()
    {
        auto rv = std.process.execute([mClient, "--query"]);
        if(rv.status == 0)
        { 
            mDcomposerStartedServer = false;
            return;
        }
        rv = std.process.execute([mServer, " --logLevel=error"]);
    }
    
    void WatchForInsert(DOC_IF Doc, TextIter ti, string text)
    {
        int minLen;
        if(text.length != 1) return;
        if(text == ".") minLen = 0;
        else minLen = mMinChars;
        
        if(Doc.IdentifierStart().length < minLen)return;
        
        switch(text[0])
        {
            case 'a': .. case 'z':
            case 'A': .. case 'Z':
            case '0': .. case '9':
            case '_': ProcessCompletion(Doc); break;
            case '.': ProcessCompletion(Doc); break;
            case '(': //for calltip
            default : return;
        }
            
        
    }
    
    
    void ProcessCompletion(DOC_IF Doc)
    {
        string[] candidates;     
        string[] info;   
        auto pipes = std.process.pipeProcess([mClient, "-c"~Doc.Offset().to!string]);
        
        pipes.stdin.write(Doc.Text);
        pipes.stdin.flush();
        pipes.stdin.close();
        
        int indx = 0;
        foreach(char[] line; pipes.stdout.byLine())
        {
            if(indx == 0)
            {
                if(line != "identifiers") return;
                indx++;
                continue;
            }
            if(line.length)
            {
                ptrdiff_t tabPosition = indexOf(line, '\t');
                dwrite(line, "..",tabPosition);
                candidates ~= line[0..tabPosition].idup;
                info ~= line[tabPosition .. $-1].idup;
            }
            indx++;
        }
        dwrite("c: ",candidates);
        
        auto rv = std.process.wait(pipes.pid);
        if(candidates.length < 1) return;
        uiCompletion.ShowCompletion(Doc, candidates, info);
    }
        
}
