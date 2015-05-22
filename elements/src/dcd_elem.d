module dcd_elem;

static import std.process;
import std.stdio;
import std.string;
import std.array;


import dcore;
import ui;
import elements;
//import document;


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
    Pid mServerPID;

    string TypeName[string];

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
    }






    void WatchForText(void* void_ti, string text, int len, void* void_self)
    {
        if(text.length != 1)
        {
            return;
        }
        if((DocMan.Current.WordLength() < mMinChars) && (text[0] != '(') && (text[0] != ')'))return;
        switch (text[0])
        {
            case 'a' : .. case 'z' :
            case 'A' : .. case 'Z' :
            case '0' : .. case '9' :
            case '_' :
            case '.' :
            case '(' : PresentCandidates(); break;
            case ')' : uiCompletion.PopCallTip(); break;
            default  : return;
        }
    }

    void PresentCandidates()
    {
        int CursorOffset = DocMan.Current.GetCursorByteIndex();

        string arg = format("-c%s",CursorOffset);

        auto pipes = std.process.pipeProcess([mClientCommand, arg]);

        pipes.stdin.write(DocMan.Current.GetText());
        pipes.stdin.flush();
        pipes.stdin.close();


        string[] Candidates;
        string[] Types;
        string[] Output;

        wait(pipes.pid());

        foreach(line; pipes.stdout.byLine)
        {
            Output ~= line.idup;
        }
        pipes.stdout.close();
        if(Output.length < 2) return;

        if(Output[0] == "identifiers")
        {
            foreach(index, line; Output[1 .. $])
            {
                auto i = line.indexOf('\t');
                Candidates ~= line[0..i];
                //Types ~= line[i+1..$];
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

        mServerCommand = SystemPath(Config.GetValue("dcd_elem", "server_command", "deps/DCD/bin/dcd-server"));
        mClientCommand = SystemPath(Config.GetValue("dcd_elem", "client_command", "deps/DCD/bin/dcd-client"));
        mImportPaths = Config.GetArray("dcd_elem", "import_paths", ["/usr/include/dmd/phobos", "/usr/include/dmd/druntime"]);
        mMinChars = Config.GetValue("dcd_elem", "min_char_lookup", 3);

        //are we running
        string[] cmd = [mClientCommand];
        cmd ~= "-q";
        auto queryServer = execute(cmd);
        if(queryServer.status ==1) //nope start it up
        {
            mShutServerDown = true;
            try
            {
                mServerPID = spawnProcess([mServerCommand] ~ mImportPaths);
            }
            catch(Exception x)
            {
                ShowMessage("DCD SERVER FAILED TO START", x.msg);
                Log.Entry("Failed to start DCD server.");
                return;
            }
            //Log.Entry("DCD server started.");
        }
        string eyeports = format("%s", mImportPaths);
        Log.Entry("DCD server running :" ~ eyeports);

        DocMan.Insertion.connect(&WatchForText);

        Log.Entry("Engaged :) Are you happy? ");
    }


    void Disengage()
    {
        DocMan.Insertion.disconnect(&WatchForText);

        if(mShutServerDown)
        {
            auto stopServer = execute([mClientCommand] ~ ["--shutdown"]);
            wait(mServerPID);
            if(stopServer.status == 0)Log.Entry("DCD server shut down.");
            else Log.Entry("Failed to shut down DCD server.");
        }
        else
        {
            Log.Entry("DCD server continuing to run.");
        }
        Log.Entry("Disengaged");
    }

    void Configure(){}



    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }

}
