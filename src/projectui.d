// projectui.d
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

module projectui;


import dcore;
import ui;
import elements;
import project;

import std.conv;
import std.path;
import std.stdio;
import std.parallelism;
import std.concurrency;
import std.string;

import gtk.AccelGroup;
import gtk.Action;
import gtk.ActionGroup;
import gtk.Alignment;
import gtk.Builder;
import gtk.Button;
import gtk.CellEditableIF;
import gtk.CellRendererText;
import gtk.CellRendererToggle;
import gtk.CheckButton;
import gtk.ComboBox;
import gtk.Dialog;
import gtk.EditableIF;
import gtk.Entry;
import gtk.FileChooserDialog;
import gtk.FileFilter;
import gtk.HBox;
import gtk.Label;
import gtk.ListStore;
import gtk.SeparatorMenuItem;
import gtk.SeparatorToolItem;
import gtk.TextView;
import gtk.TreeIter;
import gtk.TreeView;
import gtk.VBox;
import gtk.Widget;
import gtk.ScrolledWindow;
import gtk.Main;

import gdk.Cursor;
import gdk.Display;

import gobject.Value;





class PROJECT_UI : ELEMENT
{

    string              mName;
    string              mInfo;
    bool                mState;


    Builder			    mProBuilder;
    
	ScrolledWindow			    mRootVBox;
	Label 			    mTabLabel;

    //button bar
	Button			    mBtnApply;
	Button			    mBtnRevert;
	Button			    mBtnHide;

    //basics
	Entry			    mProjName;
	Entry               mFolder;
    Button              mFolderBrowse;
    Button              mSetRootBtn;
    Label               mFullPath;
    Label               mProjBaseLbl;
    ComboBox            mTargetBox;
    ListStore           mTargetTypes;
    TextView		    mInformation;

    string              mProjBaseFolder;
       
    //files
    HBox                mFilesHBox;
    LISTUI              mSrcList;
    LISTUI              mRelList;

    //compiler
    ListStore		    mFlagStore;
	CellRendererToggle  mFlagToggle;
	CellRendererText    mFlagArg;
    HBox			    mConditionalsHBox;
	LISTUI			    mVerList;
	LISTUI			    mDbgList;    
    HBox			    mPathsHBox;
	LISTUI			    mImpList;
	LISTUI			    mExpList;

    //Linker
	HBox			    mLinkerHBox;    
	LISTUI			    mLibList;
	LISTUI			    mLLPList;

    //sundry
    Alignment           mMiscAlign;
    LISTUI              mMiscList;
    Label			    mAutoCmdLine;
    CheckButton		    mUseCustomBuild;
	Entry			    mCustomBuild;
    Entry               mPreBuild;
    Entry               mPostBuild;
    Entry               mRunArguments;
    
	
   
	AccelGroup		    mAccels;
	ActionGroup 	    mActions;


    bool                mSkipWatchingProject; //multiple connects and disconnect is causing an error

    public:
    
    @property string Name() { return "PROJECT_UI";}
    @property string Information(){return "User interface to creating/maintain a D project";}
    @property bool   State(){return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        if(mState) Engage();
        else Disengage();
    }

