// docman2.d
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
import std.algorithm;
import std.parallelism;

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
import  gtk.CheckButton;
import  gtk.SpinButton;
import  gtk.FontButton;
import  gtk.ComboBox;
import  gtk.ListStore;
import  gtk.TreeIter;
import  gtk.Label;

import  glib.ListSG;



class DOCMAN
{
	private:
	
	uint				mUntitledCount;		///number to add to filenames of as yet unnamed files

	string[]			mStartUpFiles;		///need to store startup files until everything is engaged then open them

	Action[]			mContextMenuActs;	///Actions which will be added to context menu

	DOCUMENT[string]	mDocs;				///all open docs indexed by their file name
	
	FileFilter[string]	mFileFilters;		///holds the filters for open file dialog
	FileChooserDialog	mOpenFileDialog;	///Dialog to open files
	FileChooserDialog	mSaveFileDialog;	///Dialog to save (as) file

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


        CreateAct.addOnActivate     (delegate void(Action X){Create();});
        OpenAct.addOnActivate       (delegate void(Action X){Open();});
        SaveAct.addOnActivate       (delegate void(Action X){Save();});
        SaveAsAct.addOnActivate     (delegate void(Action X){SaveAs();});
        SaveAllAct.addOnActivate    (delegate void(Action X){SaveAll();});
        CloseAct.addOnActivate      (delegate void(Action X){Close();});
        CloseAllAct.addOnActivate   (delegate void(Action X){CloseAll();});

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
        dui.Actions.addActionWithAccel(CloseAllAct, "<Shift><Ctrl>W");

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


        //ok now the edit actions
        Action      UndoAct     = new Action("UndoAct","_Undo", "Undo last action", StockID.UNDO);
        Action      RedoAct     = new Action("RedoAct","_Redo", "Undo the last undo(ie redo)", StockID.REDO);
        Action      CutAct      = new Action("CutAct", "_Cut", "Remove selected text to clipboard", StockID.CUT);
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


    void LoadStartUpFiles()
    {
		mStartUpFiles = Config().getString("DOCMAN", "files_last_session").split(";");   //files open last session
        mStartUpFiles.reverse();
        mStartUpFiles ~=  Config().getString("DOCMAN", "files_to_open").split(";");      //files from command line

        string startupfiles;
        foreach (suf; mStartUpFiles) startupfiles ~= suf;
        Log.Entry("Start Up Files = " ~ startupfiles, "Debug");
	}

	void StoreOpenSessionFiles()
	{
		string StorageData;
		foreach(Doc; mDocs)StorageData ~= Doc.Name ~ ":" ~ to!string(Doc.LineNumber) ~ ";";
		if(StorageData.empty) StorageData = "";
		Config().setString("DOCMAN", "files_last_session", StorageData);
        Config().setString("DOCMAN", "files_to_open",""); //get rid of command line files
	}

	void LoadFileFilters()
    {
		//make sure these are always available
        Config.setString("DOC_FILTERS", "dsrc", "D source file;mime;text/x-dsrc");
        Config.setString("DOC_FILTERS", "text", "Text files;mime;text/plain");
        Config.setString("DOC_FILTERS", "dpro", "DComposer project files;pattern;*.dpro");
        Config.setString("DOC_FILTERS", "*"	  , "All Files;pattern;*");
        Config.setString("DOC_FILTERS", "TEST", "THIS; is a test of the docman file filter system!");

        
        string[] FilterKeys = Config.getKeys("DOC_FILTERS");

        foreach(i, key; FilterKeys)
        {
            string[] data = Config.getString("DOC_FILTERS", key).split(";");
            if(data.length  != 3 )
            {
				Log.Entry("DocManager detected malformed file filter", "Error");
				continue;
			}
            mFileFilters[key] = new FileFilter;
            mFileFilters[key].setName(data[0]);
            

            if(data[1] == "mime")mFileFilters[key].addMimeType(data[2]);
            if(data[1] == "pattern")mFileFilters[key].addPattern(data[2]);
        }
    }		
		
	public :

	@property DOCUMENT Current()
	{
		auto index = dui.GetCenterPane().getCurrentPage();
		if (index < 0) return null;
		auto tmpvarScrWin = cast(ScrolledWindow) dui.GetCenterPane().getNthPage(index);
		return cast(DOCUMENT)tmpvarScrWin.getChild();
	}

	@property DOCUMENT[string] Documents(){return mDocs;}
	 

	///Create a New DocMan (Document Manager)
	this()
	{
		mOpenFileDialog = new FileChooserDialog
								(
									"What files do you wish to DCompose?",
									dui.GetWindow(),
									FileChooserAction.OPEN
								);

		mOpenFileDialog.setSelectMultiple(true);

		LoadFileFilters();
		foreach(filter; mFileFilters)mOpenFileDialog.addFilter(filter);
        mOpenFileDialog.setFilter(mFileFilters["dsrc"]);

		mSaveFileDialog = new FileChooserDialog
								(
									"Bury DComposed File ... ",
									dui.GetWindow(),
									FileChooserAction.SAVE
								);
	}

