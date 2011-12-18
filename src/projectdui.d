//      projectdui.d
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


module projectdui;

import dproject;
import dcore;
import ui;
import elements;

import std.path;
import std.conv;
import std.file;
import std.stdio;
import std.string;

import gtk.VBox;
import gtk.Label;
import gtk.TreeView;
import gtk.ListStore;
import gtk.Button;
import gtk.TreeIter;
import gtk.Builder;
import gtk.FileChooserDialog;
import gtk.FileChooserButton;
import gtk.Dialog;
import gtk.Entry;
import gtk.Widget;
import gtk.CheckButton;
import gtk.HBox;
import gtk.Notebook;
import gtk.EditableIF;
import gtk.AccelGroup;
import gtk.Action;
import gtk.ActionGroup;
import gtk.FileFilter;
import gtk.SeparatorMenuItem;
import gtk.TextView;
import gtk.CellRendererToggle;
import gtk.CellRendererText;
import gtk.SeparatorToolItem;

import gobject.Value;

import glib.SimpleXML;



class PROJECT_UI : ELEMENT
{

    private :

    bool            mState;
    

	Builder			mProBuilder;

	VBox			mRootVBox;
	Label			mTitleLabel;
	Label 			mTabLabel;

	Entry			    mName;
	FileChooserButton   mRootDir;
    Label               mProPath;

	CheckButton		mUseManCmdLine;
	Entry			mManCmdLine;
	Label			mAutoCmdLine;

	HBox			mFilesHBox;
	HBox			mConditionalsHBox;
	HBox			mDPathsHBox;
	HBox			mLinkerHBox;
	
	ListStore		    mFlagStore;
	CellRendererToggle  mFlagToggle;
	CellRendererText    mFlagArg;
	
	Entry			mMiscLinkOptions;

	LISTUI			mSrcList;
	LISTUI			mRelList;
	LISTUI			mVerList;
	LISTUI			mDbgList;
	LISTUI			mImpList;
	LISTUI			mExpList;
	LISTUI			mLibList;
	LISTUI			mLLPList;

	Button			mBtnApply;
	Button			mBtnHide;
	Button			mBtnDiscard;

	TextView		mDescription;
	
	AccelGroup		mAccels;
	ActionGroup 	mActions;

    public:
    
    @property string Name() { return "PROJECT_UI";}
    @property string Information(){return "User interface to creating/maintaining a D project";}
    @property bool   State(){return mState;}
    @property void   State(bool nustate){mState = nustate;}