    this()
    {
        mProBuilder = new Builder;

        string gladefile = expandTilde(Config.getString("PROJECT","glade_file", "~/.neontotem/dcomposer/projopts.glade"));
        string listgladefile = expandTilde(Config.getString("PROJECT", "list_glad_file", "~/.neontotem/dcomposer/multilist.glade"));

        mProBuilder.addFromFile(gladefile);

        mRootVBox           = cast(ScrolledWindow)    mProBuilder.getObject("scrolledwindow1");
        mTabLabel           = new           Label(Project.Name ~" project options");
        

        mBtnApply           = cast(Button)  mProBuilder.getObject("button1");
        mBtnRevert          = cast(Button)  mProBuilder.getObject("button2");
        mBtnHide            = cast(Button)  mProBuilder.getObject("button3");

        mProjName           = cast(Entry)   mProBuilder.getObject("entry1");
        mFolder             = cast(Entry)   mProBuilder.getObject("folderentry");
        mFolderBrowse       = cast(Button)  mProBuilder.getObject("folderbrowse");
        mSetRootBtn         = cast(Button)  mProBuilder.getObject("button4");
        mFullPath           = cast(Label)   mProBuilder.getObject("label7");
        mProjBaseLbl        = cast(Label)   mProBuilder.getObject("label24");
        mTargetBox          = cast(ComboBox)mProBuilder.getObject("combobox1");
        mInformation        = cast(TextView)mProBuilder.getObject("textview1");

        mFilesHBox          = cast(HBox)    mProBuilder.getObject("fileshbox");
        mSrcList            = new LISTUI("D Source Files", ListType.FILES, listgladefile);
		mRelList            = new LISTUI("Related Text Files", ListType.FILES, listgladefile);

        mFlagStore          = cast(ListStore)mProBuilder.getObject("listflags");
		mFlagToggle			= cast(CellRendererToggle)mProBuilder.getObject("cellrenderertoggle1");
		mFlagArg			= cast(CellRendererText)mProBuilder.getObject("cellrenderertext5");
        
        mConditionalsHBox   = cast(HBox)    mProBuilder.getObject("hbox3");
        mVerList            = new LISTUI("Versions (-version)", ListType.IDENTIFIERS,listgladefile);
		mDbgList            = new LISTUI("Debugs (-debug)", ListType.IDENTIFIERS, listgladefile);

        mPathsHBox          = cast(HBox)    mProBuilder.getObject("hbox4");
		mImpList            = new LISTUI("Import Paths (-I)", ListType.PATHS, listgladefile);
		mExpList            = new LISTUI("Expression Paths (-J)", ListType.PATHS, listgladefile);

        mLinkerHBox         = cast(HBox)    mProBuilder.getObject("hbox5");
		mLibList            = new LISTUI("Libraries(-l)", ListType.FILES,listgladefile);
		mLLPList            = new LISTUI("Library Paths(-L)", ListType.PATHS,listgladefile);            

        mMiscAlign          = cast(Alignment)mProBuilder.getObject("alignment3");
        mMiscList           = new LISTUI("Command line extras (-*)", ListType.IDENTIFIERS, listgladefile);

        mAutoCmdLine        = cast(Label)mProBuilder.getObject("label21");

        mUseCustomBuild     = cast(CheckButton)mProBuilder.getObject("checkbutton1");
        mCustomBuild        = cast(Entry)   mProBuilder.getObject("entry2");

        mPreBuild           = cast(Entry)   mProBuilder.getObject("entry3");
        mPostBuild          = cast(Entry)   mProBuilder.getObject("entry4");

        mRunArguments       = cast(Entry)   mProBuilder.getObject("entry5");


        //add listui stuff
        mFilesHBox.add(mSrcList.GetWidget());
		mFilesHBox.add(mRelList.GetWidget());
		mConditionalsHBox.add(mVerList.GetWidget());
		mConditionalsHBox.add(mDbgList.GetWidget());
		mPathsHBox.add(mImpList.GetWidget());
		mPathsHBox.add(mExpList.GetWidget());
		mLinkerHBox.add(mLibList.GetWidget());
		mLinkerHBox.add(mLLPList.GetWidget());
        mMiscAlign.add(mMiscList.GetWidget());


        mFlagToggle.addOnToggled(delegate void(string x, CellRendererToggle t){TreeIter ti = new TreeIter(mFlagStore, x);Value gval = new Value;ti.getValue(0, gval);gval.setBoolean(!gval.getBoolean());mFlagStore.setValue(ti, 0, gval);});
        mFlagArg.addOnEdited(delegate void(string pth, string txt, CellRendererText t){ TreeIter ti = new TreeIter(mFlagStore, pth); mFlagStore.setValue(ti,2,txt);});

        

        mBtnApply.addOnClicked(delegate void (Button X){SyncProjectToGui(); mSkipWatchingProject=true; Project.Save(); mSkipWatchingProject = false;});
		mBtnHide.addOnClicked(delegate void (Button X){mRootVBox.hide();});
		mBtnRevert.addOnClicked(delegate void (Button X){SyncGuiToProject();});

        mProjName.addOnChanged(&FixProjectPath);
        mFolder.addOnChanged(&FixProjectPath);

        mProjBaseFolder = Config.getString("PROJECT", "default_project_path", "~/projects");

        mProjBaseFolder = mProjBaseFolder.expandTilde();

        mProjBaseLbl.setText("Projects root folder : " ~ mProjBaseFolder);
        mSetRootBtn.addOnClicked(delegate void (Button btn){ChangeProjectBaseFolder;});

    }

