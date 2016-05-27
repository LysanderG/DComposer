module docman;

import dcore;
import ui;

import std.path;
import std.file;
import std.stdio;
import std.string;
import std.signals;
import std.conv;
import std.utf;
import std.uni;
import std.encoding;
import std.algorithm;
import std.range;


interface DOC_IF
{

    @property string Language();
    @property void Language(string nulang);

    @property void  Name(string nuname);
    @property string Name();
    @property string TabLabel();

    @property bool  Virgin();
    @property void  Virgin(bool nuVirgin);

    @property bool  Modified();
    @property void  Modified(bool nuModified);

    void Configure();
    void ShowMe();

    int     Line();
    int     Column();
    string  LineText();
    string  Symbol();
    string  FullSymbol();
    string  Word(string AtMarkName = "insert");
    string  WordUnderPointer();
    int     WordLength(int Partial = -1);
    dchar   GetChar();
    bool    RefreshCoverage();
    void    HideGutterCoverage();

    string  GetText();
    void    SetText(string txt);
    void    InsertText(string txt);
    void    ReplaceWord(string txt);
    void    ReplaceLine(string txt);
    void    ReplaceSelection(string txt);
    void    CompleteSymbol(string txt);
    void    StopUndo();
    void    RestartUndo();

    string  Selection();
    void    GotoLine(int LineNo, int LinePos);
    void    Save();
    void    SaveAs(string NuName);
    void    Close();
    void    SetTimeStamp();
    static  DOC_IF Create(string Title, string ClassType = "unknown")
    {
        if(ClassType == "unknown") ClassType = GetClassType((Title));
        auto rv = cast(DOC_IF)Object.factory(ClassType);
        rv.Name = Title;
        rv.Virgin = true;
        return rv;
    }

    static  DOC_IF Open(string FileName, int LineNo = 0, int LinePos = 0)
    {

        auto rv = Create(FileName);

        rv.Virgin = false;

        scope(failure)
        {
            ui.ShowMessage("FILE INPUT ERROR", "Unable to open " ~ FileName ~ " confirm permissions and valid utf format.");
            SetBusyCursor(false);
            return null;
        }
        if(!exists(FileName))return null;
        SetBusyCursor(true);

        auto txt = ReadUTF8(FileName);
        rv.SetTimeStamp();
        rv.StopUndo();
        rv.SetText(txt);
        rv.RestartUndo();
        if( (LineNo) || (LinePos)) rv.GotoLine(LineNo, LinePos);

        SetBusyCursor(false);
        return rv;
    }

    void HiliteSearchResult(int LineNo, int Start, int End);
    void HiliteAllSearchResults(int LineNo, int Start, int End);
    void ClearHiliteAllSearchResults();
    void ReplaceText(string NewText, int Line, int StartOffset, int EndOffset);
    int GetCursorByteIndex();
    RECTANGLE GetCursorRectangle();
    RECTANGLE GetMarkRectangle(string MarkName);
    
    string GetLocation(out string name, out int line, out int col);

    bool IndentLines(int Reps);
    bool UnIndentLines(int Reps);



