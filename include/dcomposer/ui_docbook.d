module ui_docbook;

import ui;
import dcore;
import docman;
import document;

import std.conv;
import std.path;
import std.string;

import gtk.Action;
import gtk.Notebook;
import gtk.Menu;
import gtk.MenuItem;
import gtk.SeparatorMenuItem;
import gtk.Widget;
import gtk.MenuToolButton;
import gtk.ToolButton;
import gtk.Bin;
import gtk.ScrolledWindow;
import gtk.MessageDialog;
import gtk. FileChooserDialog;
import gtk.Container;

import gsv.SourceStyleSchemeManager;
import gsv.SourceView;

import gobject.Signals;
import gobject.Value;
import gobject.Type;


class UI_DOCBOOK :UI_DOCBOOK_IF
{

private:

    //following 5 lines are for using the same signal as in the sourceview context menu
    //seems a long way to go ... why textview doesn't make the action public is a mystery to me
    Value mInstanceAndParamsForSignal;
    Value mReturnValueForSignal;
    uint mUndoSignalID;
    uint mRedoSignalID;
    uint mCutSignalID;
    uint mPasteSignalID;
    uint mCopySignalID;
    
    //add history
    string[]	mRecentFiles;
    MenuItem	mRecentMenu;
    int			mMaxRecentFiles;
    
    
    void WatchForDocClose(string type, DOC_IF doc)
    {
	    if(ui.IsQuitting()) return;
	    if(type != "Close")return;
	    import std.algorithm;
	    import std.array;
	    
	    auto buf = mRecentFiles.remove!(a=>a==doc.Name).array();
	    buf ~= doc.Name;
	    if(buf.length > mMaxRecentFiles) mRecentFiles = buf[1..$];
	    else mRecentFiles = buf;
	    UpdateRecentFiles();		
    }
    
    void UpdateRecentFiles()
    {
        mRecentMenu.setSubmenu(null);
	    mRecentMenu.setUseUnderline(false);
	    auto RecentMenuItem = new Menu;
	    MenuItem[] RecentItems;
	    foreach(rfile; mRecentFiles)
	    {   
    	    RecentItems ~= new MenuItem(delegate void(MenuItem x){DocMan.Open(x.getLabel());}, rfile, false);
	    }
	    foreach(ri; RecentItems) RecentMenuItem.append(ri);
	    
	    mRecentMenu.setSubmenu(RecentMenuItem);
	    mRecentMenu.showAll();
    }



public:

    Notebook mNotebook;
    alias mNotebook this;
    this(Notebook x)
    {
        foreach(pth; StylesPath)SourceStyleSchemeManager.getDefault().appendSearchPath(pth);
        mNotebook = x;
    }