    this()
    {
		
		mProBuilder         = new Builder;
		mProBuilder.addFromFile(Config.getString("PROJECT_UI","glade_file", "/home/anthony/.neontotem/dcomposer/dprojectoptions.glade"));

		mRootVBox           = cast(VBox)mProBuilder.getObject("vbox1");
		mFilesHBox          = cast(HBox)mProBuilder.getObject("hbox1");
		mConditionalsHBox   = cast(HBox)mProBuilder.getObject("hbox2");
		mDPathsHBox         = cast(HBox)mProBuilder.getObject("hbox3");
		mLinkerHBox	        = cast(HBox)mProBuilder.getObject("hbox4");		
		mTabLabel           = new Label(Project.Name ~" project options");
		mName 				= cast(Entry)mProBuilder.getObject("entry1");
		mRootDir 			= cast(FileChooserButton)mProBuilder.getObject("filechooserbutton1");
        mProPath            = cast(Label)mProBuilder.getObject("label16");
		mUseManCmdLine 		= cast(CheckButton)mProBuilder.getObject("checkbutton1");
		mManCmdLine 		= cast(Entry)mProBuilder.getObject("entry3");
		mAutoCmdLine 		= cast(Label)mProBuilder.getObject("label9");
		mFlagStore 			= cast(ListStore)mProBuilder.getObject("liststore1");
		mFlagToggle			= cast(CellRendererToggle)mProBuilder.getObject("cellrenderertoggle1");
		mFlagArg			= cast(CellRendererText)mProBuilder.getObject("cellrenderertext5");
		mSrcList            = new LISTUI("D Source Files", ListType.FILES);
		mRelList            = new LISTUI("Related Text Files", ListType.FILES);
		mVerList            = new LISTUI("Versions (-version)", ListType.IDENTIFIERS);
		mDbgList            = new LISTUI("Debugs (-debug)", ListType.IDENTIFIERS);
		mImpList            = new LISTUI("Import Paths (-I)", ListType.PATHS);
		mExpList            = new LISTUI("Expression Paths (-J)", ListType.PATHS);
		mLibList            = new LISTUI("Libraries(-l)", ListType.FILES);
		mLLPList            = new LISTUI("Library Paths(-L)", ListType.PATHS);            
		mMiscLinkOptions 	= cast(Entry)mProBuilder.getObject("entry4");
		mBtnApply 	        = cast(Button)mProBuilder.getObject("button1");
		mBtnHide 	        = cast(Button)mProBuilder.getObject("button2");
		mBtnDiscard	        = cast(Button)mProBuilder.getObject("button3");
 		mDescription        = cast(TextView)mProBuilder.getObject("textview1");
       
		mFlagToggle.addOnToggled(delegate void(string x, CellRendererToggle t){TreeIter ti = new TreeIter(mFlagStore, x);Value gval = new Value;ti.getValue(0, gval);gval.setBoolean(!gval.getBoolean());mFlagStore.setValue(ti, 0, gval);});
        mFlagArg.addOnEdited(delegate void(string pth, string txt, CellRendererText t){ TreeIter ti = new TreeIter(mFlagStore, pth); mFlagStore.setValue(ti,2,txt);});



		mFilesHBox.add(mSrcList.GetWidget());
		mFilesHBox.add(mRelList.GetWidget());
		mConditionalsHBox.add(mVerList.GetWidget());
		mConditionalsHBox.add(mDbgList.GetWidget());
		mDPathsHBox.add(mImpList.GetWidget());
		mDPathsHBox.add(mExpList.GetWidget());
		mLinkerHBox.add(mLibList.GetWidget());
		mLinkerHBox.add(mLLPList.GetWidget());



		//for now ... later must create actions (menu and tool items) for(new project, save, open, options, build, run ...)
		//FillGui();

		mName.addOnChanged(delegate void(EditableIF x) { mTabLabel.setText("Project :" ~ mName.getText());});
		
		mBtnApply.addOnClicked(delegate void (Button X){FillProjectData();FillGuiData();});
		mBtnHide.addOnClicked(delegate void (Button X){mRootVBox.hide();});
		mBtnDiscard.addOnClicked(delegate void (Button X){FillGuiData(), mRootVBox.hide();});
	}

    

    void Engage()
    {
        mState = true;

        Project().ListChanged.connect(&WatchingProjectLists);
        Project().BaseDirChanged.connect(&WatchingProject);
        Project().NameChanged.connect(&WatchingProject);
        Project().OtherArgsChanged.connect(&WatchingProject);
        Project().Opened.connect(&WatchingProject);
        Project().Saved.connect(&WatchingProject);
                
        if(Project.Type != TARGET.NULL) mRootVBox.showAll();
        if(Project.Type == TARGET.NULL) mRootVBox.hide();
        dui.GetCenterPane.prependPage(mRootVBox, mTabLabel);


        EngageActions();
        
        

        Log.Entry("Engaged PROJECT_UI element");
    }
        
        

    void Disengage()
    {
        mState = false;
        
        mRootVBox.hide();

        Log.Entry("Disengaged PROJECT_UI element");
    }


