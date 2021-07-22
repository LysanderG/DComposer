module ui_project;

import std.array;
import std.conv;
import std.path;
import std.format;
import std.string;
import std.traits;
import core.memory;

import qore;
import ui;
import ui_docbook;
import ui_list;
import ui_toolbar;

import project;

void Engage()
{
    GMenu projMenu = new GMenu;
    GActionEntry[] projActions = [
        {"actionProjNew", &action_ProjNew, null, null, null},
        {"actionProjOpen", &action_ProjOpen, null, null, null},
        {"actionProjSave", &action_ProjSave, null, null, null},
        {"actionProjClose", &action_ProjClose, null, null, null},
        {"actionProjRun", &action_ProjRun, null, null, null},
        {"actionProjBuild", &action_ProjBuild, null, null, null},			
        {"actionProjEdit", &action_ProjEdit, null, null, null},			
    ];
    mMainWindow.addActionEntries(projActions, null);
    
    AddSubMenu(4, "Project", projMenu);
    projMenu.appendItem(new GMenuItem("New","actionProjNew"));
    projMenu.appendItem(new GMenuItem("Open","actionProjOpen"));
    projMenu.appendItem(new GMenuItem("Save","actionProjSave"));
    projMenu.appendItem(new GMenuItem("Edit","actionProjEdit"));
    projMenu.appendItem(new GMenuItem("Build","actionProjBuild"));
    projMenu.appendItem(new GMenuItem("Run","actionProjRun"));
    projMenu.appendItem(new GMenuItem("Close","actionProjClose"));
    
    AddToolObject("ProjNew", "New", "New Project",
		Config.GetResource("icons","ProjNew","resources", "color-new.png"),"win.actionProjNew");
    AddToolObject("ProjOpen", "Open", "Load project file",
        Config.GetResource("icons","ProjOpen","resources", "color-open.png"),"win.actionProjOpen");
    AddToolObject("ProjSave","Save","write project to file",
        Config.GetResource("icons","ProjSave","resources", "color-save.png"), "win.actionProjSave");
    AddToolObject("ProjEdit","Edit","Edit project",
        Config.GetResource("icons","ProjEdit","resources","color-edit.png"), "win.actionProjEdit");
    AddToolObject("ProjBuild","Build","Compile + link project",
        Config.GetResource("icons","ProjBuild","resources","color-build.png"),"win.actionProjBuild");
    AddToolObject("ProjRun","Run","Execute project target",
        Config.GetResource("icons","ProjRun","resources","color-arrow.png"),"win.actionProjRun");
    AddToolObject("ProjClose","Close","Remove project from IDE",
        Config.GetResource("icons","ProjClose","resources","color-close.png"),"win.actionProjClose");
    
    
    uiProject = new UI_PROJECT(Config.GetResource("ui_project", "glade_file", "glade", "ui_project.glade"));
    uiProject.Engage();
    Log.Entry("\tui_project Engaged");
}

void Mesh()
{
    uiProject.mRoot.setVisible(false);
    
    Box tabWidget = new Box(Orientation.HORIZONTAL, 0);
    Label tabLabel = new Label("Project Editor");    
    Image tabImage = new Image(Config.GetResource("ui_project", "tab_image", "resources", "cross-circle-frame.png"));
    EventBox tabEvBx = new EventBox();
    tabEvBx.addOnButtonRelease(delegate bool(Event ev, Widget w)
    {
        if(ev.button.button != GDK_BUTTON_PRIMARY) return false;
        uiProject.setVisible(false);
        return true;
    });
    tabEvBx.add(tabImage);
    tabWidget.packStart(tabLabel, true, true, 0);
    tabWidget.packStart(tabEvBx, false, false, 0);
    tabWidget.showAll();
    uiDocBook.prependPage(uiProject, tabWidget);
    
    //uiDocBook.prependPage(uiProject, new Label("Project Editor"));
    
    
    uiProject.Mesh();
    
    Log.Entry("\tui_project Meshed");
}

