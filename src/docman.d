// untitled.d
// 
// Copyright 2012 Anthony Goins <anthony@LinuxGen11>
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
// MA 02110-1301, USA.

module docman;

import dcore;
import ui;
import document;


import std.array;
import std.stdio;
import std.string;
import std.conv;
import std.path;
import std.signals;
import std.file;

import  gtk.Action;
import  gtk.Menu;
import  gtk.MenuItem;
import  gtk.MenuToolButton;
import  gtk.SeparatorMenuItem;
import  gtk.Widget;
import  gtk.FileFilter;
import  gtk.ScrolledWindow;
import  gtk.FileChooserDialog;
import  gtk.SeparatorToolItem;
import  gtk.TextIter;

import  glib.ListSG;



interface DOCUMENT_IF
{
    bool        Create(string Identifier);                          //create a new document DComposerxxxx.d
    bool        Open(string FileName, ulong LineNo = 1);            //load a file and show line LineNo
    bool        Save();                                             //put the words on disk
    bool        SaveAs(string NewName);                             //put the words on disk with a new file name
    bool        Close(bool Quitting = false);                       //close (get rid of) document (if quitting then needs a diff confirm dialog)

    @property string      DisplayName();                                      //basename of the document (no path but still an ext) or maybe relative path
    @property void        DisplayName(string NuName);                         //sets it
    @property string      FullPathName();                                     //absolute name of the documents file
    @property void        FullPathName(string NuPath);                        //setter
    @property bool        Modified();                                         //does it need to be saved?
    @property void        Modified(bool Modded);                              //setter
    @property bool        Virgin();                                           //ever been on disk??
    @property void        Virgin(bool Still);                                 //obviously can't be returned to true

    Widget      TabWidget();                                        //the tab that shows up on the centerpane notebook
    Widget      GetPage();                                          //actually the parent of this page? (ie scrollwindow
    Widget      GetWidget();                                        //cast(widget) this basically
    void        Focus();                                            //look at me!
       
    void        Edit(string Verb);                                  //do a copy cut paste delete action
    ubyte[]     RawData();                                          //return whachagot

    void        GotoLine(uint LineNumber);                         //put cursor on linenumber and show it
}



class DOCMAN
{
    private:

    uint                mUnTitledCount;                             //used to append xxx to DComposerxxx.d virgin files

    string              mFileDialogFolder;                          //where next file open dialog starts (unless ... a project protests)

    FileFilter[string]  mFileFilters;                               //text dsrc dpro and maybe somemore

    string[]            mStartUpFiles;                              //files left open last session and/or on the command line to be opened

    Action[]            mContextActions;                              //this menu prepends to text documents context popup menu
  


    void LoadFileFilters()
    {

        Config.setString("DOC_FILTERS", "dsrc", "D source file;mime;text/x-dsrc");
        Config.setString("DOC_FILTERS", "text", "Text files;mime;text/plain");
        Config.setString("DOC_FILTERS", "dpro", "DComposer project files;pattern;*.dpro");

        ulong KeyCount;
        string[] FilterKeys = Config.getKeys("DOC_FILTERS", KeyCount);

        foreach(i, key; FilterKeys)
        {
            string[] data = Config.getString("DOC_FILTERS", key).split(";");
            mFileFilters[key] = new FileFilter;
            mFileFilters[key].setName(data[0]);
            

            if(data[1] == "mime")mFileFilters[key].addMimeType(data[2]);
            if(data[1] == "pattern")mFileFilters[key].addPattern(data[2]);
        }
    }

    //only loads the names of files during engage
    //actually opening the files will wait until after all elements have been engaged
    void LoadStartUpFileNames()
    {
        mStartUpFiles = Config().getString("DOCMAN", "files_last_session").split(";");   //files open last session
        mStartUpFiles ~=  Config().getString("DOCMAN", "files_to_open").split(";");      //files from command line

        string report;
        foreach(f; mStartUpFiles) if(f.length > 0)report ~= f ~":";
        Log.Entry("Start Up Files = " ~ report, "Debug");
    }