    void Engage()
    {
	    

        AddIcon("gtk-no", ResourcePath( Config.GetValue("icons", "tab-close", "cross-button.png")));
        /////////////////////////////////////////////////////////////////////////actions
        /////////////////////////////////////////////////////////////////////////
        //create
        string[] Filetypes = Config.GetArray("ui_docman", "file_types",["plain text", "D source"]);

        Menu SubMenu = new Menu;
        MenuItem[] menuitems;
        foreach(ftype; Filetypes)menuitems ~= new MenuItem(delegate void(MenuItem x){DocMan.Create(x.getLabel());}, ftype);
        foreach(mi; menuitems)SubMenu.append(mi);

        Menu ToolSubMenu = new Menu;
        MenuItem[] Toolmenuitems;
        foreach(ftype; Filetypes)Toolmenuitems ~= new MenuItem(delegate void(MenuItem x){DocMan.Create(ftype);}, ftype);
        foreach(mi; Toolmenuitems)ToolSubMenu.insert(mi,0);
        ToolSubMenu.showAll();

        AddIcon("dcmp-doc-new", ResourcePath( Config.GetValue("icons", "doc-create", "document-text.png")));
        auto tmpAct = "ActDocNew".AddAction("_New", "create a new document", "dcmp-doc-new","<Control>n",delegate void(Action a){DocMan.Create();});

        MenuItem x = new MenuItem("New _Types");//tmpAct.createMenuItem();
        x.setSubmenu(SubMenu);

        auto toolmenubutton = new MenuToolButton("dcmp-doc-new");
        toolmenubutton.setSensitive(1);
        toolmenubutton.addOnClicked(delegate void (ToolButton x){tmpAct.activate();});
        toolmenubutton.setMenu(ToolSubMenu);
        toolmenubutton.showAll();

        AddToMenuBar("ActDocNew","_Document");
        AddItemToMenuBar(x, "_Document");



        x.showAll();

        //open
        AddIcon("dcmp-doc-open", ResourcePath( Config.GetValue("icons", "doc-open", "folder-open-document-text.png")));
        auto ActOpen = "ActDocOpen".AddAction("_Open","Open a text document", "dcmp-doc-open","<Control>O",delegate void(Action a){DocMan.Open();});
        AddToMenuBar("ActDocOpen", "_Document");
		
		//recent add
		mMaxRecentFiles = 10;
	    mRecentFiles = Config.GetArray("ui_docbook", "recent_files",["/home/anthony/projects/dcomposer/src/dcore.d", "/home/anthony/projects/dcomposer/src/ui.d"]);
	    auto RecentMenuItem = new Menu;
	    MenuItem[] RecentItems;
	    foreach(rfile; mRecentFiles) RecentItems ~= new MenuItem(delegate void(MenuItem x){DocMan.Open(x.getLabel());}, rfile, false);
	    foreach(ri; RecentItems) RecentMenuItem.append(ri);
	    mRecentMenu = new MenuItem("Recent");
	    mRecentMenu.setUseUnderline(false);
	    mRecentMenu.setSubmenu(RecentMenuItem);
	    AddItemToMenuBar(mRecentMenu,"_Document");
	    mRecentMenu.showAll();
	    //recent add end

        //save
        AddIcon("dcmp-doc-save", ResourcePath( Config.GetValue("icons", "doc-save", "document-save.png")));
        auto ActSave = "ActDocSave".AddAction("_Save","Save document", "dcmp-doc-save", "<Control>S", delegate void(Action a){DocMan.Save();});
        AddToMenuBar("ActDocSave", "_Document");

        //saveas
        AddIcon("dcmp-doc-save-as", ResourcePath( Config.GetValue("icons", "doc-save-as", "document-save-as.png")));
        auto ActSaveAs = "ActDocSaveAs".AddAction("Save _As...", "Save document to new file", "dcmp-doc-save-as", "<Control><Shift>S", delegate void (Action a){DocMan.SaveAs();});
        AddToMenuBar("ActDocSaveAs", "_Document");

        //saveall
        AddIcon("dcmp-doc-save-all", ResourcePath( Config.GetValue("icons", "doc-save-all", "document-save-all.png")));
        auto ActSaveAll = "ActDocSaveAll".AddAction("Save A_ll...", "Save all documents", "dcmp-doc-save-all", "", delegate void (Action a){DocMan.SaveAll();});
        AddToMenuBar("ActDocSaveAll", "_Document");

        //close
        AddIcon("dcmp-doc-close", ResourcePath( Config.GetValue("icons", "doc-close",  "document-close.png")));
        auto ActClose = "ActDocClose".AddAction("_Close", "Close document","dcmp-doc-close","<Control>W",delegate void(Action a){DocMan.Close();});
        AddToMenuBar("ActDocClose","_Document");
        uiContextMenu.AddAction("ActDocClose");

        //closeall
        AddIcon("dcmp-doc-close-all", ResourcePath( Config.GetValue("icons", "doc-close-all",  "document-close-all.png")));
        auto ActCloseAll = "ActDocCloseAll".AddAction("Close All", "Close all documents", "dcmp-doc-close-all", "<Shift><Control>W",delegate void(Action a){DocMan.CloseAll();});
        AddToMenuBar("ActDocCloseAll", "_Document");
        uiContextMenu.AddAction("ActDocCloseAll");

        AddToMenuBar("-", "_Document");
        //compiles w/ no object file output
        AddIcon("dcmp-doc-compile", ResourcePath( Config.GetValue("icons", "doc-compile", "document-text-compile.png")));
        auto ActCompile = "ActDocCompile".AddAction("Com_pile", "Check if document compiles (no object file output)","dcmp-doc-compile", "<shift><control>C", delegate void (Action a){DocMan.Compile();});
        AddToMenuBar("ActDocCompile", "_Document");
        uiContextMenu.AddAction("ActDocCompile");

        //run with rdmd
        AddIcon("dcmp-doc-run", ResourcePath( Config.GetValue("icons", "doc-run", "document--arrow.png")));
        auto ActRun = "ActDocRun".AddAction("_Run", "Run current document with rdmd", "dcmp-doc-run", "<shift><Control>R", delegate void (Action a){DocMan.Run();});
        AddToMenuBar("ActDocRun", "_Document");
        uiContextMenu.AddAction("ActDocRun");
        
        //run unit tests
        AddIcon("dcmp-doc-unit-tests", ResourcePath( Config.GetValue("icons", "doc-unit-tests", "document-block.png")));
        auto ActUnitTests = "ActDocUnitTests".AddAction("_Unit Tests", "Run current documents unit tests", "dcmp-doc-unit-tests", "<shift><control>U", delegate void (Action a){DocMan.UnitTests();});
        AddToMenuBar("ActDocUnitTests","_Document");
        uiContextMenu.AddAction("ActDocUnitTests");
        
        //toggle coverage
        AddIcon("dcmp-doc-hide-coverage", ResourcePath( Config.GetValue("icons", "doc-hide-coverage", "switch.png")));
        auto ActDocHideCoverage = "ActDocHideCoverage".AddAction("Toggle _coverage", "Show/Hide code coverage in gutter", "dcmp-doc-hide-coverage", "<control><shift>H", delegate void (Action a){DocMan.HideGutterCoverage();});
        uiContextMenu.AddAction("ActDocHideCoverage");

        //=============================================================================================================
        //=============================================================================================================
        //                                                         undo redo

        //undo
        AddIcon("dcmp-undo", ResourcePath( Config.GetValue("icons", "undo", "arrow-curve-180-left.png")));
        auto ActUndo = "ActUndo".AddAction("_Undo", "undo last change", "dcmp-undo", "<Control>U", delegate void(Action a){DocMan.Undo();});
        AddToMenuBar("ActUndo", "_Edit");


        //redo
        AddIcon("dcmp-redo", ResourcePath( Config.GetValue("icons", "redo", "arrow-curve.png")));
        auto ActRedo = "ActRedo".AddAction("_Redo", "redo last undo", "dcmp-redo", "<Control>R", delegate void(Action a){DocMan.Redo();});
        AddToMenuBar("ActRedo", "_Edit");


        AddToMenuBar("-", "_Edit");

        //=============================================================================================================
        //=============================================================================================================
        //                                                         edit stuff (cut copy paste)


        //cut
        AddIcon("dcmp-edit-cut", ResourcePath( Config.GetValue("icons", "edit-cut",  "scissors-blue.png")));
        auto ActEditCut = "ActEditCut".AddAction("Cu_t", "cut selected text", "dcmp-edit-cut", "<Control>X", delegate void(Action a){DocMan.Cut();});
        ActEditCut.setSensitive(false);
        AddToMenuBar("ActEditCut", "_Edit");


        //copy
        AddIcon("dcmp-edit-copy", ResourcePath( Config.GetValue("icons", "edit-copy", "blue-document-copy.png")));
        auto ActEditCopy = "ActEditCopy".AddAction("_Copy", "copy selected text", "dcmp-edit-copy", "<Control>C", delegate void(Action a){DocMan.Copy();});
        ActEditCopy.setSensitive(false);
        AddToMenuBar("ActEditCopy", "_Edit");


        //paste
        AddIcon("dcmp-edit-paste", ResourcePath( Config.GetValue("icons", "edit-paste", "clipboard-paste-document-text.png")));
        auto ActEditPaste = "ActEditPaste".AddAction("_Paste", "paste clipboard", "dcmp-edit-paste", "<Control>V", delegate void(Action a){DocMan.Paste();});
        AddToMenuBar("ActEditPaste", "_Edit");

        //prevPage
        auto ActPrevDoc = "ActPrevDoc".AddAction("prev Doc", "Switch document", "", "<Control>bracketleft",delegate void(Action a){mNotebook.prevPage();});
        AddToMenuBar("ActPrevDoc", "_Edit");
        ActPrevDoc.setVisible(false);

        //nextPage
        auto ActNextDoc = "ActNextDoc".AddAction("next Doc", "Switch document", "", "<Control>bracketright",delegate void(Action a){mNotebook.nextPage();});
        AddToMenuBar("ActNextDoc", "_Edit");
        ActNextDoc.setVisible(false);
        Log.Entry("Engaged");
        
        //receive drag and drop files
        dragDestSet(DestDefaults.ALL, null, DragAction.COPY);
        dragDestAddTextTargets();            
        addOnDragDataReceived(delegate void(DragContext dc, int i1, int i2, SelectionData sd, uint u1, uint u2, Widget w)
        {
            foreach(line; sd.getText().lineSplitter())
            {
                if(!line.startsWith("file://"))continue;
                DocMan.Open(line[6..$]);
            }
        });

    }