    void Engage()
    {
        mState = true;
        mRootVBox.hide();
        dui.GetCenterPane.prependPage(mRootVBox, mTabLabel);
        EngageActions();
        Project.Event.connect(&ProjEventWatcher);
        Log.Entry("Engaged PROJECT_UI element");
    }
    void Disengage()
    {
        Project.Event.disconnect(&ProjEventWatcher);
        mState = false;
        mRootVBox.hide();
        Log.Entry("Disengaged PROJECT_UI element");
    }

    void EngageActions()
    {
        //new | open | save? | refresh symbols | build | run | run w/args | whoops forgot options

        Action ProNewAct    = new Action("ProNewAct"    , "_New"            , "Create a new Project"                , StockID.NEW);
        Action ProOpenAct   = new Action("ProOpenAct"   , "_Open"           , "Replace current project"             , StockID.OPEN);
        Action ProOptsAct   = new Action("ProOptsAct"   , "O_ptions"        , "Edit Project options"                , StockID.EDIT);
        Action ProRefAct    = new Action("ProRefAct"    , "_Refresh Tags"   , "Update project symbol information"   , StockID.REFRESH);
        Action ProBuildAct  = new Action("ProBuildAct"  , "_Build"          , "Run Build command"                   , StockID.EXECUTE);
        Action ProRunAct    = new Action("ProRunAct"    , "_Run"            , "Launch project application"          , StockID.EXECUTE);
        Action ProRunArgsAct= new Action("ProRunArgsAcg", "Run _with Args"  , "Launch project application with arguments", StockID.EXECUTE);

        ProNewAct           .addOnActivate(&New);
        ProOpenAct          .addOnActivate(&Open);
        ProOptsAct          .addOnActivate(&ShowOptions);
        ProRefAct           .addOnActivate(&RefreshTags);
        ProBuildAct         .addOnActivate(&Build);
        ProRunAct           .addOnActivate(&Run);
        ProRunArgsAct       .addOnActivate(&RunWithArgs);


        ProNewAct           .setAccelGroup(dui.GetAccel());
        ProOpenAct          .setAccelGroup(dui.GetAccel());
        ProOptsAct          .setAccelGroup(dui.GetAccel());
        ProRefAct           .setAccelGroup(dui.GetAccel());
        ProBuildAct         .setAccelGroup(dui.GetAccel());
        ProRunAct           .setAccelGroup(dui.GetAccel());
        ProRunArgsAct       .setAccelGroup(dui.GetAccel());

        dui.Actions().addActionWithAccel(ProNewAct    , "F5");
        dui.Actions().addActionWithAccel(ProOpenAct   , "F6");
        dui.Actions().addActionWithAccel(ProOptsAct   , "F7");
        dui.Actions().addActionWithAccel(ProRefAct    , "F8");
        dui.Actions().addActionWithAccel(ProBuildAct  , "F9");
        dui.Actions().addActionWithAccel(ProRunAct    , "F10");
        dui.Actions().addActionWithAccel(ProRunArgsAct, "<SHIFT>F10");


        dui.AddMenuItem("_Project", ProNewAct    .createMenuItem());
        dui.AddMenuItem("_Project", ProOpenAct   .createMenuItem());
        dui.AddMenuItem("_Project", new SeparatorMenuItem()       );

        dui.AddMenuItem("_Project", ProOptsAct   .createMenuItem());
        dui.AddMenuItem("_Project",new SeparatorMenuItem()    );
        
        dui.AddMenuItem("_Project", ProRefAct    .createMenuItem());
        dui.AddMenuItem("_Project", ProBuildAct  .createMenuItem());
        dui.AddMenuItem("_Project",new SeparatorMenuItem()    );

        dui.AddMenuItem("_Project", ProRunAct    .createMenuItem());
        dui.AddMenuItem("_Project", ProRunArgsAct.createMenuItem());


        dui.AddToolBarItem(ProNewAct    .createToolItem());
        dui.AddToolBarItem(ProOpenAct    .createToolItem());
        dui.AddToolBarItem(ProOptsAct   .createToolItem());
        dui.AddToolBarItem(ProBuildAct  .createToolItem());
        dui.AddToolBarItem(ProRunAct    .createToolItem());
        dui.AddToolBarItem(ProRunArgsAct.createToolItem());
        
        dui.AddToolBarItem(new SeparatorToolItem);
        
    }

