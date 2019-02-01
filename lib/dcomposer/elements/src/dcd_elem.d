module dcd_elem;

static import std.process;
import std.stdio;
import std.string;
import std.format;
import std.array;
import std.conv;
import std.path;

import dcore;
import ui;
import elements;



extern (C) string GetClassName()
{
     return "dcd_elem.DCD_ELEM";
}

class DCD_ELEM : ELEMENT
{
    private:

    string mServerCommand;
    string mClientCommand;
    string[] mImportPaths;
    static std.process.Pid mServerPID;
    static ushort mPort;

    string[string] TypeName;

    uint mMinChars;

    bool mShutServerDown;

    void SetupTypeNames()
    {
        TypeName["c"] = "Class";
        TypeName["i"] = "Interface";
        TypeName["s"] = "Struct";
        TypeName["u"] = "Union";
        TypeName["v"] = "Variable";
        TypeName["m"] = "Member Variable";
        TypeName["k"] = "D word";
        TypeName["f"] = "Function/Method";
        TypeName["g"] = "Enum";
        TypeName["e"] = "Enum Member";
        TypeName["P"] = "Package";
        TypeName["M"] = "Module";
        TypeName["a"] = "Array";
        TypeName["A"] = "Assoc Array";
        TypeName["l"] = "Alias";
        TypeName["t"] = "Template";
        TypeName["T"] = "Mixin Template";
        TypeName["*"] = "WTF?";
    }

    void WatchForText(void* void_ti, string text, int len, void* void_self)
    {
        if(text.length != 1)
        {
            return;
        }
	    if(DocMan.Current is null) return;
        if((DocMan.Current.WordLength() < mMinChars) && (text[0] != '(') && (text[0] != ')'))return;
        switch (text[0])
        {
            case 'a' : .. case 'z' :
            case 'A' : .. case 'Z' :
            case '0' : .. case '9' :
            case '_' :
            case '.' :
            case '(' : PresentCandidates(); break;
            default  : return;
        }
    }
    
    void WatchImportPaths(PROJECT_EVENT proEvent)
    {
        if(proEvent != PROJECT_EVENT.LISTS) return;

        foreach(path; Project.Lists[LIST_NAMES.IMPORT])
        {
            bool Continue;
            path = path.absolutePath(Project.Folder);
            foreach(alreadyGotIt; mImportPaths)
            {
                if(path == alreadyGotIt.absolutePath(Project.Folder))
                {
                    Continue = true;
                    break;
                }
            }
            if(Continue) continue;
            mImportPaths ~= path;
            Log.Entry("DCD importing '" ~ path ~ "'");
            auto result = std.process.execute([mClientCommand,"-p" ~ mPort.to!string, "-I" ~ path]);
            if(result.status != 0)Log.Entry("DCD failed to add '" ~ path ~ "' to import path.", "Error");  
        }
    }

    void PresentCandidates()
    {
        string[] Candidates;
        string[] Types;
        string[] Output;
        
        int CursorOffset = DocMan.Current.GetCursorByteIndex();
        string arg = format("-c%s",CursorOffset);
        string port = format("-p%s", mPort);

        auto pipes = std.process.pipeProcess([mClientCommand, port, arg]);

    	if(DocMan.Current is null) return;
        {
            scope(failure) return;
            pipes.stdin.writeln(DocMan.Current.GetText());
            pipes.stdin.flush();
            pipes.stdin.close();
            
            std.process.wait(pipes.pid());
            
            foreach(line; pipes.stdout.byLine)
            {
                Output ~= line.idup;
            }
            pipes.stdout.close();
        
        }
        
        
        if(Output.length < 2) return;

        if(Output[0] == "identifiers")
        {
            foreach(index, line; Output[1 .. $])
            {
                auto i = line.indexOf('\t');
                Candidates ~= line[0..i];                
                Types  ~= TypeName[line[i+1..$]];
            }
            uiCompletion.ShowCompletion(Candidates, Types);
        }

        if(Output[0] == "calltips")
        {
            Candidates = Output[1..$];
            uiCompletion.PushCallTip(Candidates);
        }
        
    }


    public:

    string Name(){return "DCD";}
    string Info(){return "Symbol completion using DCD by Brain Schott \"Hackerpilot\"";}
    string Version(){return "00.01";}
    string License(){return "New BSD license";}
    string CopyRight(){return "Anthony Goins © 2015";}
    string[] Authors(){return ["Anthony Goins <neontotem@gmail.com>"];}
    

