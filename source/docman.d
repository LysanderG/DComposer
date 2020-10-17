module docman;

import object;
import std.format;

public import document;
import log;
import config;


public:


//ui agnostic interface to DOCUMENT
//ostensibly to use something other than GtkSourceView
//but super unlikely :)
interface DOC_IF
{
    static  DOC_IF Create(string fileName = null, string DOC_IF_CLASS = "document.DOCUMENT")
    {
        auto rv = cast(DOC_IF)Object.factory(DOC_IF_CLASS);
        if(fileName is null)fileName = NameMaker();
        
        rv.Name = fileName;
        rv.Virgin = true;
        docman.AddDoc(rv);
        return rv;      
    }
    void    Reconfigure();
    void    Load(string fileName);
    void    Save();
    void    SaveAs(string newFileName);
    void    SaveCopy(string copyFileName);
    void    Close();
    
    void *  TabWidget();
    string  StatusText();
    
    string  FullName();
    void    Name(string nuName);
    string  Name();
    void    Virgin(bool virgin);
    bool    Virgin();
    //void    Modified(bool modified);
    //bool    Modified();
}

//#############################################################################
//#############################################################################

void AddDoc(DOC_IF nuDoc)
{
    if(nuDoc.FullName in mDocs) 
    {
        Log.Entry("Readding DocIF to document manager");
        return;
    }
    mDocs[nuDoc.FullName] = nuDoc;
}
DOC_IF GetDoc(string docName)
{
    return mDocs[docName];
}

bool Opened(string testDoc)
{
    dwrite(testDoc, "\n",mDocs);
    if(testDoc in mDocs) return true;
    return false;
}

private:

DOC_IF[string]      mDocs;

string NameMaker()
{
    static int suffixNumber = 0;
    scope(exit)suffixNumber++;
    
    enum baseName = "dcomposer%4s.d";
    return format(baseName, suffixNumber);
    
    
}