    //MOVMENTS
    bool MoveLeft(int Reps, bool selection_bound);
    bool MoveUp(int Reps, bool selection_bound);
    bool MoveDown(int Reps, bool selection_bound);
    bool MoveRight(int Reps, bool selection_bound);
    bool MoveLineStart(int Reps, bool selection_bound);
    bool MoveLineEnd(int Reps, bool selection_bound);
    bool MovePageUp(int Reps, bool selection_bound);
    bool MovePageDown(int Reps, bool selection_bound);
    bool MoveStart(int Reps, bool selection_bound);
    bool MoveEnd(int Reps, bool selection_bound);
    bool MoveNextWordStart(int Reps, bool selection_bound);
    bool MovePrevWordStart(int Reps, bool selection_bound);
    bool MoveNextWordEnd(int Reps, bool selection_bound);
    bool MovePrevWordEnd(int Reps, bool selection_bound);
    bool MovePrevScope(int Reps, bool selection_bound);
    bool MoveNextScope(int Reps, bool selection_bound);
    bool MovePrevBlockStart(int Reps, bool selection_bound);
    bool MoveNextBlockStart(int Reps, bool selection_bound);
    bool MovePrevBlockEnd(int Reps, bool selection_bound);
    bool MoveNextBlockEnd(int Reps, bool selection_bound);
    bool MoveUpperScope(int Reps, bool selection_bount);
    bool MoveLowerScope(int Reps, bool selection_bound);
    bool MovePrevStatementStart(int Reps, bool selection_bound);
    bool MovePrevStatementEnd(int Reps, bool selection_bound);
    bool MoveNextStatementStart(int Reps, bool selection_bound);
    bool MoveNextStatementEnd(int Reps, bool selection_bound);
    bool MovePrevCurrentChar(int Reps, bool selection_bound);
    bool MoveNextCurrentChar(int Reps, bool selection_bound);
    bool MoveBracketMatch(bool selection_bound);
    bool MovePrevSymbol(int Reps, bool selection_bound);
    bool MoveNextSymbol(int Reps, bool selection_bound);
    bool MovePrevParameterStart(int Reps, bool selection_bound);
    bool MoveNextParameterEnd(int Reps, bool selection_bound);
    bool MovePrevParameterEnd(int Reps, bool selection_bound);
    bool MoveNextParameterStart(int Reps, bool selection_bound);
    bool MoveNextStringBoundary(int Reps, bool selection_bound);
    bool MovePrevStringBoundary(int Reps, bool selection_bound);
    bool MoveNextCommentBoundary(int Reps, bool selection_bound);
    bool MovePrevCommentBoundary(int Reps, bool selection_bound);

    /+//search test -- remove
    void SearchTest(); +/

    //object movement -- should deprecate all (most) movements above
    void MoveObjectNext(TEXT_OBJECT Object, int reps, bool selection_bound);
    void MoveObjectPrev(TEXT_OBJECT Object, int reps, bool selection_bound);

    //void MoveObject(TEXT_OBJECT Object, TEXT_OBJECT_DIRECTION Direction, TEXT_OBJECT_MARK Mark);

    void ScrollUp(int Steps);
    void ScrollDown(int Steps);
    void ScrollCenterCursor();

}
struct RECTANGLE
{
    int x, y;
    int xl, yl;
}

//====================================================================================================================
//====================================================================================================================
//====================================================================================================================
interface UI_DOCBOOK_IF
{
    @property DOC_IF Current();
    @property void Current(DOC_IF nuCurrent);

    bool ConfirmCloseFile(DOC_IF Closer);
    void Append(DOC_IF nuCurrent);
    string[] OpenDialog();
    string SaveAsDialog(string prevName);
    void ClosePage(DOC_IF);
    void Revert();
    void Undo();
    void Redo();
    void Cut();
    void Copy();
    void Paste();
    void NotifySelection();
    void NextPage();
    void PrevPage();
}

UI_DOCBOOK_IF GetDocBook(){return ui.DocBook;}

//====================================================================================================================
//====================================================================================================================
//====================================================================================================================
class DOCMAN
{
    private:

    DOC_IF[] mDocuments;
    UI_DOCBOOK_IF mDocBook;


    Pid[] mRunPids;
    enum tmpfilename = "document_run_script";
    bool mBlockDocumentKeyPress;


    string NextTitle(string Extension = ".d")
    {
        static int UnTitledCount = 0;
        immutable string Title = "dcomposer%s";
        string rv;
        if(UnTitledCount > 99_999) UnTitledCount = 0;//relax this is nothing just change it
        do
        {
            rv = buildPath(CurrentPath(), format(Title, UnTitledCount));
            if(UnTitledCount++ > 100_000) return "dcomposer";
        }while(exists(rv.setExtension(Extension)));
        return rv.setExtension(Extension);
    }