void Disengage()
{
    uiProject.Disengage();
    Log.Entry("\tui_project Disengaged");
}

string StatusLine()
{
    string layout = "Project: %s\t(options based on dmd version : %s)";
    string retString = format(layout, Project.FullPath, Project.GetDmdFlagsVersion());
    return retString;
}

extern(C) 
{
    void action_ProjNew(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        Project.Close();
        uiProject.mRoot.showAll();
        uiDocBook.setCurrentPage(uiProject);
        uiProject.setFocusChild(uiProject.uiName);
        uiProject.UpdateAll();
    }
    void action_ProjOpen(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        scope(failure)
        { ShowMessage("PROJECT LOAD ERROR", "Unable to open project file"); return;}
        string rv;
        FileChooserDialog OD = new  FileChooserDialog("What project do you wish to DCompose", mMainWindow, FileChooserAction.OPEN);
        OD.setCurrentFolder(project.defaultProjectRoot);
        OD.setSelectMultiple(false);
        FileFilter ff = new FileFilter;
        ff.setName("D project");
        ff.addPattern("*.dpro");
        FileFilter ff2 = new FileFilter;
        ff2.setName("All");
        ff2.addPattern("*");
        OD.addFilter(ff);
        OD.addFilter(ff2);

        auto resp = OD.run();
        OD.hide();

        if(resp == ResponseType.CANCEL) return ;

        rv = OD.getFilename();
        OD.destroy();

        if(rv is null)return;
        Project.Load(rv) ;
        uiDocBook.setCurrentPage(uiProject);
        uiProject.UpdateAll();
        
    }
    void action_ProjSave(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        Project.Save();
        
    }
        void action_ProjClose(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        Project.Close();
    }
    void action_ProjBuild(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        Project.Build();
    }
    void action_ProjRun(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        Project.Run();
    }
    void action_ProjEdit(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        uiProject.showAll();
        uiDocBook.setCurrentPage(uiProject);
    }
}


UI_PROJECT uiProject;

class UI_PROJECT
{
    private:
    
    Builder                 mBuilder;
    ScrolledWindow          mRoot;
    
    Entry                   uiName;
    Entry                   uiLocation;
    Label                   uiRootFolder;
    ComboBox                uiTargetType;
    ComboBox                uiCompiler;
    Box                     uiTagBox;
    Button                  uiAddTagButton;
    Button                  uiRemoveTagButton;    
    ComboBox                uiTagComboBox;              
    ListStore               uiTagStore;
    TextView[string]        uiTagViews;
    Paned                   uiFilesPane;
    Paned                   uiLinkerPane;
    Paned                   uiCompilerConditionals;
    Paned                   uiCompilerPathsPane;
    Paned                   uiScriptPane;
    Paned                   uiSundryPane;
    Frame                   uiSundryFrame;
    TreeView                uiFlagView;
    CellRendererToggle      uiFlagStateColumn;
    CellRendererText        uiFlagArgColumn;
    ListStore               uiFlagStore;
    CheckButton             uiUseCustomBuildBtn;
    Entry                   uiCustomBuildEntry;
    Label                   uiBuildCommandLabel;
    
    Box                     uiAppStatus;
    Label                   uiAppStatusLabel;
    Image                   uiAppStatusGreenLight;
    Image                   uiAppStatusRedLight;
    Image                   uiAppStatusYellowLight;
    
    UI_LIST[string]         uiLists;
    
    
    
    void UpdateAll()
    {
        uiName.setText(Project.Name);
        uiLocation.setText(Project.Location);
        uiRootFolder.setText(Config.GetValue("project", "project_root", "~/projects/dprojects".expandTilde()));
        uiCompiler.setActiveId(cast(string)Project.Compiler);
        uiTargetType.setActive(Project.Type);
        UpdateUiFlags();
        UpdateTags();
        UpdateUiLists();
        UpdateAppStatus();
        uiUseCustomBuildBtn.setActive(Project.UseCustomCommand());
        uiCustomBuildEntry.setText(Project.GetCustomCommand());
        uiBuildCommandLabel.setText(Project.GetBuildCommand());      
    }
    