    //a little long but straight forward (create actions add em to menubar and toolbar)
    void CreateActions()
    {

        Action  CreateAct   = new Action("CreateAct","_New ", "Create a new text document", StockID.NEW);
        Action  OpenAct     = new Action("OpenAct","_Open", "Open a file", StockID.OPEN);
        Action  SaveAct     = new Action("SaveAct", "_Save", "Save current document", StockID.SAVE);
        Action  SaveAsAct   = new Action("SaveAsAct", "Save _As..","Save current document to different file", StockID.SAVE_AS);
        Action  SaveAllAct  = new Action("SaveAllAct", "Save A_ll", "Save all documents", null);
        Action  CloseAct    = new Action("CloseAct", "_Close", "Close current document", StockID.CLOSE);
        Action  CloseAllAct = new Action("CloseAllAct", "Clos_e All", "Close all documents", null);


        CreateAct.addOnActivate     (delegate void(Action X){CreateDoc();});
        OpenAct.addOnActivate       (delegate void(Action X){OpenDoc();});
        SaveAct.addOnActivate       (delegate void(Action X){SaveDoc();});
        SaveAsAct.addOnActivate     (delegate void(Action X){SaveAsDoc();});
        SaveAllAct.addOnActivate    (delegate void(Action X){SaveAllDocs();});
        CloseAct.addOnActivate      (delegate void(Action X){CloseDoc();});
        CloseAllAct.addOnActivate   (delegate void(Action X){CloseAllDocs();});

        CreateAct.setAccelGroup (dui.GetAccel());  
        OpenAct.setAccelGroup   (dui.GetAccel());
        SaveAct.setAccelGroup   (dui.GetAccel());    
        SaveAsAct.setAccelGroup (dui.GetAccel());  
        SaveAllAct.setAccelGroup(dui.GetAccel()); 
        CloseAct.setAccelGroup  (dui.GetAccel());   
        CloseAllAct.setAccelGroup(dui.GetAccel());
        
        dui.Actions.addActionWithAccel(CreateAct  , null);
        dui.Actions.addActionWithAccel(OpenAct    , null);
        dui.Actions.addActionWithAccel(SaveAct    , null);
        dui.Actions.addActionWithAccel(SaveAsAct  , null);
        dui.Actions.addActionWithAccel(SaveAllAct , null);
        dui.Actions.addActionWithAccel(CloseAct   , null);
        dui.Actions.addActionWithAccel(CloseAllAct, null);

        dui.AddMenuItem("_Documents",CreateAct.createMenuItem() );
        dui.AddMenuItem("_Documents",OpenAct.createMenuItem()   );
        dui.AddMenuItem("_Documents",new SeparatorMenuItem()    );
        dui.AddMenuItem("_Documents",SaveAct.createMenuItem()   );
        dui.AddMenuItem("_Documents",SaveAsAct.createMenuItem() );
        dui.AddMenuItem("_Documents",SaveAllAct.createMenuItem());
        dui.AddMenuItem("_Documents",new SeparatorMenuItem()    );
        dui.AddMenuItem("_Documents",CloseAct.createMenuItem()  );
        dui.AddMenuItem("_Documents",CloseAllAct.createMenuItem());

        dui.AddToolBarItem(CreateAct  .createToolItem());
        dui.AddToolBarItem(OpenAct    .createToolItem());
        dui.AddToolBarItem(SaveAct    .createToolItem());
        dui.AddToolBarItem(SaveAsAct  .createToolItem());
        dui.AddToolBarItem(SaveAllAct .createToolItem());
        dui.AddToolBarItem(CloseAct   .createToolItem());
        dui.AddToolBarItem(CloseAllAct.createToolItem());
        dui.AddToolBarItem(new SeparatorToolItem);
        
        


        auto mi = new MenuItem("New _Type");
        auto m = new Menu;

        Config.setString("DOC_NEW_TYPES", ".d", "D source file");
        Config.setString("DOC_NEW_TYPES", ".di", "D interface file (header)");
        Config.setString("DOC_NEW_TYPES", ".lua", "Lua source file");
        Config.setString("DOC_NEW_TYPES", ".tcl", "Tcl source file");
        Config.setString("DOC_NEW_TYPES", ".html", "HTML source file");

        ulong KeyCount;
        string[] DocTypes = Config.getKeys("DOC_NEW_TYPES", KeyCount);
        foreach(Type; DocTypes)
        {
            m.insert(new MenuItem(delegate void(MenuItem mi){CreateDoc(Type);},     Config.getString("DOC_NEW_TYPES", Type)), 0);

        }        
        
        mi.setSubmenu(m);        
        dui.AddMenuItem("_Documents", mi,1);

        //auto mt = new Menu;
        //mt.insert(new MenuItem(delegate void(MenuItem mi){Log().Entry("menuitem alpha");}, "D source file"), 0);
        //mt.insert(new MenuItem(delegate void(MenuItem mi){Log().Entry("menuitem beta");}, "Empty text file"), 1);
        //MenuToolButton mtb = new MenuToolButton(StockID.NEW);
        //mtb.setMenu(mt);
        //dui.AddToolBarItem(mtb,2);


        //ok now the edit actions
        Action      UndoAct     = new Action("UndoAct","_Undo", "Undo last action", StockID.UNDO);
        Action      RedoAct     = new Action("RedoAct","_Redo", "Undo the last undo(ie redo)", StockID.REDO);
        Action      CutAct      = new Action("CutAct", "_Save", "Remove selected text to clipboard", StockID.CUT);
        Action      CopyAct     = new Action("CopyAct", "_Copy","Copy selected text", StockID.COPY);
        Action      PasteAct    = new Action("PasteAct", "_Paste", "Paste clipboard into document", StockID.PASTE);
        Action      DeleteAct   = new Action("DeleteAct", "_Delete", "Delete selected text", StockID.DELETE);
        Action      SelAllAct   = new Action("SelAllAct", "Select _All", "Select all text", StockID.SELECT_ALL);
        Action      SelNoneAct  = new Action("SelNoneAct", "Select _None", "Unselect all text", null);

        UndoAct     .addOnActivate(delegate void(Action X){Edit("UNDO");});
        RedoAct     .addOnActivate(delegate void(Action X){Edit("REDO"); });
        CutAct      .addOnActivate(delegate void(Action X){Edit("CUT"); });
        CopyAct     .addOnActivate(delegate void(Action X){Edit("COPY"); });
        PasteAct    .addOnActivate(delegate void(Action X){Edit("PASTE"); });
        DeleteAct   .addOnActivate(delegate void(Action X){Edit("DELETE"); });
        SelAllAct   .addOnActivate(delegate void(Action X){Edit("SELALL"); });
        SelNoneAct  .addOnActivate(delegate void(Action X){Edit("SELNONE"); });

        UndoAct     .setAccelGroup(dui.GetAccel());  
        RedoAct     .setAccelGroup(dui.GetAccel());  
        CutAct      .setAccelGroup(dui.GetAccel());  
        CopyAct     .setAccelGroup(dui.GetAccel());  
        PasteAct    .setAccelGroup(dui.GetAccel());  
        DeleteAct   .setAccelGroup(dui.GetAccel());  
        SelAllAct   .setAccelGroup(dui.GetAccel());  
        SelNoneAct  .setAccelGroup(dui.GetAccel());

        dui.Actions().addActionWithAccel(UndoAct   , null);
        dui.Actions().addActionWithAccel(RedoAct   , null);
        dui.Actions().addActionWithAccel(CutAct    , null);
        dui.Actions().addActionWithAccel(CopyAct   , null);
        dui.Actions().addActionWithAccel(PasteAct  , null);
        dui.Actions().addActionWithAccel(DeleteAct , null);
        dui.Actions().addActionWithAccel(SelAllAct , null);
        dui.Actions().addActionWithAccel(SelNoneAct , null);

        dui.AddMenuItem("_Edit",UndoAct.createMenuItem());
        dui.AddMenuItem("_Edit",RedoAct.createMenuItem());
        dui.AddMenuItem("_Edit",new SeparatorMenuItem());
        dui.AddMenuItem("_Edit",CutAct.createMenuItem());
        dui.AddMenuItem("_Edit",CopyAct.createMenuItem());
        dui.AddMenuItem("_Edit",PasteAct.createMenuItem());
        dui.AddMenuItem("_Edit",DeleteAct.createMenuItem()); 
        dui.AddMenuItem("_Edit",new SeparatorMenuItem()    );
        dui.AddMenuItem("_Edit",SelAllAct.createMenuItem()  );
        dui.AddMenuItem("_Edit",SelNoneAct.createMenuItem());
        dui.AddMenuItem("_Edit",new SeparatorMenuItem());        



        dui.AddToolBarItem(UndoAct  .createToolItem());
        dui.AddToolBarItem(RedoAct    .createToolItem());
        dui.AddToolBarItem(CutAct    .createToolItem());
        dui.AddToolBarItem(CopyAct  .createToolItem());
        dui.AddToolBarItem(PasteAct .createToolItem());
        dui.AddToolBarItem(DeleteAct   .createToolItem());
        dui.AddToolBarItem(new SeparatorToolItem);
    }
    