    public:

    this()
    {
    }

    void Engage()
    {
        //what do i really need to do here

        Log.Entry("Engaged");
    }

    void PostEngage()
    {
        //AddIcon("nav_point_icon", SystemPath(Config.GetValue("docman", "nav_point_icon", "resources/pin-small.png")));

        mDocBook = GetDocBook();
        //Reload files opened last session and any cmdline files
        auto CmdLineFiles = Config.GetArray!string("docman", "cmd_line_files");
        auto LastSessionFiles = Config.GetArray!string("docman", "last_session_files");
        Open(cast(string[])CmdLineFiles ~ cast(string[])LastSessionFiles);

        Log.Entry("PostEngaged");
    }
    void Disengage()
    {
        //save open files for next session .. reimplemented to fix moved pages and save/discard on exit
        //string[] names;
        //foreach(xdoc; mDocuments)if(exists(xdoc.Name)) names ~= xdoc.Name;
        //Config.SetArray("docman","last_session_files", names);

        if( tmpfilename.exists())std.file.remove(tmpfilename);
        foreach(pid; mRunPids)kill(pid);
        foreach(pid; mRunPids)wait(pid);

        Log.Entry("Disengaged");
    }

    void SaveSessionDocuments()
    {
        string[] sessionDocs;

        auto pageCount = DocBook.getNPages();
        foreach(indx; 0 .. pageCount)
        {
            auto page = cast(ScrolledWindow)DocBook.getNthPage(indx);
            if(page is null)continue;
            auto doc = cast(DOC_IF)page.getChild();
            if(doc is null) continue;
            sessionDocs ~= doc.Name();
        }
        Config.SetArray("docman","last_session_files", sessionDocs);
    }



    @property DOC_IF Current()
    {
        return mDocBook.Current();
    }

    @property int Modified()
    {
        int ModifiedFiles;
        foreach(doc; mDocuments)if(doc.Modified)ModifiedFiles++;
        return ModifiedFiles;
    }

    void Create(string DocType = "D source")
    {
        string nameindex;
        string ClassType;
        switch (DocType)
        {
            case "plain text" : nameindex = NextTitle(".txt"); ClassType = "document.DOCUMENT";break;
            case "D source" : nameindex = NextTitle(".d"); ClassType = "document.DOCUMENT";break;
            default : ClassType = "document.DOCUMENT";break;
        }
        auto tmp = DOC_IF.Create(nameindex, ClassType);
        tmp.Configure();
        tmp.ShowMe();
        mDocBook.Append(tmp);
        mDocuments ~= tmp;

        Event.emit("Create", Current());

        Log.Entry("Create document");
    }

    void Open()
    {
        auto DocsToOpen = mDocBook.OpenDialog();
        if(DocsToOpen.length == 0)return;
        Open(DocsToOpen);
    }
    void Open(string[] Files)
    {
        foreach(doc; Files)Open(doc);
    }
    DOC_IF Open(string FileName, int LineNo = 0, int LinePos = 0)
    {
        //first see if it is already open
        auto doc = GetDoc(FileName);
        if(doc)
        {
            mDocBook.Current = doc;
            if(LineNo >= 0)doc.GotoLine(LineNo, LinePos);
            return doc;
        }

        auto nudoc = DOC_IF.Open(FileName, LineNo, LinePos);
        if(nudoc is null) return null;
        nudoc.Modified = false;
        nudoc.Virgin = false;
        nudoc.Configure();

        mDocuments ~= nudoc;
        nudoc.ShowMe();
        mDocBook.Append(nudoc);

        Event.emit("Open", nudoc);

        Log.Entry("Opened " ~ nudoc.Name);
        return nudoc;
    }


    void Save(DOC_IF xDoc = null)
    {
        scope(failure)
        {
            Log.Entry("Failed to save " ~ xDoc.Name, "Error");
            return;
        }
        if(xDoc is null) xDoc = Current();
        if(xDoc is null) return;

        if(xDoc.Virgin())
        {
            SaveAs(xDoc);
            return;
        }
        xDoc.Save();
        Event.emit("Save", xDoc);
        Log.Entry("Saved " ~ xDoc.Name);
    }