    void PostEngage()
    {
        //GTK complains (and craps out) if DOCUMENT not loaded so force it
        //probably a better way but I'm a dumby
        auto x = new DOCUMENT;

        //recent files add
        DocMan.Event.connect(&WatchForDocClose);
        //recent files end

        mInstanceAndParamsForSignal = new Value;
        mInstanceAndParamsForSignal.init(GType.OBJECT);
        mReturnValueForSignal = new Value;
        mReturnValueForSignal.init(GType.OBJECT);
        mRedoSignalID = Signals.lookup("redo", DOCUMENT.getType());
        mUndoSignalID = Signals.lookup("undo", DOCUMENT.getType());
        mPasteSignalID = Signals.lookup("paste-clipboard", Type.fromName("GtkTextView"));
        mCutSignalID = Signals.lookup("cut-clipboard", Type.fromName("GtkTextView"));
        mCopySignalID = Signals.lookup("copy-clipboard", Type.fromName("GtkTextView")) ;
        Log.Entry("PostEngaged");
    }

    void Disengage()
    {
	    //recent files add
	    Config.SetArray("ui_docbook","recent_files", mRecentFiles);
	    //recent files add end
	    
        Log.Entry("Disengaged");
    }

    @property DOC_IF Current()
    {
        auto indx = getCurrentPage();
        if(indx < 1) return null;  //would be zero but 0 index is project options page (maybe 1 will be preference page)
        ScrolledWindow scrwin = cast(ScrolledWindow)getNthPage(indx);
        if(scrwin is null) return null;
        auto doc = cast(DOC_IF)scrwin.getChild();
        return doc;
    }
    @property void Current(DOC_IF nuCurrent)
    {
        DOCUMENT tmp = cast(DOCUMENT) nuCurrent;
        if(tmp is null) return;
        setCurrentPage(tmp.PageWidget());
    }