    void messageReceiver(PROJECT proj, PROJECT_EVENT event, string content)
    {
        final switch (event)
        {
            case PROJECT_EVENT.CREATED : 
                {
                    UpdateAll();
                }break;
            case PROJECT_EVENT.COMPILER: 
                {
                    uiCompiler.setActiveId(content~"error");
                }break;
            case PROJECT_EVENT.CUSTOM_BUILD_COMMAND: 
                {
                    //uiCustomBuildEntry.setText(content);
                }break;
            case PROJECT_EVENT.EDIT: 
                {
                    uiBuildCommandLabel.setText(Project.GetBuildCommand());
                }break;
            case PROJECT_EVENT.ERROR: break;
            case PROJECT_EVENT.FILE_NAME: break;
            case PROJECT_EVENT.FLAG: 
                {
                    UpdateUiFlags();
                }break;
            case PROJECT_EVENT.LISTS: 
                {
                    UpdateUiLists();   
                }break;
            case PROJECT_EVENT.LOCATION: 
                {
                    uiLocation.setText(content);
                }break;
            case PROJECT_EVENT.NAME:  
                uiName.setText(content);
                UpdateAppStatus();
                break;
            case PROJECT_EVENT.OPENED:
                {
                    UpdateAll();
                }break;
            case PROJECT_EVENT.SAVED: break;
            case PROJECT_EVENT.TAGS: break;
            case PROJECT_EVENT.TARGET_TYPE: 
                {
                    UpdateAll();
                }break;
            case PROJECT_EVENT.USE_CUSTOM_BUILD: break;
            case PROJECT_EVENT.CLOSED:
                UpdateAll();
                mRoot.hide();
                break;
            case PROJECT_EVENT.BUILD:
                UpdateAppStatus();
                break;
        }

    }
    void UpdateTags()
    {
        uiTagBox.removeAll();
        uiTagViews.clear();
        uiTagStore.clear();
        foreach(ref tag; Project.TagKeys)
        {
            //fill combobox
            auto ti = new TreeIter;
            uiTagStore.append(ti);
            uiTagStore.setValue(ti, 0, tag);
            
            Widget textWidget;
            string[] text = Project.GetTag(tag);
            
            uiTagViews[tag] = new TextView();
            string ftest;
            ftest = text.join('\n').strip;
            if(ftest.length) uiTagViews[tag].getBuffer.setText(ftest);
            uiTagViews[tag].setName(tag);
            
            uiTagViews[tag].addOnFocusOut(delegate bool(Event e , Widget w)
            {
                string tbTag = w.getName(); 
                TextBuffer tb = (cast(TextView)w).getBuffer();
                Project.SetTag(tbTag, tb.getText().splitLines());   
                return false;            
            });
            textWidget = cast(Widget)uiTagViews[tag];
            
            Frame tmpFrame = new Frame(textWidget, tag);
            uiTagBox.add(tmpFrame);

        }       
        Entry tmp = cast(Entry)uiTagComboBox.getChild();
        tmp.setText("new tag");   
        uiTagBox.showAll();
    }
    
    void UpdateUiLists()
    {       
        foreach(string key, list; uiLists)
        {
            list.SetItems(Project.List(key));
        }
    }
    