    void EngageActions()
    {
        //new | open | save? | refresh symbols | build | run | run w/args | whoops forgot options

        Action ProNewAct    = new Action("ProNewAct"    , "_New"            , "Create a new Project"    , StockID.NEW);
        Action ProOpenAct   = new Action("ProOpenAct"   , "_Open"           , "Replace current project" , StockID.OPEN);
        Action ProOptsAct   = new Action("ProOptsAct"   , "O_ptions"        , "Edit Project options"    , StockID.EDIT);
        Action ProRefAct    = new Action("ProRefAct"    , "_Refresh Tags"   , "Update project symbol information", StockID.REFRESH);
        Action ProBuildAct  = new Action("ProBuildAct"  , "_Build"          , "Run Build command"       , StockID.EXECUTE);
        Action ProRunAct    = new Action("ProRunAct"    , "_Run"            , "Launch project application", StockID.EXECUTE);
        Action ProRunArgsAct= new Action("ProRunArgsAcg", "Run _with Args"  , "Launch project application with arguments", StockID.EXECUTE);

        ProNewAct           .addOnActivate(&New);
        ProOpenAct          .addOnActivate(&Open);
        ProOptsAct          .addOnActivate(&ShowOptions);
        ProRefAct           .addOnActivate(&RefreshSymbols);
        ProBuildAct         .addOnActivate(&Build);
        ProRunAct           .addOnActivate(&Run);
        //ProRunArgsAct       .addOnActivate(&RunWithArgs);


        ProNewAct           .setAccelGroup(dui.GetAccel());
        ProOpenAct          .setAccelGroup(dui.GetAccel());
        ProOptsAct          .setAccelGroup(dui.GetAccel());
        ProRefAct           .setAccelGroup(dui.GetAccel());
        ProBuildAct         .setAccelGroup(dui.GetAccel());
        ProRunAct           .setAccelGroup(dui.GetAccel());
        ProRunArgsAct       .setAccelGroup(dui.GetAccel());

        dui.GetActions().addActionWithAccel(ProNewAct    , "F5");
        dui.GetActions().addActionWithAccel(ProOpenAct   , "F6");
        dui.GetActions().addActionWithAccel(ProOptsAct   , "F7");
        dui.GetActions().addActionWithAccel(ProRefAct    , "F8");
        dui.GetActions().addActionWithAccel(ProBuildAct  , "F9");
        dui.GetActions().addActionWithAccel(ProRunAct    , "F10");
        dui.GetActions().addActionWithAccel(ProRunArgsAct, "<SHIFT>F10");


        dui.AddMenuItem("_Project", ProNewAct    .createMenuItem());
        dui.AddMenuItem("_Project", ProOpenAct   .createMenuItem());
        dui.AddMenuItem("_Project",new SeparatorMenuItem()    );

        dui.AddMenuItem("_Project", ProOptsAct   .createMenuItem());
        dui.AddMenuItem("_Project",new SeparatorMenuItem()    );
        
        dui.AddMenuItem("_Project", ProRefAct    .createMenuItem());
        dui.AddMenuItem("_Project", ProBuildAct  .createMenuItem());
        dui.AddMenuItem("_Project",new SeparatorMenuItem()    );

        dui.AddMenuItem("_Project", ProRunAct    .createMenuItem());
        dui.AddMenuItem("_Project", ProRunArgsAct.createMenuItem());

        dui.AddToolBarItem(ProOptsAct.createToolItem());
        dui.AddToolBarItem(ProBuildAct.createToolItem());
        dui.AddToolBarItem(ProRunAct.createToolItem());
        dui.AddToolBarItem(new SeparatorToolItem);
        
    }

    void New(Action X)
    {
        Project.New("NewProject");
        FillGuiData();
        mRootVBox.showAll();
        dui.GetCenterPane.setCurrentPage(mRootVBox);
        mRootVBox.grabFocus();
    }

    void Open(Action X)
    {
        FileChooserDialog fcd = new FileChooserDialog("Open Project", dui.GetWindow(), FileChooserAction.OPEN);

        FileFilter ff = new FileFilter;
        ff.setName("DComposer Project");
        ff.addPattern("*.dpro");
        fcd.setFilter(ff);
        fcd.setCurrentFolder(Config.getString("DPROJECT","last_open_dialog_folder", "../junkpile"));
        
        int rt = fcd.run();
		fcd.hide();
		if(rt != ResponseType.GTK_RESPONSE_OK) return;
        
        Project.Open(fcd.getFilename);
        //chdir(Project.BaseDir);
        FillGuiData();

        Config.setString("DPROJECT", "last_open_dialog_folder", fcd.getCurrentFolder());

    }

