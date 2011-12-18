//      docman.d
//      
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//      
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//      
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//      
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.

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
    bool        Create(string Identifier);
    bool        Open(string FileName, ulong LineNo = 1);
    bool        Save();
    bool        SaveAs(string NewName);
    bool        Close(bool Quitting = false);

    @property   string DisplayName();
    @property   string FullName();
    @property   void FullName(string NuName);
    string      GetDisplayName();
    string      GetFullFileName();
    bool        IsModified();
    bool        IsVirgin();
    Widget      GetTab();
    Widget      GetPage();
    void        GrabFocus();

    void        Edit(string Verb);
    void        GotoLine(int Line);
}



class DOCMAN
{

    private:
    uint                mUnTitledCount;

    string              mLastFileDialogDirectory;

    FileFilter[string]  mFileFilters;

    public:

    void Engage()
    {
        mLastFileDialogDirectory = "./";
        string[] LastSessionFiles = Config().getString("DOCMAN", "files_last_session").split(";");
        string[] CmdLineFiles = Config().getString("DOCMAN", "files_to_open").split(";");
        


        CreateActions();
        OpenDocs(LastSessionFiles);
        OpenDocs(CmdLineFiles);
        
        Log.Entry("Engaged DOCMAN");


        //file filters
        auto ff = new FileFilter;
        ff.setName("D source files");
        ff.addMimeType("text/x-dsrc");
        mFileFilters["dsource"] = ff;

        ff = new FileFilter;
        ff.setName("D project files");
        ff.addPattern("*.dpro");
        mFileFilters["dproject"] = ff;

        ff = new FileFilter;
        ff.setName("Text files");
        ff.addMimeType("text/plain");
        mFileFilters["text"] = ff;
        
    }

    void Disengage()
    {
        

        //save all docs open in session to config file
        string DocsToOpenNextSession;

        DOCUMENT_IF docX;

        auto ocnt = dui.GetCenterPane().getNPages();
        while(ocnt > 0)
        {
            ocnt--;
            docX = GetDocX(ocnt);
            if(docX is null) continue;
            if(docX.IsVirgin())continue;
            DocsToOpenNextSession~= docX.GetFullFileName() ~ ";";
            //if(ocnt != 0) DocsToOpenNextSession ~= ";";
        }
        DocsToOpenNextSession = DocsToOpenNextSession.chomp(";");
        if(DocsToOpenNextSession.empty)DocsToOpenNextSession =  "";
        Config().setString("DOCMAN", "files_last_session", DocsToOpenNextSession);
        Config().setString("DOCMAN", "files_to_open","");

        //verify saving or discarding any modified docs
        CloseAllDocs(true);
        Log().Entry("Disengaged DOCMAN");
    }

    DOCUMENT_IF CreateDoc(string DocType = ".d")
    {
        string TitleString = std.string.format("DComposer%.3s", mUnTitledCount++);
        TitleString ~= DocType;

        DOCUMENT_IF NuDoc;

        scope(failure) Log().Entry("Document " ~ TitleString ~ " failed creation" , "Error");
        scope(success)         Log().Entry("Document " ~ TitleString ~ " created.");

        //now this assumes we're creating a DOCUMENT ... how to improve this for different file types ???
        NuDoc = new DOCUMENT;
        
        NuDoc.Create(TitleString);

        AppendDocument(NuDoc);
        
        return NuDoc;
    }
    void OpenDoc()
    {
        auto DocFiler = new FileChooserDialog
                            (
                                "Which files to DCompose?",
                                dui.GetWindow(),
                                FileChooserAction.OPEN
                            );
        DocFiler.addShortcutFolder(".");
        DocFiler.addShortcutFolder("/usr/include/d/dmd/phobos/std/");
        DocFiler.setSelectMultiple(1);
        DocFiler.setCurrentFolder(mLastFileDialogDirectory);
        foreach(filter; mFileFilters)DocFiler.addFilter(filter);
        DocFiler.setFilter(mFileFilters["dsource"]);
        auto DialogReturned = DocFiler.run();
        DocFiler.hide();
        
        if (DialogReturned != ResponseType.GTK_RESPONSE_OK) return;
        
        mLastFileDialogDirectory = DocFiler.getCurrentFolder();

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
            return;
        }
        