    public:
    

    void Engage()
    {
        mFileDialogFolder = Config.getString("DOCMAN", "last_folder", "./");

        LoadFileFilters();
        LoadStartUpFileNames();

        CreateActions();

        Log.Entry("Engaged DOCMAN");
    }

    void Disengage()
    {
        //save all docs open in session to config file
        string DocsToOpenNextSession;

        DOCUMENT_IF docX;

        auto openCount = dui.GetCenterPane().getNPages();
        while(openCount > 0)
        {
            openCount--;
            docX = GetDocX(openCount);
            if(docX is null) continue;
            if(docX.Virgin())continue;
            DocsToOpenNextSession~= docX.FullPathName() ~ ";";
        }
        //DocsToOpenNextSession = DocsToOpenNextSession.chomp(";");
        if(DocsToOpenNextSession.empty)DocsToOpenNextSession =  "";
        Config().setString("DOCMAN", "files_last_session", DocsToOpenNextSession);
        Config().setString("DOCMAN", "files_to_open",""); //get rid of command line files

        //verify saving or discarding any modified docs
        CloseAllDocs(true);
        Log().Entry("Disengaged DOCMAN");
    }

     DOCUMENT_IF CreateDoc(string DocType = ".d")
    {
        string TitleString = std.string.format("DComposer%.3s", mUnTitledCount++);
        TitleString ~= DocType;

        DOCUMENT_IF NuDoc;

        scope(failure) {Log().Entry("Document " ~ TitleString ~ " failed creation" , "Error"); return null;}
        scope(success) Log().Entry("Document " ~ TitleString ~ " created.");

        //now this assumes we're creating a DOCUMENT ... how to improve this for different file types ???
        //if (DocType == ".glade"){ NuDoc = new GladeDoc; NuDoc.Create(TitleString); AppendDocument(NuDoc); return NuDoc;}  <--like that?  
        
        NuDoc = new DOCUMENT;
        
        NuDoc.Create(TitleString);

        AppendDocument(NuDoc);

        
        
        return NuDoc;
    }