    void SaveAs(DOC_IF saDoc = null)
    {
        if(saDoc is null) saDoc = Current;
        if(saDoc is null) return;

        string savefile = mDocBook.SaveAsDialog(saDoc.Name);
        if (savefile.length == 0) return;
        saDoc.Name = savefile;
        saDoc.Save();
        saDoc.Configure();
        Event.emit("SaveAs", saDoc);
    }
    void SaveAll()
    {
        foreach(doc; mDocuments)if(doc.Modified())Save(doc);
    }

    void Close(DOC_IF DocToClose = null)
    {
        if(DocToClose is null) DocToClose = Current;
        if(DocToClose is null) return;

        if(DocToClose.Modified)
        {
            if(!mDocBook.ConfirmCloseFile(DocToClose))return;
        }

        DOC_IF[] tmpDocs;
        foreach(doc; mDocuments)
        {
            if(doc !is DocToClose) tmpDocs ~= doc;
        }
        mDocuments = tmpDocs;

        Event.emit("Close", DocToClose);
        mDocBook.ClosePage(DocToClose);
        Log.Entry("Closed " ~ DocToClose.Name);
    }
    void CloseAll()
    {
        foreach(doc; mDocuments)Close(doc);
    }

    //try run with a script
    void Run(string[] args = null)
    {
        if(Current is null) return;
        if(Current.Modified)Current.Save();

        scope(failure)
        {
            ShowMessage("Error", "Failed to run " ~ Current.TabLabel);
            Log.Entry("Failed to run " ~ Current.TabLabel);
        }
        CurrentPath(Current.Name.baseName());

        string ExecName = Current.Name();

        auto TerminalCommand = Config.GetArray!string("terminal_cmd","run", ["xterm", "-T","dcomposer running project","-e"]);

        auto tFile = std.stdio.File(tmpfilename, "w");

        tFile.writeln("#!/bin/bash");
        tFile.write("rdmd ", ExecName,);
        //foreach(arg; args)tFile.write(" ",arg);
        tFile.writeln();
        tFile.writeln(`echo -e "\n\nProgram Terminated.\nPress a key to close terminal..."`);
        tFile.writeln(`read -sn1`);
        tFile.flush();
        tFile.close();
        setAttributes(tmpfilename, 509);


        string[] CmdStrings;

        CmdStrings = TerminalCommand;
        CmdStrings ~= ["./"~tmpfilename];

        try
        {
            mRunPids ~= spawnProcess(CmdStrings);
            Log.Entry(`"` ~ Current.TabLabel ~ `"` ~ " spawned ... " );
        }
        catch(Exception E)
        {
            Log.Entry(E.msg);
            return;
        }
    }


    bool Compile(DOC_IF xDoc = null, string[] Args = [])
    {
        scope(exit)SetBusyCursor(false);
        SetBusyCursor(true);

        if(xDoc is null) xDoc = Current;
        if(xDoc is null) return false;

        if(xDoc.Modified) xDoc.Save();
        auto CmdString = Config.GetArray!string("docman","compile_command", ["dmd", "-c", "-o-", "-vcolumns"]);
        CmdString ~= Args ~ [xDoc.Name];

        auto result = execute(CmdString);

        Message.emit("BEGIN");
        Message.emit(CmdString.join(" "));
        if(result.status == 0)
        {
            Log.Entry(xDoc.Name ~ " compiled successfully");
            Message.emit("Success");
        }
        else
        {
            Log.Entry(xDoc.Name ~ " failed to compile");
            foreach(ln;result.output.splitLines()){Message.emit(ln);}
        }
        Message.emit("END");
        return (result.status == 0);
    }
    