	void Engage()
	{
		///get last session files and cmdline files to open later (after everything is engaged)
		LoadStartUpFiles();

		///Creates all document related actions (adds menu and toolbar stuff too)	
		CreateActions();

		Log.Entry("Engaged DOCMAN");
	}

	void Disengage()
	{
		StoreOpenSessionFiles();
		CloseAll(true);
	}


	void AddContextMenuAction(Action NewAction)
	{
		mContextMenuActs ~= NewAction;
	}	
	Action[] GetContextMenuActions(){return mContextMenuActs;}

	void Edit(string EditAction)
	{
		if (Current is null) return;
		Current.Edit(EditAction);
	}


	bool IsOpen(string Name, bool  SetFocus = false)
	{
		if(Name !in mDocs) return false;

		if (SetFocus)mDocs[Name].grabFocus();
		return true;
	}

	void GotoLine(ulong LineNumber)
	{
		if(Current !is null)Current.GotoLine(LineNumber);
	}

	string GetWord()
	{
		if(Current !is null)return Current.Word;
		return null;
	}
	ulong GetLine()
	{
		if(Current !is null)return Current.LineNumber;
		return -1;
	}
	string GetLine()
	{
		if(Current !is null)return Current.LineText;
		return null;
	}

	bool HasModifiedDocs()
	{
		foreach(doc; mDocs) if (doc.Modified) return true;
		return false;
	}

	string GetText()
	{
		if(Current !is null)return Current.getBuffer().getText();
		return null;
	}

	DOCUMENT GetDocument(string Name = null)
	{
		if(Name is null) return Current;
		if(Name !in mDocs) return null;
		return mDocs[Name];
	}

	void Create(string extension = ".d")
	{

		if(extension.length > 0)
		{
			if(extension[0] != '.') extension = '.' ~ extension;
		}
		static UnTitledCount = 0;
		string TitleString;
		do
		{
			TitleString = std.string.format("DComposer%.3s%s", UnTitledCount++, extension);
			TitleString = buildPath(getcwd(), TitleString);
		}while (exists(TitleString));

        scope(failure) {Log().Entry("Document " ~ TitleString ~ " failed creation" , "Error"); return;}
        scope(success) Log().Entry("Document " ~ TitleString ~ " created.");

        auto NuDoc = DOCUMENT.Create(TitleString);

        Append(NuDoc);
    }

	void Open()
	{
		auto response = mOpenFileDialog.run();
		mOpenFileDialog.hide();

		if (response != ResponseType.GTK_RESPONSE_OK) return;
        
        ListSG   ListOfFiles = mOpenFileDialog.getFilenames();
        //ArrayOfFiles.length = ListOfFiles.length();


		while(ListOfFiles !is null)
		{
			auto f = toImpl!(string, char *)(cast(char*)ListOfFiles.data());
			Open(f);
			ListOfFiles = ListOfFiles.next();
		}

	}

	void Open(string DocPath, ulong LineNo = 0)
	{
        DocPath = DocPath.absolutePath;

        if(!IsOpen(DocPath, true))
        {
            scope(failure){Log.Entry("Document: "~DocPath~" failed to open.", "Error"); return;}
            scope(success)Log.Entry("Document: "~DocPath~" opened.");

            auto Doc = DOCUMENT.Open(DocPath, LineNo);
            if(Doc !is null)
            {
                Append(Doc, LineNo);   
            }            
            return;
        }        
        mDocs[DocPath].GotoLine(LineNo);             
        return ;
    }

    void Save()
    {
		if (Current is null) return;
        scope(success)Log.Entry("Document :"~Current.Name ~ " saved.");
        scope(failure){Log.Entry("Document :"~Current.Name ~ " failed to save.", "Error"); return;}
		if (Current.Virgin) return SaveAs();
		Current.Save();		
	}

	void SaveAs()
	{
		if(Current is null) return;
		string OriginalName = Current.Name;
		
		mSaveFileDialog.setCurrentName(OriginalName);
		auto response = mSaveFileDialog.run();
		mSaveFileDialog.hide();

		if (response != ResponseType.GTK_RESPONSE_OK) return;

		scope(failure)
		{
			Log.Entry("Document Failed to save "~OriginalName~" as "~mSaveFileDialog.getFilename, "Error");
			return;
		}
		scope (success) Log.Entry("Document saved "~OriginalName~" as "~mSaveFileDialog.getFilename);
		
		
		Current.SaveAs(mSaveFileDialog.getFilename);
	}