    //OpenDoc with a file name and maybe a line number opens the FullFileName parameter
    //not going to add open project functionality here ... shouldn't need it
    void OpenDoc(string FullFileName, int LineNo = 0)
    {
        FullFileName = FullFileName.absolutePath;
        
        //ok this is wierd syntax here .. if not open(and focus if it is) do this(open) now do this(goto)
        //must have had a reason..?
        if(!IsOpenDoc(FullFileName, true))
        {
            scope(failure){Log.Entry("Document: "~FullFileName~" failed to open.", "Error"); return;}
            scope(success)Log.Entry("Document: "~FullFileName~" opened.");
            auto DocX = new DOCUMENT;
            if(DocX.Open(FullFileName))
            {
                AppendDocument(DocX, LineNo);
                
            }
            DocX.GotoLine(LineNo); //this is not good but didn't have time to figure out why appenddocument(doc, line) didn't position on cursor
                                   //stupid scroll to mark has wierd behavior can't figure it out.
            
            return;
        }        
        auto DocX = GetDocX(FullFileName);
        if (DocX is null) return;
        
        DocX.GotoLine(LineNo);               
        return ;
    }
    
    //open doc with no parameters presents a filechooser dialog then calls OpenDocs(string[])
    //if a project file is chosen will call Project.Open(chosenfile)
    void OpenDoc()
    {
        auto DocFiler = new FileChooserDialog
                            (
                                "Which files to DCompose?",
                                dui.GetWindow(),
                                FileChooserAction.OPEN
                            );
        //DocFiler.addShortcutFolder(".");
        DocFiler.addShortcutFolder("/usr/include/d/dmd/phobos/std/");
        DocFiler.setSelectMultiple(1);
        
        DocFiler.setCurrentFolder(mFileDialogFolder);
        foreach(filter; mFileFilters)DocFiler.addFilter(filter);
        DocFiler.setFilter(mFileFilters["dsrc"]);
        auto DialogReturned = DocFiler.run();
        DocFiler.hide();
       
        
        if (DialogReturned != ResponseType.GTK_RESPONSE_OK) return;
        
        mFileDialogFolder = DocFiler.getCurrentFolder();
        Config.setString("DOCMAN", "last_folder", mFileDialogFolder);

        string[] ArrayOfFiles;
        ListSG   ListOfFiles = DocFiler.getFilenames();
        ArrayOfFiles.length = ListOfFiles.length();

        foreach(ref f; ArrayOfFiles)
        {
            f = toImpl!(string, char *)(cast(char *)ListOfFiles.data());
            ListOfFiles = ListOfFiles.next();
        }

        OpenDocs(ArrayOfFiles);
    }
    void OpenDocs(string[] FullFileNames)
    {

        foreach(f;FullFileNames)
        {
            if(f.length < 1) continue;

            scope(failure){Log.Entry("Document: "~f~" failed to open.", "Error"); continue;}
            scope(success)Log.Entry("Document: "~f~" opened.");
            if(IsOpenDoc(f, true))continue;
            
            //stuck again ... for now just able to open DOCUMENTs
            //gotta change this ... (maybe later dcomposer will open rad gui form builders or images or anything)
            //switch (extension) docx = new extensiontype, docx.open append and return;  ...hey how come open returns void and create returns doc_if

            if(f.extension == ".dpro")
            {
                Project.Open(f);
                return;
            }
            auto DocX = new DOCUMENT;
            if(DocX.Open(f))AppendDocument(DocX);
            else throw new Exception("bad file?");
        }
    }