    void UnitTests()
    {
        
        
        if(Current is null) return;
        scope(success) 
        {
            Current.RefreshCoverage();
        }
        scope(failure)
        {
            ShowMessage("Error", "Failed to execute unit tests " ~ Current.TabLabel);
            Log.Entry("Failed to execute unit tests for " ~ Current.TabLabel);
            return;
        }
        
        if(Current.Modified)Current.Save();

        CurrentPath(Current.Name.baseName());

        string ExecName = Current.Name();
        string projOpts;
        if(Project.TargetType != TARGET.EMPTY)
        {
            if(Project.Lists[LIST_NAMES.IMPORT].length)
                projOpts = " -I" ~ Project.Lists[LIST_NAMES.IMPORT].join(" -I") ~" ";
            if(Project.Lists[LIST_NAMES.STRING].length)
                projOpts ~= " -J" ~ Project.Lists[LIST_NAMES.STRING].join(" -J") ~" ";
        }
       
        auto TerminalCommand = Config.GetArray!string("terminal_cmd","run", ["xterm", "-T","dcomposer running project","-e"]);
        try
        {
            auto tFile = std.stdio.File(tmpfilename, "w");
    
            tFile.writeln("#!/bin/bash");
            tFile.writeln("rdmd -unittest -cov --main ", projOpts, ExecName );
            tFile.writeln("if [ $? = 0 ]; then");
            tFile.writeln(" echo UNIT TESTS SUCCEEDED");
            tFile.writeln("fi");
            tFile.writeln();
            tFile.writeln(`echo -e "\n\nProgram Terminated.\nPress a key to close terminal..."`);
            tFile.writeln(`read -sn1`);
            tFile.flush();
            tFile.close();
            setAttributes(tmpfilename, 509);
    
    
            string[] CmdStrings;
    
            CmdStrings = TerminalCommand;
            CmdStrings ~= ["./"~tmpfilename];


            auto xpid = spawnProcess(CmdStrings);
            wait(xpid);
            Log.Entry(`"` ~ Current.TabLabel ~ `"` ~ " unittests ran and finished" );
            auto covfile = readText(Current.Name.tr("/", "-").setExtension("lst"));
            string finalmsg = covfile
                              .lineSplitter
                              .array[$-1];
                              
            ShowMessage("Code coverage", finalmsg);            
        }
        catch(Exception E)
        {
            Log.Entry(E.msg);
            return;
        }       
        
    }
    
    void HideGutterCoverage()
    {
        auto doc = Current();
        if(doc) doc.HideGutterCoverage();
    }

    bool IsOpen(string CheckName)
    {
        foreach(doc; mDocuments)
        {
            if(doc.Name == CheckName) return true;
        }
        return false;
    }

    DOC_IF GetDoc(string DocName)
    {
        foreach(doc; mDocuments)
        {
            if(doc.Name == DocName) return doc;
        }
        return null;
    }

    bool Empty()
    {
        return (mDocuments.length < 1);
    }

    bool GoTo(string DocName, int DocLine = 0 , int DocLinePos = 0)
    {
        auto docCheck = Open(DocName, DocLine, DocLinePos);
        if(docCheck is null) return false;
        if(Current is null) return false;
        if(Current.Name != DocName)return false;
        //Current.GotoLine(DocLine);
        return true;
    }
    void Undo()
    {
        mDocBook.Undo();
    }
    void Redo()
    {
        mDocBook.Redo();
    }
    void Revert()
    {
        mDocBook.Revert();
    }
    void Cut()
    {
        mDocBook.Cut();
    }
    void Copy()
    {
        mDocBook.Copy();
    }
    void Paste()
    {
        mDocBook.Paste();
    }

    void NotifySelection()
    {
        mDocBook.NotifySelection();
    }

    DOC_IF[] GetOpenDocs()
    {
        return mDocuments;
    }

    void SetBlockDocumentKeyPress(bool setting = true)
    {
        mBlockDocumentKeyPress = setting;
    }
    bool BlockDocumentKeyPress()
    {
        auto rv = mBlockDocumentKeyPress;
        mBlockDocumentKeyPress = false;
        return rv;
    }