    void UpdateUiFlags()
    {
        scope(exit) GC.enable();
        GC.disable();
        
        dchar[dchar] subs = ['<': '(', '>':')'];
        uiFlagStore.clear();
        auto ti = new TreeIter;
         
        foreach(xflag; Project.GetFlags())
        {
            uiFlagStore.append(ti);
            uiFlagStore.setValue(ti, 0, xflag.mState);
            uiFlagStore.setValue(ti, 1, xflag.mSwitch);
            uiFlagStore.setValue(ti, 2, translate(xflag.mBrief, subs));
            uiFlagStore.setValue(ti, 3, xflag.mArgument);
            uiFlagStore.setValue(ti, 4, (xflag.mType != FLAG_TYPE.SIMPLE) );
            uiFlagStore.setValue(ti, 5, xflag.mId);
        }
    }
    
    void UpdateAppStatus()
    {
        //app status bar
        uiAppStatusLabel.setText("Current Project : " ~ Project.Name);
        uiAppStatusLabel.setTooltipText(buildPath(Project.Location, Project.FileName));
        uiAppStatusGreenLight.hide();
        uiAppStatusYellowLight.hide();
        uiAppStatusRedLight.hide();
        final switch(Project.GetLastBuildState)
        {
            case BUILD_STATE.UNKNOWN   : uiAppStatusYellowLight.show(); break;
            case BUILD_STATE.FAILED    : uiAppStatusRedLight.show(); break;
            case BUILD_STATE.SUCCEEDED : uiAppStatusGreenLight.show();break;
        }
    }
    

    public:
    alias mRoot this;
    
    this(string gladeFile)
    {
        mBuilder = new Builder(gladeFile);
        mRoot = cast(ScrolledWindow)mBuilder.getObject("ui_project_root");
        uiName = cast(Entry)mBuilder.getObject("name_entry");
        uiLocation = cast(Entry)mBuilder.getObject("location_entry");
        uiRootFolder = cast(Label)mBuilder.getObject("root_folder_label");
        uiCompiler = cast(ComboBox)mBuilder.getObject("compiler_combo");
        uiTargetType = cast(ComboBox)mBuilder.getObject("target_combo");
        uiTagBox = cast(Box)mBuilder.getObject("tag_box");
        uiAddTagButton = cast(Button)mBuilder.getObject("add_tag");
        uiRemoveTagButton = cast(Button)mBuilder.getObject("remove_tag");     
        uiTagComboBox = cast(ComboBox)mBuilder.getObject("tag_combobox");
        uiTagStore = cast(ListStore)mBuilder.getObject("tag_store");
        uiFilesPane = cast(Paned)mBuilder.getObject("files_pane");        
        uiLinkerPane = cast(Paned)mBuilder.getObject("linker_pane");
        uiFlagView = cast(TreeView)mBuilder.getObject("flag_view");
        uiFlagStore = cast(ListStore)mBuilder.getObject("flag_store");
        uiFlagStateColumn = cast(CellRendererToggle)mBuilder.getObject("toggled_col");
        uiFlagArgColumn = cast(CellRendererText)mBuilder.getObject("args_col");
        uiCompilerConditionals = cast(Paned)mBuilder.getObject("compiler_conditionals_pane");
        uiCompilerPathsPane = cast(Paned)mBuilder.getObject("compiler_paths_pane");
        uiScriptPane = cast(Paned)mBuilder.getObject("script_pane");
        uiSundryPane = cast(Paned)mBuilder.getObject("sundry_pane");
        uiSundryFrame = cast(Frame)mBuilder.getObject("sundry_frame");
        uiUseCustomBuildBtn = cast(CheckButton)mBuilder.getObject("custom_build_checkbutton");
        uiCustomBuildEntry = cast(Entry)mBuilder.getObject("custom_build_entry");
        uiBuildCommandLabel = cast(Label)mBuilder.getObject("build_command_label");
        
        //appstatus stuff (app status vs docbook status bar)
        uiAppStatus = new Box(Orientation.HORIZONTAL, 2);
        uiAppStatus.setHalign(Align.END);
        uiAppStatus.setHexpand(true);
        uiAppStatusLabel = new Label("No project.");
        uiAppStatusGreenLight = new Image(Config.GetResource("icons", "green_light", "resources", "status.png"));
        uiAppStatusGreenLight.setNoShowAll(true);
        uiAppStatusGreenLight.setTooltipText("Last known build succeeded");
        uiAppStatusRedLight = new Image(Config.GetResource("icons", "red_light", "resources", "status-busy.png"));
        uiAppStatusRedLight.setNoShowAll(true);
        uiAppStatusRedLight.setTooltipText("Last known build failed");
        uiAppStatusYellowLight = new Image(Config.GetResource("icons", "yello_light", "resources", "status-offline.png"));
        uiAppStatusYellowLight.setNoShowAll(true);
        uiAppStatusYellowLight.setTooltipText("Last build not known");
        
        uiAppStatusYellowLight.show();
        
        uiAppStatus.packStart(uiAppStatusLabel, false, true, 2);
        uiAppStatus.packStart(uiAppStatusGreenLight, false, false, 2);
        uiAppStatus.packStart(uiAppStatusYellowLight, false, false, 2);
        uiAppStatus.packStart(uiAppStatusRedLight, false, false, 2);
        uiAppStatus.showAll();
    }
       