    void ShowOptions(Action X)
    {
        if(!State) return;
        if(Project.Type == TARGET.NULL) return;
        mRootVBox.showAll();
        dui.GetCenterPane.setCurrentPage(mRootVBox);
        mRootVBox.grabFocus();
    }

    void RefreshSymbols(Action X)
    {
        if(Project.CreateTags() == 0)
        {
            Log.Entry("Tag file for Project : "~Project.Name~" created.");
        }
        else
        {
            Log.Entry("Failed to create tag file for project : "~ Project.Name ~".","Error");
        }
    }

    /*void Build(Action x)
    {
        //hey you stupid ... you have this same function in dproject.d  no reason to have it here much less use it!

        dui.GetDocMan.SaveAllDocs();
        std.stdio.File Process = File("tmp","w");

        scope(failure)foreach(string L; lines(Process) )Log.Entry(chomp(L),"Error");
writeln(getcwd());
writeln(Project.CmdLine);
        Process.popen("sh /home/anthony/.neontotem/dcomposer/childrunner.sh " ~ Project.CmdLine ~ " 2>&1 ", "r");

        string[] output;
        foreach(string L; lines(Process) )
        {
            output.length = output.length +1;
            output[$-1] = chomp(L);
            Log.Entry(SimpleXML.escapeText(chomp(L), -1));
        }
        scope(exit) Process.close();
    }*/

    void Build(Action x)
    {
        dui.GetDocMan.SaveAllDocs();
        Project.Build();
    }
               
    void Run(Action X)
    {
        scope(failure) return;
        std.stdio.File Process;
        Process.popen("./"~Project.Name,"r");
        string[] output;
        foreach(string L; lines(Process) )
        {
            output.length = output.length +1;
            output[$-1] = chomp(L);
            Log.Entry(chomp(L));
        }
        Process.close();
        
    }

    //fills the gui stuff with data from the actual project (reverts to original on discard) (and on new project or open project)
	void FillGuiData()
	{
		TreeIter tmpIter = new TreeIter;
		//basics
		mName.setText(Project.Name);
		mRootDir.setFilename(Project.BaseDir);
        mProPath.setText("Project path : " ~ Project.BaseDir ~ "/" ~ Project.Name ~ "/" ~ Project.Name ~ ".dpro");
        
        Log.Entry(mRootDir.getFilename(),"Debug");

		mUseManCmdLine.setActive(Project.UseManualBuild);
		mManCmdLine.setText(Project.CmdLine);
		mAutoCmdLine.setText(Project.BuildCommand);
		mSrcList.SetItems(Project.Get(SRCFILES));
		mRelList.SetItems(Project.Get(RELFILES));
		//flags
        mFlagStore.clear();
        foreach(index, flag; Project.GetFlags())
        {
            Value gval = new Value;
            gval.init(GType.BOOLEAN);
            gval.setBoolean(cast(int)flag.State);
            mFlagStore.insert(tmpIter,0);
            mFlagStore.setValue(tmpIter, 0, gval);
            mFlagStore.setValue(tmpIter, 1, flag.CmdString);
            
            mFlagStore.setValue(tmpIter, 2, flag.Argument);
            gval.setBoolean(cast(int)flag.HasAnArg);
            mFlagStore.setValue(tmpIter, 3, gval);
            mFlagStore.setValue(tmpIter, 4, flag.Brief);
        }

        mVerList.SetItems(Project.Get(VERSIONS));
        mDbgList.SetItems(Project.Get(DEBUGS));
        mImpList.SetItems(Project.Get(INCPATHS));
        mExpList.SetItems(Project.Get(JPATHS));
        mLibList.SetItems(Project.Get(LIBFILES));
        mLLPList.SetItems(Project.Get(LIBPATHS));

        //string TmpExtraOpts;
        //foreach(lnkopt; mProject.Get("LinkOpts"))TmpExtraOpts ~=lnkopt ~ " ";
        mMiscLinkOptions.setText(" "~Project.OtherArgs);
        mDescription.getBuffer().setText(Project.GetFirst("DESCRIPTION"));
	}

