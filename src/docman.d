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
import std.encoding;


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
    string  Word();
    string  WordUnderPointer();

    string  GetText();
    void    SetText(string txt);
    void    InsertText(string txt);
    void    ReplaceWord(string txt);
    void    ReplaceLine(string txt);
    void    ReplaceSelection(string txt);
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
        rv.GotoLine(LineNo, LinePos);

        SetBusyCursor(false);
        return rv;
    }

    void HiliteSearchResult(int LineNo, int Start, int End);
    void HiliteAllSearchResults(int LineNo, int Start, int End);
    void ClearHiliteAllSearchResults();
    void ReplaceText(string NewText, int Line, int StartOffset, int EndOffset);
    RECTANGLE GetCursorRectangle();

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
    void Undo();
    void Redo();
    void Cut();
    void Copy();
    void Paste();
    void NotifySelection();
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


    string NextTitle(string Extension = "")
    {
        static int UnTitledCount = 0;
        immutable string Title = "dcomposer%s%s";
        string rv;
        if(UnTitledCount > 99_999) UnTitledCount = 0;//relax this is nothing just change it
        do
        {
            rv = buildPath(CurrentPath(), format(Title, UnTitledCount++, Extension));
            if(UnTitledCount > 100_000) return "dcomposer";
        }while(exists(cast(string)rv));
        return rv;
    }

    Pid[] mRunPids;

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
        mDocBook = GetDocBook();
        //Reload files opened last session and any cmdline files
        auto CmdLineFiles = Config.GetArray!string("docman", "cmd_line_files");
        auto LastSessionFiles = Config.GetArray!string("docman", "last_session_files");
        Open(cast(string[])CmdLineFiles ~ cast(string[])LastSessionFiles);

        Log.Entry("PostEngaged");
    }
    void Disengage()
    {
        //save open files for next session
        string[] names;
        foreach(xdoc; mDocuments)if(exists(xdoc.Name)) names ~= xdoc.Name;
        Config.SetArray("docman","last_session_files", names);

        foreach(pid; mRunPids)kill(pid);
        foreach(pid; mRunPids)wait(pid);

        Log.Entry("Disengaged");
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
        string nameindex = NextTitle();
        string ClassType;
        switch (DocType)
        {
            case "plain text" : ClassType = "document.DOCUMENT";break;
            case "D source" : nameindex ~= ".d"; ClassType = "document.DOCUMENT";break;
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

    void Run()
    {
        if(Current is null) return;
        if(Current.Modified) Current.Save();
        auto CmdString = Config.GetArray!string("docman","run_command", ["xterm", "-hold", "-e"]);
        CmdString ~= "rdmd " ~ Current.Name;
        mRunPids ~= spawnProcess(CmdString);
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

    mixin Signal!(string, DOC_IF) Event;
    mixin Signal!(string) Message;
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