    void SyncGuiToProject()
    {
        
        scope (exit)mSkipWatchingProject =false;
        mSkipWatchingProject = true;
        
        TreeIter tmpIter = new TreeIter;

        //notebook tab label

        mTabLabel.setText("Project:"~Project.Name);
        
		//basics
		mProjName.setText(Project.Name);
        mFolder.setText("");
		mFolder.setText(baseName(Project.WorkingPath));
        //do I need to set mFullPath or will that handle it self??
        mTargetBox.setActive(Project.Target());

        string newText = (Project.GetCatList("DESCRIPTION") is null) ? "" : Project.GetCatList("DESCRIPTION");
        mInformation.getBuffer.setText(newText);

    

        //files
        mSrcList.SetItems(Project[SRCFILES]);
		mRelList.SetItems(Project[RELFILES]);

        //compiler - flags
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
        

        //compiler - conditionals
        mVerList.SetItems(Project[VERSIONS]);
        mDbgList.SetItems(Project[DEBUGS]);

        //compiler - paths
        mImpList.SetItems(Project[IMPPATHS]);
        mExpList.SetItems(Project[JPATHS]);

        //linker
        mLibList.SetItems(Project[LIBFILES]);
        mLLPList.SetItems(Project[LIBPATHS]);

        //sundry - extra command line args
        mMiscList.SetItems(Project[MISC]);

        //sundry -- custom build
        mUseCustomBuild.setActive(Project.UseCustomBuild);
		mCustomBuild.setText(Project.CustomBuildCommand);
        if(Project.CustomBuildCommand is null) mCustomBuild.setText("");
		mAutoCmdLine.setText(Project.BuildCommand);

        //sundry -- scripts
        {
            scope(failure)
            {
                mPreBuild.setText(":)");
                mPostBuild.setText(":)");
            }
            mPreBuild.setText(Project.GetCatList("PRE_BUILD_SCRIPTS"));
            mPostBuild.setText(Project.GetCatList("POST_BUILD_SCRIPTS"));
        }

        scope (exit)mSkipWatchingProject =false;

    }
    void SyncProjectToGui()
    {
        mSkipWatchingProject = true;
        TreeIter tmpIter = new TreeIter;

        Project.Name = mProjName.getText();
        Project.WorkingPath = buildPath(mProjBaseFolder, mFolder.getText);
        Project.Target = cast(TARGET)mTargetBox.getActive();
        Project.SetList("DESCRIPTION",mInformation.getBuffer.getText);
        
        Project.SetList(SRCFILES, mSrcList.GetFullItems);
        Project.SetList(RELFILES, mRelList.GetFullItems);
        
        if(mFlagStore.getIterFirst(tmpIter))
        {
            Value gval = new Value;
            string key;
            string arg;
            bool    nustate;
            do
            {
                
                gval    = mFlagStore.getValue(tmpIter, 0, null); //0 = a boolean value for on/off of switch
                nustate = cast(bool)gval.getBoolean();
                key     = mFlagStore.getValueString(tmpIter, 1); //1 = the cmdline switch string
                arg     = mFlagStore.getValueString(tmpIter, 2); //3 = the argument for the switch
                Project.SetFlag(key, nustate, arg);
            }while (mFlagStore.iterNext(tmpIter));
		}


        Project.SetList(VERSIONS, mVerList.GetFullItems);
        Project.SetList(DEBUGS  , mDbgList.GetFullItems);
        Project.SetList(IMPPATHS, mImpList.GetFullItems);
        Project.SetList(JPATHS  , mExpList.GetFullItems);
        Project.SetList(LIBFILES, mLibList.GetFullItems);
        Project.SetList(LIBPATHS, mLLPList.GetFullItems);

        Project.SetList(MISC, mMiscList.GetFullItems);
                
        Project.UseCustomBuild = cast(bool)mUseCustomBuild.getActive;
        Project.CustomBuildCommand = mCustomBuild.getText;
        
        Project.SetList("PRE_BUILD_SCRIPTS", mPreBuild.getText);
        Project.SetList("POST_BUILD_SCRIPTS",mPostBuild.getText);
        
        mSkipWatchingProject = false;
    }