	void SaveAll()
	{
		foreach(Doc; mDocs) Doc.Save();
	}
		
	void CloseAll(bool Quitting = false)
	{
		string[] KeysToClose;
		foreach (key, Doc; mDocs)
		{
			if(Doc.Close(Quitting))
			{
				KeysToClose ~= key;
				auto PageNumber = dui.GetCenterPane().pageNum(Doc.PageWidget());
				dui.GetCenterPane().removePage(PageNumber);
			}
		}
		foreach(key; KeysToClose)
		{
			Log.Entry("Document: "~key~" closed.");

			mDocs[key].Disengage();
			Event.emit("CloseDocument", mDocs[key]);
			mDocs.remove(key);
		}			
		
	}

	void Close(DOCUMENT XDoc = null, bool Quitting = false)
	{
		
		if(XDoc is null)
		{
			XDoc = Current;
			if(XDoc is null)return;
		}
		if(!XDoc.Close(Quitting)) return;

		mDocs.remove(XDoc.Name);
		auto PageNumber = dui.GetCenterPane().pageNum(XDoc.PageWidget());
		dui.GetCenterPane().removePage(PageNumber);

		XDoc.Disengage();

		Log.Entry("Document: "~XDoc.Name~" closed.");

		Event.emit("CloseDocument", XDoc);

	}

	void Append(DOCUMENT ADoc, ulong LineNo = 0)
	{

		mDocs[ADoc.Name] = ADoc;
		ScrolledWindow ScrollWin = new ScrolledWindow(null, null);
		ScrollWin.add(ADoc);
		ScrollWin.setPolicy(GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);

		
		dui.GetCenterPane().appendPageMenu(ADoc.PageWidget(), ADoc.TabWidget(), new Label(ADoc.ShortName));

		dui.GetCenterPane().setTabReorderable(ADoc.PageWidget, 1);
        ScrollWin.showAll();
        dui.GetCenterPane().setCurrentPage(ADoc.PageWidget);
        ADoc.grabFocus();
        
        //this signal has become the signal to allow other modules/elements to connect to all docs, so
        //it is now important to call AppendDocument exactly one time for each new document.
        Event.emit("AppendDocument", ADoc);

        ADoc.GotoLine(LineNo);

	}

	void OpenInitialDocs()
	{
		ulong LineInFile;
		foreach(initfile; mStartUpFiles) 
		{
			auto colon = std.string.indexOf(initfile, ":");
			if(colon < 1)
			{
				LineInFile = 0;
				colon = initfile.length;
			}
			else
			{
				LineInFile = to!ulong(initfile[colon+1..$]);
			}

			auto NameOfFile = initfile[0..colon];
			if(NameOfFile.length < 1) continue;
			Open(NameOfFile, LineInFile);
		}
	}
	
	mixin Signal!(string, DOCUMENT) Event;
}
	
class DOC_PAGE : PREFERENCE_PAGE
{
    //indention??? I think I meant indentation.
    
    CheckButton     mAutoIndent;
    CheckButton     mIndentOnTab;
    CheckButton     mSpacesForTab;
    CheckButton     mSmartHome;
    CheckButton     mHiliteCurrentLine;
    CheckButton     mShowLineNumbers;
    CheckButton     mShowRightMargin;
    CheckButton     mHiliteSyntax;
    CheckButton     mMatchBrackets;

    SpinButton      mRightMargin;
    SpinButton      mIndentionWidth;
    SpinButton      mTabWidth;
    FontButton      mFontStuff;
    ComboBox        mStyleBox;
    ListStore       mStyleChoices;
    

    this(string PageName, string FrameTitle)
    {
        super(PageName, Config.getString("PREFERENCES", "glade_file_docman", "~/.neontotem/dcomposer/docprefs.glade"));
        mFrame.showAll();

        mAutoIndent         = cast(CheckButton) mBuilder.getObject("autoindentchkbtn");
        mIndentOnTab        = cast(CheckButton) mBuilder.getObject("indentontabchkbtn");
        mSpacesForTab       = cast(CheckButton) mBuilder.getObject("spacesfortabchkbtn");
        mSmartHome          = cast(CheckButton) mBuilder.getObject("smarthomechkbtn");
        mHiliteCurrentLine  = cast(CheckButton) mBuilder.getObject("hilitelinechkbtn");
        mShowLineNumbers    = cast(CheckButton) mBuilder.getObject("linenumberschkbtn");
        mShowRightMargin    = cast(CheckButton) mBuilder.getObject("showrightmarginchkbtn");
        mHiliteSyntax       = cast(CheckButton) mBuilder.getObject("hilitesyntaxchkbtn");
        mMatchBrackets      = cast(CheckButton) mBuilder.getObject("matchbracketschkbtn");

        mRightMargin        = cast(SpinButton)  mBuilder.getObject("rightmarginspin");
        mIndentionWidth     = cast(SpinButton)  mBuilder.getObject("indentionspin");
        mTabWidth           = cast(SpinButton)  mBuilder.getObject("tabspin");
        mFontStuff          = cast(FontButton)  mBuilder.getObject("fontbutton");
        mStyleBox           = cast(ComboBox)    mBuilder.getObject("stylebox");

        //lordy lordy what a powerful heap of typin' this here is turnin' out to be

        mRightMargin.setRange(ulong.min, ulong.max);
        mRightMargin.setIncrements(1, -1);
        mIndentionWidth.setRange(ulong.min, ulong.max);
        mIndentionWidth.setIncrements(1, -1);
        mTabWidth.setRange(ulong.min, ulong.max);
        mTabWidth.setIncrements(1, -1);

        mStyleChoices = new ListStore([GType.STRING]);
        
    }