    void OpenInitialDocs()
    {
        if (mStartUpFiles.length > 1)Log.Entry("Opening Initial Document(s)...");
        OpenDocs(mStartUpFiles);
    }

    void SaveDoc()
    {
        auto docX = GetDocX();
        if(docX is null) return;

        scope(success)Log.Entry("Document :"~docX.FullPathName ~ " saved.");
        scope(failure){Log.Entry("Document :"~docX.FullPathName ~ " failed to save.", "Error"); return;}
                


        if(docX.Virgin())return SaveAsDoc(docX);
        docX.Save();


    }
    void SaveAsDoc(DOCUMENT_IF docX = null)
    {
        string presaveas;
        
        auto DocFiler = new FileChooserDialog
                            (
                                "Bury DComposed Files ...",
                                dui.GetWindow(),
                                FileChooserAction.SAVE
                            );        
        
        scope(failure){Log.Entry("Document :"~ presaveas ~ " failed to save as "~ DocFiler.getFilename ~ ".", "Error"); return; }
        
        if(docX is null) docX = GetDocX();
        if(docX is null) return;
        presaveas = docX.FullPathName;

        DocFiler.setCurrentFolder(mFileDialogFolder);
        DocFiler.setCurrentName(presaveas);
        foreach(filter; mFileFilters)DocFiler.addFilter(filter);
        auto DialogResponse = DocFiler.run();
        DocFiler.hide();
        if(DialogResponse !=  ResponseType.GTK_RESPONSE_OK) return;
        mFileDialogFolder = DocFiler.getCurrentFolder();
        Config.setString("DOCMAN", "last_folder", mFileDialogFolder);

        docX.SaveAs(DocFiler.getFilename);
        scope(success)Log.Entry("Document :"~ presaveas ~ " saved as " ~ docX.FullPathName ~ ".");

             
    }