    mixin Signal!(string, DOC_IF) Event;
    mixin Signal!(string) Message;
    mixin Signal!(void*, string, int, void*) Insertion;
    mixin Signal!(DOC_IF) PageFocusOut;
    mixin Signal!(DOC_IF) PageFocusIn;
    mixin Signal!(uint, uint) DocumentKeyDown;
    mixin Signal!(void *, DOC_IF) MouseButton;
    mixin Signal!(DOC_IF, int, int) PreCursorJump;
    mixin Signal!(DOC_IF, int, int) CursorJump;
}


/+
enum OBJECT_POSITION
{
    START,
    WHOLE,
    END
}

enum OBJECT_DEFINED_BY
{
    REGEX,
    FUNCTION
}



struct TEXT_OBJECT
{
    private:
    string mID;
    OBJECT_DEFINED_BY mDefinedBy;
    string mRegexDef; //regular expression for the object
    void  function() mFunctionDef;

    public:
    this(string ID, string Definition, OBJECT_DEFINED_BY DefinedBy = OBJECT_DEFINED_BY.REGEX)
    {
        mID = ID; mRegexDef = Definition; mDefinedBy = DefinedBy;
    }

    void SetFunction(void function() FunctionDefinition) { mFunctionDef = FunctionDefinition;}

    bool IsRegex(){ return (mDefinedBy == OBJECT_DEFINED_BY.REGEX);} //DON'T ASK ME! like some kind of sad UNION
    bool IsFunction(){return (mDefinedBy == OBJECT_DEFINED_BY.FUNCTION);}
    string GetRegex(){ return (mDefinedBy == OBJECT_DEFINED_BY.REGEX) ? mRegexDef : "";}
    void CallObject(){if(mFunctionDef)mFunctionDef();}
    string ID() { return mID;}
}+/


struct TEXT_OBJECT
{
    string mId;
    char mKey;
    string mRegex;

    this(string Name, char key, string Regex)
    {
        mId = Name;
        mKey = key;
        mRegex = Regex;
    }
}

enum TEXT_OBJECT_DIRECTION
{
    PREV,
    NEXT
}

enum TEXT_OBJECT_MARK
{
    CURSOR,
    START,
    END
}

//====================================================================================================================
//====================================================================================================================
//====================================================================================================================


//=====================================================================================================================
//=====================================================================================================================
//                                    misc utility stuff
//=====================================================================================================================
//=====================================================================================================================

string GetClassType(string docTitle)
{
    string rv;
    auto ext = docTitle.extension();
    if(ext.length < 1)ext = "default";
    rv = (Config.GetValue!string("document_classes", ext, "document.DOCUMENT"));
    return rv;
}



string ReadUTF8(string FileName)
{
    bool Succeeded;

    ubyte[] data = cast(ubyte[])read(FileName);

    if(try8(data))  return toUTF8(cast( char[])data);
    //if(try16(data)) return toUTF8(cast(wchar[])data);
    if(try32(data)) return toUTF8(cast(dchar[])data);
    throw new Exception("DComposer is limited opening to valid utf files only.\nEnsure " ~ baseName(FileName) ~ " is properly encoded.\nSorry for any inconvenience.");
}

bool try8(const ubyte[] data)
{
    scope(failure) return false;
    validate!(char[])(cast(char[])data);
    return true;
}

bool try16(const ubyte[] data)
{
    scope(failure) return false;
    validate!(wchar[])(cast(wchar[])data);
    return true;
}
bool try32(const ubyte[] data)
{
    scope(failure) return false;
    validate!(dchar[])(cast(dchar[])data);
    return true;
}

bool isWordStartChar(dchar x)
{
    return ((x.isAlpha()) || (x == '_'));
}

bool isWordChar(dchar x)
{
    return ( (x.isAlpha()) || (x == '_') || (x.isNumber()));
}