    override void PrepGui()
    {
        //load choices
        auto currentStyle = Config.getString("DOCMAN", "style_scheme", "cobalt");
        int ActiveChoice;
        int indx;
        TreeIter ti = new TreeIter;
        string stylefolder = expandTilde("~/.neontotem/dcomposer/styles/");
        auto StyleFiles = filter!`endsWith(a.name, ".xml")`(dirEntries(stylefolder, SpanMode.shallow));
        mStyleChoices.clear();
        foreach( xmlfile; StyleFiles)
        {
	        mStyleChoices.append(ti);
            mStyleChoices.setValue(ti, 0, baseName(xmlfile.name,".xml"));
            if(currentStyle == mStyleChoices.getValueString(ti, 0)) ActiveChoice = indx;
            
            indx++;
        }
        mStyleBox.setModel(mStyleChoices);
        mStyleBox.setActive(ActiveChoice);    
        
        mAutoIndent         .setActive(Config.getBoolean("DOCMAN", "auto_indent"        , true));
        mIndentOnTab        .setActive(Config.getBoolean("DOCMAN", "indent_on_tab"      , true));
        mSpacesForTab       .setActive(Config.getBoolean("DOCMAN", "spaces_for_tabs"    , true));
        mSmartHome          .setActive(Config.getBoolean("DOCMAN", "smart_home_end"     , true));
        mHiliteCurrentLine  .setActive(Config.getBoolean("DOCMAN", "hilite_current_line", true));
        mShowLineNumbers    .setActive(Config.getBoolean("DOCMAN", "show_line_numbers"  , true));
        mShowRightMargin    .setActive(Config.getBoolean("DOCMAN", "show_right_margin"  , true));
        mHiliteSyntax       .setActive(Config.getBoolean("DOCMAN", "hilite_syntax"      , true));
        mMatchBrackets      .setActive(Config.getBoolean("DOCMAN", "match_brackets"     , true));

        mRightMargin.setValue(Config.getInteger("DOCMAN", "right_margin", 80));
        mIndentionWidth.setValue(Config.getInteger("DOCMAN", "indention_width", 8));
        mTabWidth.setValue(Config.getInteger("DOCMAN", "tab_width", 8));

        mFontStuff.setFontName(Config.getString("DOCMAN", "font", "Droid Sans Mono 16"));

    }

    override void Apply()
    {
        TreeIter ti = new TreeIter;
        mStyleBox.getActiveIter(ti);
        
        Config.setString("DOCMAN", "style_scheme", mStyleChoices.getValueString(ti,0));

        
        Config.setBoolean("DOCMAN", "auto_indent"        , mAutoIndent         .getActive());
        Config.setBoolean("DOCMAN", "indent_on_tab"      , mIndentOnTab        .getActive());
        Config.setBoolean("DOCMAN", "spaces_for_tabs"    , mSpacesForTab       .getActive());
        Config.setBoolean("DOCMAN", "smart_home_end"     , mSmartHome          .getActive());
        Config.setBoolean("DOCMAN", "hilite_current_line", mHiliteCurrentLine  .getActive());
        Config.setBoolean("DOCMAN", "show_line_numbers"  , mShowLineNumbers    .getActive());
        Config.setBoolean("DOCMAN", "show_right_margin"  , mShowRightMargin    .getActive());
        Config.setBoolean("DOCMAN", "hilite_syntax"      , mHiliteSyntax       .getActive());
        Config.setBoolean("DOCMAN", "match_brackets"     , mMatchBrackets      .getActive());

        Config.setInteger("DOCMAN", "right_margin"       , mRightMargin.getValueAsInt());
        Config.setInteger("DOCMAN", "indention_width"    , mIndentionWidth.getValueAsInt());
        Config.setInteger("DOCMAN", "tab_width"          , mTabWidth.getValueAsInt());

        Config.setString("DOCMAN", "font"              , mFontStuff.getFontName());
    }
        

}                                         

	
		
		