    void ProjEventWatcher(string EventType)
    {
        if(EventType == "StartOpen") mSkipWatchingProject = true;
        if(EventType == "Opened") mSkipWatchingProject = false;
        
        if(mSkipWatchingProject == true) return;
        SyncGuiToProject();
        
    }
    


    //the following functions do little work
    //mostly just call the working functions  in project.d
    //oh they're also attached to actions to be called from other 'elements'
    void New(Action x)
    {
        Project.New();
        ShowOptions(null);
    }
    void Open(Action x)
    {
        FileChooserDialog fcd = new FileChooserDialog("Open Project", dui.GetWindow(), FileChooserAction.OPEN);

        FileFilter ff = new FileFilter;
        ff.setName("DComposer Project");
        ff.addPattern("*.dpro");
        fcd.setFilter(ff);
        fcd.setCurrentFolder(Config.getString("DPROJECT","last_open_dialog_folder", "./"));
        
        int rt = fcd.run();
		fcd.hide();
		if(rt != ResponseType.GTK_RESPONSE_OK) return;
        
        Project.Open(fcd.getFilename);

        Config.setString("DPROJECT", "last_open_dialog_folder", fcd.getCurrentFolder());
    }
    

    void ShowOptions(Action x)
    {
        if(Project.Target == TARGET.NULL) return;
        mRootVBox.showAll();
        dui.GetCenterPane.setCurrentPage(mRootVBox);
        mRootVBox.grabFocus();        
    }

    void Build(Action x)
    {
        //set cursor to a busy cursor --- since I totally failed to build in parallel!
        int xx, yy;
        auto watch = new Cursor(GdkCursorType.WATCH);
        auto tmpwindow = Display.getDefault.getWindowAtPointer(xx,yy);
        tmpwindow.setCursor(watch);
        Display.getDefault.sync();
        watch.unref();

        //save all and build
        dui.GetDocMan.SaveAllDocs();
        Project.BuildMsg.emit(`BEGIN`);
        Project.Build();        
        Project.BuildMsg.emit(`END`);

        //restore default cursor
        tmpwindow.setCursor(null);
    }

    


    void Run(Action x)
    {
        dui.GetDocMan.SaveAllDocs();
        Project.RunConcurrent();
    }

    void RunWithArgs(Action x)
    {
        dui.GetDocMan.SaveAllDocs();
        Project.Run(mRunArguments.getText);
    }        

    void RefreshTags(Action x)
    {
        Project.CreateTags();
    }

    void FixProjectPath(EditableIF EntryWidget)
    {
       auto tmpPath = buildPath(mProjBaseFolder, mFolder.getText, mProjName.getText);
       
       tmpPath = defaultExtension(tmpPath, "dpro");
       mFullPath.setText("Projects full folder  : " ~ tmpPath);
    }

    void ChangeProjectBaseFolder()
    {
        auto FolderChoice = new FileChooserDialog("Select Projects Root Folder", dui.GetWindow(), FileChooserAction.SELECT_FOLDER);

        FolderChoice.setCurrentFolder(mProjBaseFolder);
        auto choice = FolderChoice.run();
        FolderChoice.hide();
        if (choice != ResponseType.GTK_RESPONSE_OK) return;

        mProjBaseFolder = chompPrefix(FolderChoice.getUri(), "file://");
        mProjBaseLbl.setText("Projects root folder : " ~ mProjBaseFolder);
        FixProjectPath(null);
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return null;
    }
        
}
        