        void SaveAllDocs()
    {
        DOCUMENT_IF docX;
        int count = dui.GetCenterPane.getNPages();

        while(count > 0)
        {
            count--;
            docX = GetDocX(count);
            if(docX is null) continue;
            docX.Save();
        }
        
    }
    void CloseDoc(string FullFileName = null)
    {
        DOCUMENT_IF docX;
        scope(success)Log().Entry("Document " ~ docX.FullPathName() ~ " closed.");        
 
        if(FullFileName is null)
        {
            scope(failure) return;
            int pagenumber = dui.GetCenterPane().getCurrentPage();
            docX = GetDocX(pagenumber);

            if (docX is null) throw new Exception("Nothing to Close");

            if(docX.Close())dui.GetCenterPane().removePage(pagenumber);
            return;
        }

        auto counter = dui.GetCenterPane().getNPages();
        while(counter > 0)
        {
            counter--;
            docX = GetDocX(counter);
            
            if (FullFileName == docX.FullPathName())
            {
                if(docX.Close())dui.GetCenterPane().removePage(counter);
                return;
            }
        }
    }
    void CloseAllDocs(bool Quitting = false)
    {
        DOCUMENT_IF docX;
        int pagecount;

        pagecount = dui.GetCenterPane().getNPages();
        if(pagecount > 0) Log().Entry("Documents, Closing All...");
        while(pagecount > 0)
        {
            pagecount--;
            
            docX = GetDocX(pagecount);
            if(docX is null) continue;
            if(docX.Close(Quitting))
            {
                dui.GetCenterPane().removePage(pagecount);
                Log().Entry("    Document " ~ docX.FullPathName() ~ " closed.");
            }
        }                    
    }

    void Edit(string WhichEdit)
    {
        
        
        auto docX = GetDocX();
        if(docX is null)return;        
        docX.Edit(WhichEdit);
    }

    DOCUMENT_IF GetDocX(string FullFileName)
    {
        DOCUMENT_IF docX = null;
        int count;

        count = dui.GetCenterPane().getNPages();
        while(count > 0)
        {
            count--;
            auto ScrWin = cast(ScrolledWindow) dui.GetCenterPane().getNthPage(count);
            docX = cast(DOCUMENT_IF)ScrWin.getChild();
            if (docX.FullPathName == FullFileName) return docX;
        }            
        return null;
    }
    DOCUMENT_IF GetDocX(int index = -1)
    {
        if(index == -1) index = dui.GetCenterPane().getCurrentPage();
        if(index == -1) return null;
        
        auto ScrWin = cast(ScrolledWindow) dui.GetCenterPane().getNthPage(index);
        if(ScrWin is null) return null;

        DOCUMENT_IF rVal = cast (DOCUMENT_IF) ScrWin.getChild();
        return rVal;
    }


    void AppendDocument(DOCUMENT_IF Doc, uint LineNo = 0)
    {
        ScrolledWindow ScrollWin = new ScrolledWindow(null, null);
		ScrollWin.add(Doc.GetWidget());
		ScrollWin.setPolicy(GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);

        ScrollWin.showAll();

        dui.GetCenterPane().appendPage(ScrollWin, Doc.TabWidget());
        dui.GetCenterPane().setTabReorderable(ScrollWin, 1);
        dui.GetCenterPane().setCurrentPage(ScrollWin);
        Doc.GetWidget().grabFocus();
        Doc.GotoLine(LineNo);

        //this signal has become the signal to allow other modules to connect to all docs, so
        //it is now important to call AppendDocument exactly one time for each new document.
        Event.emit("AppendDocument", Doc); 
    }


    bool IsOpenDoc(string FullFileName, bool SetFocus = false)
    {
        DOCUMENT_IF docX = null;
        int count;

        count = dui.GetCenterPane().getNPages();
        while(count > 0)
        {
            count--;
            docX = GetDocX(count);
            if (docX is null) continue;
            if (docX.FullPathName == FullFileName)
            {
                dui.GetCenterPane.setCurrentPage(docX.GetPage());
                docX.Focus();
                return true;
            }
        }            
        return false;
    }

    Action[] ContextActions()
    {
        return mContextActions;
    }

    void AddContextAction(Action Item)
    {

        mContextActions ~=  Item;
    }

    
    mixin Signal!(string, DOCUMENT_IF) Event;
}    