    void Engage()
    {
        SetupTypeNames();

        mServerCommand = SystemPath(Config.GetValue("dcd_elem", "server_command", "dcd-server"));
        mClientCommand = SystemPath(Config.GetValue("dcd_elem", "client_command", "dcd-client"));
        mImportPaths = Config.GetArray("dcd_elem", "import_paths", ["/usr/include/dmd/phobos", "/usr/include/dmd/druntime"]);
        mPort = Config.GetValue!ushort("dcd_elem", "port_number", 9166);
        mMinChars = Config.GetValue("dcd_elem", "min_char_lookup", 3);
        
        DocMan.Insertion.connect(&WatchForText);
        Project.Event.connect(&WatchImportPaths);
        
        //goto location stuff
        AddIcon("dcd-got", SystemPath(Config.GetValue("dcd_elem", "goto_icon", "elements/resources/target.png")));
        AddAction("ActDcdGoto", "Locate Symbol", "Where is symbol defined", "dcd-got", "F2", 
            delegate void(Action a){Locate();});
        uiContextMenu.AddAction("ActDcdGoto");

        //are we running
        string[] cmd = [mClientCommand];
        cmd ~= "-q";
        cmd ~= format("-p%s", mPort);
        std.typecons.Tuple!(int, "status", string, "output") queryServer;
        try
        {
            queryServer = std.process.execute(cmd);
        }
        catch(Exception x)
        {
            ShowMessage("DCD SERVER ERROR", x.msg);
            Log.Entry("DCD server query failed (check preferences for correct binaries)","Error");
            queryServer.status = 1;
        }
        
        if(queryServer.status ==1) //nope start it up
        {
            mShutServerDown = true;
            try
            {
                string switchPort = format("-p%s",mPort);
                string[] switchImports;
                foreach(I; mImportPaths) switchImports ~= ["-I" ~ I];
                mServerPID = std.process.spawnProcess([mServerCommand] ~ [switchPort] ~  switchImports);
            }
            catch(Exception x)
            {
                mShutServerDown = false;
                ShowMessage("DCD SERVER FAILED TO START", x.msg);
                Log.Entry("Failed to start DCD server.");
                return;
            }
        }
        string eyeports = format("%s", mImportPaths);
        Log.Entry("DCD server running :" ~ format(" @%s ", mPort) ~ eyeports);


        Log.Entry("Engaged :) Are you happy? ");
    }


    void Disengage()
    {
        uiContextMenu.RemoveAction("ActDcdGoto");
        RemoveAction("ActDcdGoto");
        
        
        DocMan.Insertion.disconnect(&WatchForText);
        Project.Event.disconnect(&WatchImportPaths);

        if(mShutServerDown)
        {
            scope(failure)
            {
                Log.Entry("Error Shutting down DCD server", "Error");
                Log.Entry("\tCheck for correct client/server settings in DCD preferences", "Error");
                return;
            }
            string port = format("-p%s", mPort);
            auto stopServer = std.process.execute([mClientCommand] ~ [port] ~ ["--shutdown"]);
            std.process.wait(mServerPID);
            if(stopServer.status == 0)Log.Entry("DCD server shut down.");
            else Log.Entry("Failed to shut down DCD server.");
        }
        else
        {
            Log.Entry("DCD server continuing to run.");
        }
        Log.Entry("Disengaged");
    }

    void Configure()
    {
        mServerCommand = SystemPath(Config.GetValue("dcd_elem", "server_command", "deps/DCD/bin/dcd-server"));
        mClientCommand = SystemPath(Config.GetValue("dcd_elem", "client_command", "deps/DCD/bin/dcd-client"));
        mImportPaths = Config.GetArray("dcd_elem", "import_paths", ["/usr/include/dmd/druntime", "/usr/include/dmd/phobos"]);
        mPort = Config.GetValue!ushort("dcd_elem", "port_number", 9166);
        mMinChars = Config.GetValue("dcd_elem", "min_char_lookup", 3);
    }

    PREFERENCE_PAGE PreferencePage()
    {
        return new DCD_ELEM_PREFERENCE_PAGE;
    }

    static void SetServerPid(std.process.Pid RestartedPid)
    {
        mServerPID = RestartedPid;
    }
    static std.process.Pid ServerPid()
    {
        return mServerPID;
    }

    static void SetPort( ushort newPort)
    {
        mPort = newPort;
    }

    static ushort GetPort()
    {
        return mPort;
    }
    
    void Locate()
    {

        string[] Output;
        
        int CursorOffset = DocMan.Current.GetCursorByteIndex();
        string arg = format("-c%s",CursorOffset);
        string port = format("-p%s", mPort);

        auto pipes = std.process.pipeProcess([mClientCommand, port, arg, "-l"]);

        pipes.stdin.writeln(DocMan.Current.GetText());
        pipes.stdin.flush();
        pipes.stdin.close();
        
        std.process.wait(pipes.pid());
        
        foreach(line; pipes.stdout.byLine)
        {
            Output ~= line.idup;
        }
        pipes.stdout.close();
        
        if(Output.length > 0)
        {
            if (Output[0] == "Not found") return;
            string file;
            int pos;
            formattedRead(Output[0], "%s\t%s",  &file, &pos);
            DocMan.Open(file);
            DocMan.Current.SetCursorByteIndex(pos);
        }           
        
    }
        
}


class DCD_ELEM_PREFERENCE_PAGE : PREFERENCE_PAGE
{
    private:
    FileChooserButton   mServerFile;
    FileChooserButton   mClientFile;
    SpinButton          mMinLookupChars;
    SpinButton          mPort;
    UI_LIST             mDcdImportPaths;
    Button              mRestart;