    void Engage()
    {
        Transmit.ProjectEvent.connect(&messageReceiver);
        uiName.addOnEditingDone(delegate void(CellEditableIF intre)
        {
            Project.Name = uiName.getText();
            uiAppStatusLabel.setText(Project.Name);
        });
        uiName.addOnFocusOut(delegate bool (Event ev, Widget w)
        {
            uiName.editingDone();
            return false;
        });
        uiName.addOnActivate(delegate void(Entry ntry)
        {
            uiName.editingDone();
        });
        
        uiLocation.addOnEditingDone(delegate void(CellEditableIF ntre)
        {
            Project.Location = uiLocation.getText();
        });
        uiLocation.addOnFocusOut(delegate bool (Event ev, Widget w)
        {
            uiLocation.editingDone();
            return false;
        });
        uiLocation.addOnActivate(delegate void(Entry ntry)
        {
            uiLocation.editingDone();
        });
        
        uiTargetType.addOnChanged(delegate void (ComboBox cbox)
        {
            Project.Type = cast(TARGET_TYPE)cbox.getActive();   
        });
        uiCompiler.addOnChanged(delegate void (ComboBox cbox)
        {
            Project.Compiler = cast(COMPILER)cbox.getActiveId(); 
        });
        uiAddTagButton.addOnClicked(delegate void(btn)
        {
            auto entrydialog = new MessageDialog(mMainWindow,
                                                 DialogFlags.MODAL,
                                                 MessageType.OTHER,
                                                 ButtonsType.OK,
                                                 "%s",
                                                 "Tag Name?") ;
            auto tagEntry = new Entry();
            tagEntry.setText("tmp\0");
            tagEntry.addOnActivate(delegate void(Entry intri)
            {
                entrydialog.response(ResponseType.OK);
            });
            entrydialog.getContentArea.add(tagEntry);
            entrydialog.getContentArea.showAll();
            
            auto dialogResponse = entrydialog.run();
            entrydialog.close();
            if(dialogResponse == ResponseType.OK)
            {
                Project.SetTag(tagEntry.getText(), []);
                UpdateTags();
            }
            
        });      
        
        uiRemoveTagButton.addOnClicked(delegate void(Button btn)
        {
            auto ti = new TreeIter;
            if(uiTagComboBox.getActiveIter(ti))
            {
                string tagKey = uiTagStore.getValueString(ti, 0);
                Project.TagRemove(tagKey);
                uiTagStore.remove(ti);   
                UpdateTags();
            }
        });  
        
        static foreach (listKey; EnumMembers!LIST_KEYS)
        {
            uiLists[listKey] = new UI_LIST(listKey);
        }
        uiFilesPane.add1(uiLists[LIST_KEYS.SOURCE].GetRootWidget);
        uiFilesPane.add2(uiLists[LIST_KEYS.RELATED].GetRootWidget);
        uiLinkerPane.add1(uiLists[LIST_KEYS.LIBRARIES].GetRootWidget);
        uiLinkerPane.add2(uiLists[LIST_KEYS.LIBRARY_PATHS].GetRootWidget);
        uiScriptPane.add1(uiLists[LIST_KEYS.PRE_SCRIPTS].GetRootWidget());
        uiScriptPane.add2(uiLists[LIST_KEYS.POST_SCRIPTS].GetRootWidget());
        
        uiFlagStateColumn.addOnToggled(delegate void(string strPath, CellRendererToggle crt)
        {
           auto ti = new TreeIter;
           uiFlagStore.getIterFromString(ti, strPath);
           string flagKey = uiFlagStore.getValueString(ti, 5);
           
           string currArg;
           bool currState = Project.GetFlag(flagKey, currArg);
           Project.SetFlag(flagKey, !currState, currArg);
           uiFlagStore.setValue(ti, 0, !currState);           
        });
        uiFlagArgColumn.addOnEdited(delegate void(string path, string text,CellRendererText crt)
        {
            TreeIter ti = new TreeIter;
            uiFlagStore.getIterFromString(ti, path);
            string flagKey = uiFlagStore.getValueString(ti, 5);
            string currArg;
            bool currState;
            
            currState = Project.GetFlag(flagKey, currArg);
            
            Project.SetFlag(flagKey, currState, text);
            uiFlagStore.setValue(ti, 3, text);           
        });
        
        uiCompilerConditionals.add1(uiLists[LIST_KEYS.VERSION].GetRootWidget());
        uiCompilerConditionals.add2(uiLists[LIST_KEYS.DEBUG].GetRootWidget());
        uiCompilerPathsPane.add1(uiLists[LIST_KEYS.IMPORT_PATHS].GetRootWidget());
        uiCompilerPathsPane.add2(uiLists[LIST_KEYS.STRING_PATHS].GetRootWidget());
        uiSundryFrame.add(uiLists[LIST_KEYS.SUNDRY].GetRootWidget());
        
        uiUseCustomBuildBtn.addOnToggled(delegate void(ToggleButton tb)
        {
            //tb.setActive(!tb.getActive);
            Project.UseCustomCommand(tb.getActive());
        });
        
        uiCustomBuildEntry.addOnEvent(delegate bool(Event ev, Widget wjt)
        {
            Project.SetCustomBuildCommand(uiCustomBuildEntry.getText());
            return false;
        });
        
        AddEndStatusWidget(uiAppStatus);

    }
    void Mesh()
    {
        uiFilesPane.setPosition(Config.GetValue("ui_project", "files_pane", 100));
        uiCompilerConditionals.setPosition(Config.GetValue("ui_project", "compiler_conditionals_pane", 100));
        uiCompilerPathsPane.setPosition(Config.GetValue("ui_project", "compiler_paths_pane", 100));
        uiLinkerPane.setPosition(Config.GetValue("ui_project", "linker_pane", 100));
        uiScriptPane.setPosition(Config.GetValue("ui_project", "script_pane", 100));
        uiSundryPane.setPosition(Config.GetValue("ui_project", "sundry_pane", 100));
    }
    void Disengage()
    {
        Config.SetValue("ui_project", "sundry_pane",uiSundryPane.getPosition());
        Config.SetValue("ui_project", "script_pane", uiScriptPane.getPosition());
        Config.SetValue("ui_project", "linker_pane", uiLinkerPane.getPosition());
        Config.SetValue("ui_project", "compiler_paths_pane", uiCompilerPathsPane.getPosition());
        Config.SetValue("ui_project", "compiler_conditionals_pane", uiCompilerConditionals.getPosition());
        Config.SetValue("ui_project", "files_pane", uiFilesPane.getPosition());
        Transmit.ProjectEvent.disconnect(&messageReceiver);
    }

}
