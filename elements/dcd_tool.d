module dcd_tool;

import std.conv;
import std.format;
static import std.process;
import std.string;


import qore;
import ui;
import elements;
import document;
import docman;
import ui_docbook;
import ddocconvert;

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
        Transmit.BufferFinishedLoading.connect(&WatchForFinishedLoading);
        Transmit.ProjectEvent.connect(&WatchForProjectImports);
        
        //Goto symbol declaration;
        GActionEntry[] actEntriesLocate = [
            { "actionLocate", &action_locate, null, null, null},
            { "actionDocumentation", &action_documentation, null, null, null}
        ];
        mMainWindow.addActionEntries(actEntriesLocate, cast(void*)this);
        uiApplication.setAccelsForAction("win.actionLocate",["F2"]);
        AddToolObject("locate", "Locate Symbol","Find where symbol is defined.",
            Config.GetResource("icons","locate","resources", "spectacle.png"),"win.actionLocate");
        mContextLocate = AddMenuPart("Locate Symbol", &LocateAction, "win.actionLocate");
        
        //documentation
        mDocsScroll = new ScrolledWindow();
        mDocsLabel = new Label("Documentation");
        mDocsScroll.add(mDocsLabel);
        mDocsScroll.showAll();
        uiApplication.setAccelsForAction("win.actionDocumentation", ["F1"]);
        AddToolObject("documentation", "Symbol Documentation", "Show Doc comments from source",
            Config.GetResource("icons", "Documentation", "resources", "spectacle.png"), "win.actionDocumentation");
        mContextDoc =  AddMenuPart("Documentation", &DocumentationAction, "win.actionDocumentation");
        
        StartServer();
        AddExtraPane(mDocsScroll, "Documentation");
        
        
        Log.Entry("Engaged");
    }
    void Mesh()
    {
        
        Log.Entry("Meshed");
    }
    void Disengage()
    {
        
        mMainWindow.removeAction("actionLocate");
        mMainWindow.removeAction("actionDocumentation");
        RemoveToolObject("locate");
        RemoveToolObject("Documentation");
        RemoveExtraPaneWidget(mDocsScroll);
        RemoveMenuPart(mContextDoc);
        RemoveMenuPart(mContextLocate);
        StopServer();
        //Transmit.ProjectEvent.disconnect(&WatchForProjectImports);
        Transmit.BufferFinishedLoading.disconnect(&WatchForFinishedLoading);
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
    MENU_PARTS  mContextDoc;
    MENU_PARTS  mContextLocate;
    
    ScrolledWindow mDocsScroll;
    Label          mDocsLabel;
    
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
        mDcomposerStartedServer = true;
        //rv = std.process.execute([mServer, " --logLevel=error"]);
       std.process.spawnProcess([mServer, "--logLevel=error"], null, std.process.Config.detached);
       
    }
    
    void AddImportPaths(string[] ipaths)
    {
        foreach(imp; ipaths)
        {
            std.process.execute([mClient, "-I"~imp]);
        }
    }
    
    void WatchForFinishedLoading(string fullFilePath)
    {
        if(fullFilePath !in WaitingLoads) return;
        GetDoc(fullFilePath).GotoByteOffset(WaitingLoads[fullFilePath]);
        WaitingLoads.remove(fullFilePath);
    }
    
    void WatchForInsert(DOC_IF Doc, TextIter ti, string text)
    {
        int minLen;
        if(text.length != 1) return;
        
        if(text == "(")
        {
            ProcessCallTip(Doc);
            return;
        }
        
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
            default : return;
        }
                    
    }
    
    void WatchForProjectImports(PROJECT project, PROJECT_EVENT event, string key)
    {
        if(key != LIST_KEYS.IMPORT_PATHS) return;
        AddImportPaths(project.List(key));   
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
                candidates ~= line[0..tabPosition].idup;
                info ~= line[tabPosition .. $-1].idup;
            }
            indx++;
        }
        auto rv = std.process.wait(pipes.pid);
        if(candidates.length < 1) return;
        uiCompletion.ShowCompletion(Doc, candidates, info);
    }
    
    void ProcessCallTip(DOC_IF Doc)
    {
        string[] candidates;   
        auto pipes = std.process.pipeProcess([mClient, "-c"~Doc.Offset().to!string]);
        
        pipes.stdin.write(Doc.Text);
        pipes.stdin.flush();
        pipes.stdin.close();
        
        int indx = 0;
        foreach(char[] line; pipes.stdout.byLine())
        {
            if(indx == 0)
            {
                if(line != "calltips") return;
                indx++;
                continue;
            }
            if(line.length)
            {
                candidates ~= line.idup;
            }
            indx++;
        }
        
        auto rv = std.process.wait(pipes.pid);
        if(candidates.length < 1) return;
        uiCompletion.PushCallTip(Doc, candidates);
        
    }

    void LocateAction(MenuItem mi)
    { 
        action_locate(null,null, cast(void*)this);
    }
    
    void DocumentationAction(MenuItem mi)
    {
        action_documentation(null, null, cast(void*)this);
    }
        
}

int[string] WaitingLoads;
extern (C)
{
    void action_locate(void* simAction, void* varTarget, void* voidUserData)
	{   

    	DCD_TOOL dcd = cast (DCD_TOOL)voidUserData;
        DOC_IF Doc = GetCurrentDoc();
        std.process.ProcessPipes pipes = std.process.pipeProcess([dcd.mClient, "-c"~Doc.Offset().to!string, "-l"]);

        pipes.stdin.write(Doc.Text);
        pipes.stdin.flush();
        pipes.stdin.close();
        string[] output;
        foreach (line; pipes.stdout.byLine) output ~= line.idup;
        
        std.process.wait(pipes.pid);
        if(output.length < 1) return;
        if(output[0] == "Not found") return;
        string file;
        int pos;
        formattedRead(output[0], "%s\t%s", file, pos);
        if(file == "stdin")file = Doc.FullName;
        
        if(Opened(file))
        {
            GetDoc(file).Goto(pos);
            return;
        }        
        docman.OpenDocAt(file,0,0);
        WaitingLoads[file] = pos;        
	}
	
	void action_documentation(void* simAction, void* varTarget, void* voidUserData)
	{       
    	DCD_TOOL dcd = cast (DCD_TOOL)voidUserData;
        DOC_IF Doc = GetCurrentDoc();
        std.process.ProcessPipes pipes = std.process.pipeProcess([dcd.mClient, "-c"~Doc.Offset().to!string, "-d"]);

        pipes.stdin.write(Doc.Text);
        pipes.stdin.flush();
        pipes.stdin.close();
        string[] output;
        foreach (line; pipes.stdout.byLine) output ~= myEncode(line.idup);
        
        string fullDocs;
        foreach(doc; output)
        {
            import std.regex;
            //auto reallines = regex(r"(?<=[^\\])(\\n)","g");
            //fullDocs ~= Ddoc2Pango(doc.replaceAll(reallines, "\n")) ~ "\n";
            fullDocs ~= doc ~ "\n";
        }
        dcd.mDocsLabel.setMarkup(fullDocs);
	}
}