    void Append(DOC_IF nuDoc)
    {
        auto xDoc = cast(DOCUMENT) nuDoc;
        auto indx = appendPage(xDoc.PageWidget, xDoc.PageTab);
        setTabReorderable(xDoc.PageWidget, 1);
        setCurrentPage(xDoc.PageWidget);// <- this gives wierd and annoying gtk warnings about size allocation so using
        setFocusChild(xDoc.PageWidget);
        setMenuLabelText(xDoc.PageWidget,xDoc.TabLabel);
        xDoc.grabFocus();
    }

    void Create(string somekindatype = "unknown")
    {
        DocMan.Create(somekindatype);
    }
    void Open()
    {
    }
    void Save()
    {
    }


    bool ConfirmCloseFile(DOC_IF DocToClose)
    {
        auto ConfClosing = new MessageDialog(MainWindow, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, false, "");
        if(!DocToClose.Modified) return true;

        ConfClosing.setTitle("Confirm closing modified document.");
        ConfClosing.addButtons(["Save and close", "Discard and close", "Do not Close"], [ResponseType.YES, ResponseType.NO, ResponseType.CANCEL]);
        ConfClosing.setMarkup("There are unsaved changes to\n<b><big>" ~ DocToClose.TabLabel ~ "</big></b>\nHow do you wish to proceed?");
        auto rv = ConfClosing.run();
        ConfClosing.destroy();

        if (rv == ResponseType.CANCEL) return false;
        if (rv == ResponseType.NO) return true;
        DocMan.Save(DocToClose);
        return true;

    }
    string[] OpenDialog()
    {
        string[] rv;
        auto OD = new  FileChooserDialog("What file(s) do you wish to DCompose", null, FileChooserAction.OPEN);
        scope(exit)OD.destroy;
        OD.setSelectMultiple(true);
        OD.setCurrentFolder(CurrentPath());
        auto resp = OD.run();

        if(resp != ResponseType.OK)return rv;

        auto sinlist = OD.getFilenames();


        while(sinlist)
        {
            auto txt = text(cast(char*)sinlist.data());
            if(txt is null) continue;
            rv ~= txt;
            sinlist = sinlist.next();
        }
        return rv ;
    }
    string SaveAsDialog(string PrevName)
    {
        string rv;
        auto SAD = new FileChooserDialog("Bury the DComposed document as ...", null, FileChooserAction.SAVE);
        SAD.setCurrentName(baseName(PrevName));
        SAD.setCurrentFolder(dirName(PrevName));
        SAD. setDoOverwriteConfirmation(true);
        auto resp = SAD.run();

        if(resp != ResponseType.OK)
        {
            SAD.destroy();
            return rv;
        }

        rv = SAD.getFilename();
        SAD.destroy();
        return rv;
    }