    void FillProjectData()
	{
        DisconnectProjectWatchers();
        
		TreeIter tmpiter = new TreeIter;
		
		Project.Name = mName.getText();
		Project.BaseDir = mRootDir.getFilename();

		Project.UseManualBuild = cast(bool)mUseManCmdLine.getActive();
		Project.CmdLine = mManCmdLine.getText();
		Project.Set(SRCFILES, mSrcList.GetFullItems());
		Project.Set(RELFILES, mRelList.GetFullItems());
		//SAVE flags
        if(mFlagStore.getIterFirst(tmpiter))
        {
            Value gval = new Value;
            string key;
            string arg;
            bool    nustate;
            do
            {
                
                gval    = mFlagStore.getValue(tmpiter, 0, null); //0 = a boolean value for on/off of switch
                nustate = cast(bool)gval.getBoolean();
                key     = mFlagStore.getValueString(tmpiter, 1); //1 = the cmdline switch string
                arg     = mFlagStore.getValueString(tmpiter, 2); //3 = the argument for the switch
                Project.SetFlag(key, nustate, arg);
            }while (mFlagStore.iterNext(tmpiter));
		}
		Project.Set(VERSIONS, mVerList.GetFullItems());
		Project.Set(DEBUGS, mDbgList.GetFullItems());
		Project.Set(INCPATHS, mImpList.GetFullItems());
		Project.Set(JPATHS, mExpList.GetFullItems());
		Project.Set(LIBFILES, mLibList.GetFullItems());
		Project.Set(LIBPATHS, mLLPList.GetFullItems());
		Project.OtherArgs = mMiscLinkOptions.getText();

		//mProject.AddList("DESCRIPTION");
		Project.Set("DESCRIPTION", mDescription.getBuffer().getText());
        Project.Save();

        ConnectProjectWatchers();
	}



    void WatchingProjectLists(string x1, string[] x2)
    {
        WatchingProject(x1);
    }
    void WatchingProject(string x)
    {
        //Log.Entry("Watching project (from projectui) -- " ~ x, "Debug");
        FillGuiData();
    }

    void DisconnectProjectWatchers()
    {
        Project().ListChanged.disconnect(&WatchingProjectLists);
        Project().BaseDirChanged.disconnect(&WatchingProject);
        Project().NameChanged.disconnect(&WatchingProject);
        Project().OtherArgsChanged.disconnect(&WatchingProject);
        Project().Opened.disconnect(&WatchingProject);
        Project().Saved.disconnect(&WatchingProject);
    }

    void ConnectProjectWatchers()
    {
        Project().ListChanged.connect(&WatchingProjectLists);
        Project().BaseDirChanged.connect(&WatchingProject);
        Project().NameChanged.connect(&WatchingProject);
        Project().OtherArgsChanged.connect(&WatchingProject);
        Project().Opened.connect(&WatchingProject);
        Project().Saved.connect(&WatchingProject);
    }

    
}

enum ListType {FILES, PATHS, IDENTIFIERS};

class LISTUI
{
	Builder		mBuilder;

	VBox		mVBox;
	Label		mFrameLabel;
	TreeView	mListView;
	ListStore	mListStore;
	Button		mAddButton;
	Button		mRemoveButton;
	Button		mClearButton;
	Dialog 		mAddItemDialog;
	Entry		mAddItemEntry;

	this(string ListTitle, ListType Type, string GladeFile = "/home/anthony/.neontotem/dcomposer/multilist.glade")
	{
		mBuilder = new Builder;
		mBuilder.addFromFile(GladeFile);

		mVBox 			= cast(VBox)mBuilder.getObject("vbox1");
		mFrameLabel 	= cast(Label)mBuilder.getObject("label1");
		mListView 		= cast(TreeView)mBuilder.getObject("treeview");
		mListStore		= cast(ListStore)mBuilder.getObject("thestore");
		mAddButton 		= cast(Button)mBuilder.getObject("buttonadd");
		mRemoveButton 	= cast(Button)mBuilder.getObject("buttonremove");
		mClearButton 	= cast(Button)mBuilder.getObject("buttonclear");

		mAddItemDialog = cast(Dialog)mBuilder.getObject("dialog1");
		mAddItemEntry 	= cast(Entry)mBuilder.getObject("entry");		

		if(Type == ListType.FILES) mAddButton.addOnClicked(&AddFiles);
		if(Type == ListType.PATHS) mAddButton.addOnClicked(&AddPaths);
		if(Type == ListType.IDENTIFIERS) mAddButton.addOnClicked(&AddItem);

		mRemoveButton.addOnClicked(&RemoveItems);
		mClearButton.addOnClicked(&ClearItems);
		
		mFrameLabel.setText(ListTitle);

		mListView.getSelection().setMode(GtkSelectionMode.MULTIPLE);
		mListView.setRubberBanding(false);
		mListView.setReorderable(true);

		mVBox.showAll();
	}

