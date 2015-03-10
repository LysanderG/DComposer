module dcd_completion;

import std.algorithm;
import std.string;
import std.conv;

import ui;
import dcore;
import elements;
import document;
import ui_preferences;


import gtk.Widget;
import gtk.TextIter;
import gtk.TextBuffer;

import gsv.SourceCompletion;
import gsv.SourceCompletionProviderIF;
import gsv.SourceCompletionProvider;
import gsv.SourceCompletionContext;
import gsv.SourceCompletionInfo;
import gsv.SourceCompletionProposalIF;
import gsv.SourceCompletionProviderT;
import gsv.SourceCompletionItem;
import gsv.SourceCompletionWords;

import gobject.ObjectG;
import gobject.Type;

import gtkc.gobject;
import gtkc.Loader;
import gtkc.paths;

import glib.ListG;


import std.traits;

export extern (C) string GetClassName()
{
    return fullyQualifiedName!DCD_COMPLETION;
}

class DCD_COMPLETION : ELEMENT
{
    private:

    Pid mServerPid;
    string mClientCommand;
    string mServerCommand;

    string[] mIpaths;



    void WatchProject(PROJECT_EVENT Event)
    {
        //NO WAY TO REMOVE IPATHS THIS COULD GET UGLY HUGE
        if(Event == PROJECT_EVENT.LISTS)
        {
            foreach(ipath; Project.Lists[LIST_NAMES.IMPORT]) AddImportPath(ipath);
        }
    }

    void WatchForNewDocuments(string EventName, DOC_IF Doc)
    {
        auto SrcDoc = cast(DOCUMENT) Doc;
        if(SrcDoc is null) return;

        auto comp = SrcDoc.getCompletion();

        comp.addOnPopulateContext (&Populate);
    }

    void Populate(SourceCompletionContext Context, SourceCompletion Completion)
    {
        dwrite("hello there");

        GtkSourceCompletionProvider *xstruct = new GtkSourceCompletionProvider;
        auto item1 = new SourceCompletionItem("string1", "string2", cast(Pixbuf)null, "string3");
        auto item2 = new SourceCompletionItem("alpha1", "alpha2", cast(Pixbuf)null, "alpha3");

        ListG lg = new ListG(null);

        lg.append(item1.getSourceCompletionItemStruct());
        lg.append(item2.getSourceCompletionItemStruct());

        dwrite(xstruct, "/",lg);
        auto providerx = new SourceCompletionProvider(xstruct);
        dwrite(xstruct, "/",providerx);

        Context.addProposals(providerx, lg, true);
    }


    string[] GetDCDCandidates(TextIter ti)
    {
        //find offset
        auto tiOffset = ti.copy();
        int offsetnotbytes = tiOffset.getLineIndex();
        while(tiOffset.backwardLine())offsetnotbytes += tiOffset.getBytesInLine();

        //start dcd with -c offset
        string CmdOption = format("-c%s", offsetnotbytes);

        std.process.ProcessPipes presult;
        try
        {
            presult = std.process.pipeProcess([mClientCommand, CmdOption]);
        }
        catch(Exception x)
        {
            Log.Entry(x.toString(), "Error");
        }

        //write text to dcd stdin (why did i do it by line? dunno)
        foreach(oline; DocMan.Current.GetText().splitLines())
        {
            presult.stdin.writeln(oline);
        }
        presult.stdin.flush();
        presult.stdin.close();

        //now read the results from dcd
        string[] CompletionLines;
        foreach (line; presult.stdout.byLine())
        {
            auto idx = countUntil(line, '\t'); //get rid of the type thingy on the end don't think i need it
            if (idx < 0) idx = line.length;
            CompletionLines ~= line[0..idx].idup;
        }

        wait(presult.pid);

        //get rid of the first line ... it should be "identifiers" or "calltips" don't need it
        if(CompletionLines.length < 2) return [];
        return CompletionLines[1..$];
    }



    public:
    string Name(){return "DCD completion";}
    string Info(){return "Symbol completion, calltips, and more using HackerPilot's excellent DCD utility.";}
    string Version() {return "00.01";}
    string CopyRight() {return "Anthony Goins © 2014";}
    string License() {return "New BSD license";}
    string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}

    void Engage()
    {
        Configure();

        string[] DcdServerCommandLine = [Config.GetValue!string("dcd_element", "server_command")];
        foreach(imp; Config.GetArray("dcd_element","import_paths",["/opt/dmd/include/d2", "/usr/local/include/d/gtkd-2"]))
        {
            mIpaths ~= imp;
            DcdServerCommandLine ~= "-I" ~ imp;
        }

        scope(failure)
        {
            dwrite(DcdServerCommandLine);
            Log.Entry("Failed to start dcd-server", "Error");
            assert(0);
        }
        mServerPid = spawnProcess(mServerCommand ~ DcdServerCommandLine, std.stdio.stdin, std.stdio.File("/dev/null","w"));

        Project.Event.connect(&WatchProject);

        DocMan.Event.connect(&WatchForNewDocuments);


        Log.Entry("Engaged");
    }


    void Disengage()
    {
        scope(failure)Log.Entry("Failed to Disengage DCD_COMPLETION", "Error");

        Project.Event.disconnect(&WatchProject);

        //execute([mClientCommand, "--shutdown"]);
        kill(mServerPid);
        wait(mServerPid);

        Log.Entry("Disengaged");
    }


    void Configure()
    {
        mServerCommand = SystemPath(Config.GetValue("dcd_element", "server_command", "deps/DCD/dcd-server"));
        mClientCommand = SystemPath(Config.GetValue("dcd_element", "client_command", "deps/DCD/dcd-client"));
    }

    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }

    void AddImportPath(string Ipath)
    {
        foreach(path; mIpaths)
        {
            if(path == Ipath) return;
        }
        mIpaths ~= Ipath;
        execute([mClientCommand, "-I"~Ipath]);
    }
}


//new crap ********************************************************
/*
GType dcd_comp_get_type()
{
    static GType type  = 0;

    if(!type)
    {
        static const GTypeInfo info =
        {
            DCDObjectClass.sizeof,
            null,
            null,
            &dcd_comp_class_init,
            null,
            null,
            DCDObject.sizeof,
            0,
            &dcd_comp_init
        }
    }

    GInterfaceInfo iface_info =
    {
        &my_object_interface_init,
        null,
        null,
    }



*/