    void ClosePage(DOC_IF closeDoc)
    {
        auto doc = cast(DOCUMENT) closeDoc;
        auto page = doc.PageWidget();
        auto pageindex = pageNum(page);
        removePage(pageindex);
    }
    void Revert()
    {
        auto xdoc = cast(DOCUMENT)Current();
        while(xdoc.getBuffer().getUndoManager().canUndo()) Undo();
    }
    void Undo()
    {
        auto xdoc = cast (DOCUMENT)Current();
        if(xdoc is null) return;
        //xdoc.getBuffer.undo();
        mInstanceAndParamsForSignal.setObject(xdoc);
        mReturnValueForSignal.setObject(xdoc);
        Signals.emitv([mInstanceAndParamsForSignal],mUndoSignalID, 0u, mReturnValueForSignal);
    }
    void Redo()
    {
        auto xdoc = cast (DOCUMENT)Current();
        if(xdoc is null) return;
        //xdoc.getBuffer.redo();

        mInstanceAndParamsForSignal.setObject(xdoc);//.getSourceViewStruct());
        mReturnValueForSignal.setObject(xdoc);//.getSourceViewStruct());
        Signals.emitv([mInstanceAndParamsForSignal], mRedoSignalID, 0u, mReturnValueForSignal);
    }

    void Cut()
    {
        auto xdoc = cast(DOCUMENT)Current();
        if(xdoc is null) return;

        mInstanceAndParamsForSignal.setObject(xdoc);//.getTextViewStruct());
        mReturnValueForSignal.setObject(xdoc);//.getTextViewStruct());
        Signals.emitv([mInstanceAndParamsForSignal], mCutSignalID, 0u, mReturnValueForSignal);
    }
    void Copy()
    {
        auto xdoc = cast(DOCUMENT)Current();
        if(xdoc is null) return;

        mInstanceAndParamsForSignal.setObject(xdoc);//.getTextViewStruct());
        mReturnValueForSignal.setObject(xdoc);//.getTextViewStruct());
        Signals.emitv([mInstanceAndParamsForSignal], mCopySignalID, 0u, mReturnValueForSignal);
    }

    void Paste()
    {
        auto xdoc = cast(DOCUMENT)Current();
        if(xdoc is null)return;

        mInstanceAndParamsForSignal.setObject(xdoc);//.getTextViewStruct());
        mReturnValueForSignal.setObject(xdoc);//.getTextViewStruct());
        Signals.emitv([mInstanceAndParamsForSignal], mPasteSignalID, 0u, mReturnValueForSignal);
    }

    void NotifySelection()
    {
        if(Current is null) return;
        auto xcut = mActions.getAction("ActEditCut");
        auto xcopy = mActions.getAction("ActEditCopy");
        if(Current.Selection() == "")
        {
            xcut.setSensitive(false);
            xcopy.setSensitive(false);
        }
        else
        {
            xcut.setSensitive(true);
            xcopy.setSensitive(true);
        }
    }

    void NextPage() { mNotebook.nextPage();}
    void PrevPage() { mNotebook.prevPage();}


}