        auto DocX = GetDocX(FullFileName);
        if (DocX is null) return;
        
        DocX.GotoLine(LineNo);
               
        return ;
    }
    void OpenDocs(string[] FullFileNames)
    {

        foreach(f;FullFileNames)
        {

            scope(failure){Log.Entry("Document: "~f~" failed to open.", "Error"); continue;}
            scope(success)Log.Entry("Document: "~f~" opened.");
            if(IsOpenDoc(f, true))continue;
            
            //stuck again ... for now just able to open DOCUMENTs
            //gotta change this ... (maybe later dcomposer will open rad gui form builders or images or anything)
            auto DocX = new DOCUMENT;
            if(DocX.Open(f))AppendDocument(DocX);
            else throw new Exception("bad file?");
        }
    }
            
    void SaveDoc()
    {
        auto docX = GetDocX();
        if(docX is null) return;

        if(docX.IsVirgin())return SaveAsDoc(docX);
        docX.Save();

        scope(success)Log.Entry("Document :"~docX.FullName ~ " saved.");
        scope(failure)Log.Entry("Document :"~docX.FullName ~ " failed to save.", "Error");
    }
    void SaveAsDoc(DOCUMENT_IF docX = null)
    {
        
        
        if(docX is null) docX = GetDocX();
        if(docX is null) return;
        string presaveas = docX.FullName;

        auto DocFiler = new FileChooserDialog
                            (
                                "Bury DComposed Files ...",
                                dui.GetWindow(),
                                FileChooserAction.SAVE
                            );
        DocFiler.addShortcutFolder(".");
        DocFiler.setCurrentFolder(mLastFileDialogDirectory);
        DocFiler.setCurrentName(presaveas);
        foreach(filter; mFileFilters)DocFiler.addFilter(filter);
        DocFiler.run();
        DocFiler.hide();
        mLastFileDialogDirectory = DocFiler.getCurrentFolder();

        docX.SaveAs(DocFiler.getFilename);

        scope(success)Log.Entry("Document :"~ presaveas ~ " saved as " ~ docX.FullName ~".");
        scope(failure)Log.Entry("Document :"~ presaveas ~ " failed to save as "~ DocFiler.getFilename ~ ".", "Error");
        
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
            if(docX.IsVirgin)
            {
                SaveAsDoc(docX);
                continue;
            }
            docX.Save();
        }
        
    }
    
    void CloseDoc(string FullFileName = null)
    {
        DOCUMENT_IF docX;
        scope(success)Log().Entry("Document " ~ docX.GetFullFileName() ~ " closed.");
        
 
        if(FullFileName is null)
        {
            int pagenumber = dui.GetCenterPane().getCurrentPage();
            docX = GetDocX(pagenumber);

            if (docX is null) throw new Exception("Nothing to Close");
            scope(failure) return;
            if(docX.Close())dui.GetCenterPane().removePage(pagenumber);
            return;
        }

        auto counter = dui.GetCenterPane().getNPages();
        while(counter > 0)
        {
            counter--;
            docX = GetDocX(counter);
            
            if (FullFileName == docX.GetFullFileName())
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
                Log().Entry("    Document " ~ docX.GetFullFileName() ~ " closed.");
            }
        }
                    
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
            if (docX.FullName == FullFileName)
            {
                dui.GetCenterPane.setCurrentPage(docX.GetPage.getParent());
                docX.GrabFocus();

                return true;
            }
        }            
        return false;
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
            if (docX.FullName == FullFileName) return docX;
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


    void CreateActions()
    {

        Action  CreateAct   = new Action("CreateAct","_New ", "Create a new text document", StockID.NEW);
        Action  OpenAct     = new Action("OpenAct","_Open", "Open a file", StockID.OPEN);
        Action  SaveAct     = new Action("SaveAct", "_Save", "Save current document", StockID.SAVE);
        Action  SaveAsAct   = new Action("SaveAsAct", "Save _As..","Save current document to different file", StockID.SAVE_AS);
        Action  SaveAllAct  = new Action("SaveAllAct", "Save A_ll", "Save all documents", null);
        Action  CloseAct    = new Action("CloseAct", "_Close", "Close current document", StockID.CLOSE);
        Action  CloseAllAct = new Action("CloseAllAct", "Clos_e All", "Close all documents", null);


        CreateAct.addOnActivate(delegate void(Action X){CreateDoc();});
        OpenAct.addOnActivate(delegate void(Action X){OpenDoc();});
        SaveAct.addOnActivate(delegate void(Action X){SaveDoc();});
        SaveAsAct.addOnActivate(delegate void(Action X){SaveAsDoc();});
        SaveAllAct.addOnActivate(delegate void(Action X){SaveAllDocs();});
        CloseAct.addOnActivate(delegate void(Action X){CloseDoc();});
        CloseAllAct.addOnActivate(delegate void(Action X){CloseAllDocs();});

        CreateAct.setAccelGroup(dui.GetAccel());  
        OpenAct.setAccelGroup(dui.GetAccel());
        SaveAct.setAccelGroup(dui.GetAccel());    
        SaveAsAct.setAccelGroup(dui.GetAccel());  
        SaveAllAct.setAccelGroup(dui.GetAccel()); 
        CloseAct.setAccelGroup(dui.GetAccel());   
        CloseAllAct.setAccelGroup(dui.GetAccel());
        
        dui.GetActions().addActionWithAccel(CreateAct  , null);
        dui.GetActions().addActionWithAccel(OpenAct    , null);
        dui.GetActions().addActionWithAccel(SaveAct    , null);
        dui.GetActions().addActionWithAccel(SaveAsAct  , null);
        dui.GetActions().addActionWithAccel(SaveAllAct , null);
        dui.GetActions().addActionWithAccel(CloseAct   , null);
        dui.GetActions().addActionWithAccel(CloseAllAct, null);

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
        m.insert(new MenuItem(delegate void(MenuItem mi){CreateDoc(".d");},     "_D source file"), 0);
        m.insert(new MenuItem(delegate void(MenuItem mi){CreateDoc(".lua");},   "_Lua source file"), 1);
        m.insert(new MenuItem(delegate void(MenuItem mi){CreateDoc(".c");},     "_C source file"), 1);
        m.insert(new MenuItem(delegate void(MenuItem mi){CreateDoc(".cpp");},   "C_++ source file"), 1);
        m.insert(new MenuItem(delegate void(MenuItem mi){CreateDoc(".xml");},   "_XML file"), 1);
        m.insert(new MenuItem(delegate void(MenuItem mi){CreateDoc(".html");},  "_HTML file"), 1);
        
        
        
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

        dui.GetActions().addActionWithAccel(UndoAct   , null);
        dui.GetActions().addActionWithAccel(RedoAct   , null);
        dui.GetActions().addActionWithAccel(CutAct    , null);
        dui.GetActions().addActionWithAccel(CopyAct   , null);
        dui.GetActions().addActionWithAccel(PasteAct  , null);
        dui.GetActions().addActionWithAccel(DeleteAct , null);
        dui.GetActions().addActionWithAccel(SelAllAct , null);
        dui.GetActions().addActionWithAccel(SelNoneAct , null);

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
        

    void AppendDocument(DOCUMENT_IF Doc, uint LineNo = 0)
    {
        ScrolledWindow ScrollWin = new ScrolledWindow(null, null);
		ScrollWin.add(Doc.GetPage());
		ScrollWin.setPolicy(GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);

        ScrollWin.showAll();

        dui.GetCenterPane().appendPage(ScrollWin, Doc.GetTab());
        dui.GetCenterPane().setTabReorderable(ScrollWin, 1);
        dui.GetCenterPane().setCurrentPage(ScrollWin);
        Doc.GetPage().grabFocus();
        Doc.GotoLine(LineNo);

        Appended.emit(Doc);
    }



    void Edit(string WhichEdit)
    {
        
        
        auto docX = GetDocX();
        if(docX is null)return;
        
        docX.Edit(WhichEdit);
    }
        
    mixin Signal!(DOCUMENT_IF) Appended;
}
        
    
    