	void SetItems(string[] Items)
	{
		TreeIter ti = new TreeIter;		
		mListStore.clear();
		foreach (index, i; Items)
		{
			mListStore.insert(ti, 0);
			mListStore.setValue(ti, 0, baseName(i));
			mListStore.setValue(ti, 1, relativePath(i));
		}
		mListView.setModel(mListStore);
	}

	string[] GetShortItems(int col = 0)
	{
		string[] rval;
		TreeIter ti = new TreeIter;
		
		if (!mListStore.getIterFirst(ti)) return rval;
	
		rval ~= mListStore.getValueString(ti,col);
		while(mListStore.iterNext(ti)) rval ~= mListStore.getValueString(ti,col);

		return rval;
	}
		
	string[] GetFullItems()
	{
		return GetShortItems(1);
	}

	void AddFiles(Button btn)
	{
		string afile;
		TreeIter ti = new TreeIter;

		auto FileDialog = new FileChooserDialog("Select Files", dui.GetWindow(), FileChooserAction.OPEN);
		FileDialog.setSelectMultiple(true);

		auto DialogResponse = FileDialog.run();
		FileDialog.hide();

		if(DialogResponse != ResponseType.GTK_RESPONSE_OK)return;

		auto SelFiles = FileDialog.getFilenames();
		while(SelFiles !is null)
		{
			afile = toImpl!(string, char *)(cast(char *)SelFiles.data()); 
			mListStore.append(ti);
			mListStore.setValue(ti, 0, baseName(afile));
			mListStore.setValue(ti, 1, afile);
			SelFiles = SelFiles.next();
		}
		mListView.setModel(mListStore);
	}

	void AddPaths(Button btn)
	{
		string afile;
		TreeIter ti = new TreeIter;

		auto FileDialog = new FileChooserDialog("Select Files", dui.GetWindow(), FileChooserAction.SELECT_FOLDER);
		FileDialog.setSelectMultiple(true);

		auto DialogResponse = FileDialog.run();
		FileDialog.hide();

		if(DialogResponse != ResponseType.GTK_RESPONSE_OK)return;

		auto SelFiles = FileDialog.getFilenames();
		while(SelFiles !is null)
		{
			afile = toImpl!(string, char *)(cast(char *)SelFiles.data()); 
			mListStore.append(ti);
			mListStore.setValue(ti, 0, baseName(afile));
			mListStore.setValue(ti, 1, afile);
			SelFiles = SelFiles.next();
		}
		mListView.setModel(mListStore);
	}

	void AddItem(Button btn)
	{
		TreeIter ti = new TreeIter;
		auto rv = mAddItemDialog.run();
		mAddItemDialog.hide();
		if(rv == 0) return;

		string x = mAddItemEntry.getText();

		if (x.length < 1) return;
		mListStore.append(ti);
		mListStore.setValue(ti, 0, x);
		mListStore.setValue(ti, 1, x);
		mListView.setModel(mListStore);
	}

	void RemoveItems(Button btn)
	{
		TreeIter[] xs = mListView.getSelectedIters();

		foreach(x; xs)
		{
			mListStore.remove(x);
		}
		mListView.setModel(mListStore);
	}

	void ClearItems(Button btn)
	{
		mListStore.clear();
		mListView.setModel(mListStore);
	}

	Widget GetWidget() { return mVBox;}
		
}