    void watchList(string title, string[] items)
    {
        Config.SetArray("dcd_elem", "import_paths", items);
    }

    void RestartServer(Button x)
    {

        //collect and create all the damn variables!
        string ServerFile = SystemPath(Config.GetValue!string("dcd_elem", "server_command"));
        string ClientFile = SystemPath(Config.GetValue!string("dcd_elem", "client_command"));
        ushort Port = Config.GetValue!ushort("dcd_elem", "port_number");
        string[] Imports = Config.GetArray!string("dcd_elem", "import_paths");

        string switchPort = format("-p%s", Port);
        string switchOldPort = format("-p%s", DCD_ELEM.GetPort());
        string[] switchImports;
        foreach(I; Imports) switchImports ~= format("-I%s", I);
        foreach(I; Project.Lists[LIST_NAMES.IMPORT]) switchImports ~= format("-I%s",I);

        std.process.Pid newPID;

        //stop the server -- if we didnt start it ...
        try
        {
            auto stopServer = std.process.execute([ClientFile, switchOldPort ,"--shutdown"]);
            if(DCD_ELEM.ServerPid() !is null) std.process.wait(DCD_ELEM.ServerPid());
            if(stopServer.status == 0) Log.Entry("DCD server shutdown");
            else Log.Entry("DCD server shutdown failed");
        }
        catch(Exception x)
        {
            Log.Entry(x.msg);
        }


        //now start it

        try
        {
            newPID = std.process.spawnProcess([ServerFile] ~ [switchPort] ~ switchImports);

        }
        catch(Exception x)
        {
            ui.ShowMessage("Error", x.msg);
            Log.Entry("Failed to restart DCD server", "Error");
            return;
        }
        DCD_ELEM.SetServerPid(newPID);
        DCD_ELEM.SetPort(Port);
        Log.Entry("DCD server restarted " ~ format("(listening at port %s)", Port));
    }

    public:

    this()
    {
        Title = "DCD Element Preferences";

        auto dcdBuilder = new Builder;

        dcdBuilder.addFromFile(ElementPath(Config.GetValue("dcd_elem", "glade_file", "resources/dcd_elem_pref.glade")));

        auto tmp = cast(Grid)dcdBuilder.getObject("grid1");
        mServerFile = cast(FileChooserButton)dcdBuilder.getObject("filechooserbutton1");
        mClientFile = cast(FileChooserButton)dcdBuilder.getObject("filechooserbutton2");
        mMinLookupChars = cast(SpinButton)dcdBuilder.getObject("spinbutton1");
        mPort = cast(SpinButton)dcdBuilder.getObject("spinbutton2");
        mRestart = cast(Button)dcdBuilder.getObject("button1");

        mDcdImportPaths = new UI_LIST("DCD Import Paths", ListType.PATHS);

        mDcdImportPaths.GetRootWidget().setVexpand(true);
        mDcdImportPaths.GetRootWidget().setValign(GtkAlign.FILL);

        tmp.attach(mDcdImportPaths.GetRootWidget(), 0, 4, 2, 2);
        ContentWidget = tmp;

        mServerFile.setFilename(SystemPath(Config.GetValue("dcd_elem", "server_command", "deps/DCD/bin/dcd-server")));
        mClientFile.setFilename(SystemPath(Config.GetValue("dcd_elem", "client_command", "deps/DCD/bin/dcd-client")));
        mMinLookupChars.setValue(Config.GetValue("dcd_elem", "min_char_lookup", 3));
        mPort.setValue(Config.GetValue!ushort("dcd_elem", "port_number", 9166));
        mDcdImportPaths.SetItems(Config.GetArray("dcd_elem", "import_paths", ["/usr/include/dmd/phobos", "/usr/include/dmd/druntime"]));


        mServerFile.addOnFileSet(delegate void(FileChooserButton fcb)
        {
            Config.SetValue("dcd_elem", "server_command", fcb.getFilename());
        });
        mClientFile.addOnFileSet(delegate void(FileChooserButton fcb)
        {
            Config.SetValue("dcd_elem", "client_command", fcb.getFilename());
        });
        mMinLookupChars.addOnValueChanged(delegate void(SpinButton sb)
        {
            Config.SetValue("dcd_elem", "min_char_lookup", sb.getValueAsInt());
        });
        mPort.addOnValueChanged(delegate void(SpinButton sb)
        {
            Config.SetValue("dcd_elem", "port_number", sb.getValueAsInt());
        });

        mDcdImportPaths.connect(&watchList);

        mRestart.addOnClicked(&RestartServer);    
        
        auto label = new Label("Thanks to  Brian 'Hackerpilot' Schott\nfor all his wonderful d tools.");  
        label.setJustify(GtkJustification.CENTER);
        SplashWidget = label;
    }
    ~this()
    {
        mDcdImportPaths.disconnect(&watchList);
    }
}




