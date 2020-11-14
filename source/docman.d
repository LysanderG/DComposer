module docman;

import object;
import std.algorithm;
import std.array;
import std.format;
import std.file;
import std.path;
import std.process: spawnProcess, pConfig = Config;
import std.stdio;

import qore;
public import document;



public:

void Engage(ref string[] args)
{
    string[] cmdLineFiles;
    if(args.length > 1) foreach(arg; args[1..$])
    {
        if(arg.extension != ".dpro")cmdLineFiles ~= buildNormalizedPath(getcwd(),arg);
    }
    if(cmdLineFiles.length)Config.SetValue!(string[])("docman","cmdLineFiles", cmdLineFiles);
    else Config.SetValue!(string[])("docman","cmdLineFiles", []);
    
}
void Mesh()
{  
    string[] openFilesOnStart;
    openFilesOnStart = Config.GetArray!string("docman", "cmdLineFiles");
    openFilesOnStart ~= Config.GetArray!string("docman", "last_session_files");
    
    foreach(startup; openFilesOnStart)
    { 
        if(!startup.exists())
        {
            Log.Entry(startup ~ " does not exist, skipping");
            continue;            
        }
        OpenDoc(startup);
    }
}
void Disengage(){}

//ui agnostic interface to DOCUMENT
//ostensibly to use something other than GtkSourceView
//but super unlikely :)
interface DOC_IF
{
    static  DOC_IF Create(string DOC_IF_CLASS = "document.DOCUMENT")
    {
        auto rv = cast(DOC_IF)Object.factory(DOC_IF_CLASS);
        return rv;      
    }
    //Must call either Init or Load for doc_if to function 
    void    Init(string nuFileName = null);
    void    Reconfigure();
    void    Load(string fileName);
    void    Save();
    void    SaveAs(string newFileName);
    void    SaveCopy(string copyFileName);
    void    Close();
    
    void *  TabWidget();
    
    string  FullName();
    void    Name(string nuName);
    string  Name();
    bool    Virgin();
    bool	Modified();
    string  GetStatusLine();
}

//#############################################################################
//#############################################################################
void OpenDoc(string fileName)
{
    scope(failure)
    {
        Log.Entry("Unable to open document ",fileName);
    }
    auto doc = DOC_IF.Create();
    doc.Load(fileName);
    AddDoc(doc);    
}
void AddDoc(DOC_IF nuDoc)
{
    if(nuDoc.FullName in mDocs) 
    {
        Log.Entry("Adding " ~ nuDoc.Name ~ " to document manager");
        return;
    }
    mDocs[nuDoc.FullName] = nuDoc;
}
void Remove(DOC_IF oldDoc)
{
	mDocs.remove(oldDoc.FullName);
}
DOC_IF GetDoc(string docName)
{
    return mDocs[docName];
}

DOC_IF[] GetDocs()
{
	return mDocs.values;
}

bool Opened(string testDoc)
{
    if(testDoc in mDocs) return true;
    return false;
}

auto GetModifiedDocs()
{
    return (mDocs.byValue).filter!("a.Modified").array;
}

void SaveSessionDocuments()
{
    Config.SetArray!(string[])("docman","last_session_files",mDocs.keys);
}

void Run(string DocName, bool unitTest = true)
{  
    auto Doc = (DocName in mDocs);
    if(Doc is null) return;
    scope(failure)
    {
        Log.Entry("Failed to run " ~ Doc.FullName);
    }
    string ExecName = Doc.FullName;
    auto TerminalCommand = Config.GetArray!string("terminal_cmd","run", ["xterm", "-T","dcomposer running project","-e"]);

    auto tFile = std.stdio.File(mtmpDocRun, "w");

    tFile.writeln("#!/bin/bash");
    tFile.write("rdmd ");
    if(unitTest)tFile.write(" -unittest ");
    tFile.write(ExecName); 
    tFile.writeln();
    tFile.writeln(`echo -e "\n\nProgram Terminated.\nPress a key to close terminal..."`);
    tFile.writeln(`read -sn1`);
    tFile.writeln(`rm ` ~ mtmpDocRun);
    tFile.flush();
    tFile.close();
    setAttributes(mtmpDocRun, 509);

    string[] CmdStrings;
    CmdStrings = TerminalCommand;
    CmdStrings ~= ["./"~mtmpDocRun];

    try
    {
        spawnProcess(CmdStrings,stdin, stdout, stderr,null, pConfig.detached, null);
        Log.Entry(`"` ~ Doc.FullName ~ `"` ~ " spawned ... " );
    }
    catch(Exception E)
    {
        Log.Entry(E.msg);
        return;
    }
}

struct RECTANGLE
{
    int x, y;
    int xl, yl;
}

private:

DOC_IF[string]      mDocs;
int                 mSaveCtr;
string              mtmpDocRun = "tmp_doc_run.sh";

