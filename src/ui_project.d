module ui_project;

import dcore;
import ui;
import ui_list;

import std.algorithm;
import std.path;
import std.file;
import std.string;
import std.stdio;

import core.memory;

import json;

import gtk.Adjustment;
import gtk.Builder;
import gtk.Label;
import gtk.Button;
import gtk.Frame;
import gtk.Entry;
import gtk.EditableIF;
import gtk.ComboBoxText;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.ListStore;
import gtk.TreeModelIF;
import gtk.TreePath;
import gtk.TreeIter;
import gtk.CheckButton;
import gtk.ToggleButton;
import gtk.Box;
import gtk.Widget;
import gtk.Action;
import gtk.CellRendererText;
import gtk.CellRendererToggle;
import gtk.FileChooserDialog;
import gtk.Dialog;
import gtk.FileFilter;

import gobject.Value;



class UI_PROJECT
{
    private :

    Frame   mRootWidget;

    Label   ProjTitle;
    Button  ProjHide;

    Entry   ProjName;
    Entry   ProjRelPath;
    Label   ProjAbsPath;
    ComboBoxText ProjTargetType;
    ComboBoxText ProjCompiler;
    TextView ProjNotes;

    UI_LIST ProjSrcFiles;
    UI_LIST ProjRelFiles;

    TreeView ProjFlagsView;
    ListStore ProjFlagsStore;
    CellRendererText ProjCellArgs;
    CellRendererToggle ProjCellToggle;
    UI_LIST ProjVersions;
    UI_LIST ProjDebugs;
    UI_LIST ProjImportPaths;
    UI_LIST ProjStringExpressionPaths;

    UI_LIST ProjLibraries;
    UI_LIST ProjLibraryPaths;

    UI_LIST ProjOtherFlags;
    UI_LIST ProjPreBuildScripts;
    UI_LIST ProjPostBuildScripts;
    CheckButton ProjCustomBuild;
    Entry ProjCustomBuildCommand;
    TextView ProjGeneratedBuildCommand;

    bool mFlagsLoading; //variable to stop emitting signal when initially loading flags (on project open)

    void WatchProject(PROJECT_EVENT event)
    {
        switch (event) with(PROJECT_EVENT)
        {
            case OPENED:
            case CREATED:
            {
                ProjRelPath.setText(relativePath(Project.Folder, Project.DefaultProjectRootPath));
                UpdateFlags();
                mRootWidget.show();
                //DocBook.setCurrentPage(mRootWidget);
                break;
            }
            case EDIT:
            {
                mRootWidget.show();
                DocBook.setCurrentPage(mRootWidget);
                break;
            }
            case NAME:
            case FOLDER:
            {
                if(WeAreSettingNameAndFolder)break;
                ProjName.setText(Project.Name);
                ProjRelPath.setText(relativePath(Project.Folder, Project.DefaultProjectRootPath));
                break;
            }
            case COMPILER:
            {
                ProjCompiler.setActive(ProjCompiler.getIndex(Project.Compiler));
                break;
            }
            case TARGET_TYPE:
            {
                ProjTargetType.setActive(Project.TargetType);
                break;
            }
            case USE_CUSTOM_BUILD:
            {
                ProjCustomBuild.setActive(Project.UseCustomBuild);
                break;
            }
            case CUSTOM_BUILD_COMMAND:
            {
                ProjCustomBuildCommand.setText(Project.CustomBuildCommand);
                break;
            }
            case FLAG:
            {
                UpdateFlags();
                break;
            }


            case LISTS:
            {
                foreach(key,lillist; Project.Lists)
                {
                    switch (key) with(LIST_NAMES)
                    {
                        case SRC_FILES: ProjSrcFiles.UpdateItems(lillist); break;
                        case REL_FILES: ProjRelFiles.UpdateItems(lillist); break;
                        case VERSIONS: ProjVersions.UpdateItems(lillist);  break;
                        case DEBUGS: ProjDebugs.UpdateItems(lillist);  break;
                        case IMPORT: ProjImportPaths.UpdateItems(lillist); break;
                        case STRING: ProjStringExpressionPaths.UpdateItems(lillist); break;
                        case LIBRARIES: ProjLibraries.UpdateItems(lillist); break;
                        case LIBRARY_PATHS: ProjLibraryPaths.UpdateItems(lillist); break;
                        case PREBUILD: ProjPreBuildScripts.UpdateItems(lillist); break;
                        case POSTBUILD: ProjPostBuildScripts.UpdateItems(lillist); break;
                        case OTHER: ProjOtherFlags.UpdateItems(lillist);  break;
                        case NOTES:
                        {
                            if(Project.Lists[key].length > 0)ProjNotes.getBuffer().setText(Project.Lists[key][0]);
                            else ProjNotes.getBuffer().setText("");break;
                        }
                        default: writeln("not here!!", key);break;
                    }
                }
                break;
            }
            default :break;
        }
        ProjGeneratedBuildCommand.getBuffer.setText("");
        foreach(ln;Project.BuildCommand())ProjGeneratedBuildCommand.appendText(ln ~ "\n");
    }

    void WatchLists(string ListName, string[] Values)
    {
        Project.SetListData(ListName, Values);
    }

    bool WeAreSettingNameAndFolder;
    void  CalculateFolder()
    {
        WeAreSettingNameAndFolder = true;
        scope(exit)WeAreSettingNameAndFolder = false;

        ProjAbsPath.setText(buildNormalizedPath(Project.DefaultProjectRootPath, ProjRelPath.getText(), ProjName.getText().setExtension(".dpro")));
        Project.Name = ProjName.getText();
        Project.Folder = buildNormalizedPath(Project.DefaultProjectRootPath, ProjRelPath.getText());

        //Project.SetNameAndFolder(ProjName.getText(), buildPath(Project.DefaultProjectRootPath, ProjRelPath.getText()));
        ui.SetProjectTitle(Project.Name);
    }


    void LoadFlags()
    {
        ProjFlagsStore.clear();

        foreach (obj; Project.Flags())
        {
            auto ti = new TreeIter;
            ProjFlagsStore.append(ti);
            ProjFlagsStore.setValue(ti, 0, false);
            ProjFlagsStore.setValue(ti, 1, obj.mSwitch);
            ProjFlagsStore.setValue(ti, 2, " ");
            ProjFlagsStore.setValue(ti, 3, obj.mBrief);
            ProjFlagsStore.setValue(ti, 4, obj.mArgument);
        }
    }

    void UpdateFlags()
    {
        auto ti = new TreeIter;

        int NotLastFlag = ProjFlagsStore.getIterFirst(ti);

        while(NotLastFlag)
        {

            auto cmdswitch = ProjFlagsStore.getValueString(ti, 1);
            auto cmdBrief = ProjFlagsStore.getValueString(ti, 3);
            if (cmdswitch.length < 1) return;
            auto state = cast(int)Project.GetFlag(cmdswitch, cmdBrief);
            auto arg = Project.GetFlagArgument(cmdswitch, cmdBrief);

            ProjFlagsStore.setValue(ti, 0, state);
            ProjFlagsStore.setValue(ti, 2, arg);

            NotLastFlag = ProjFlagsStore.iterNext(ti);
        }

    }


    public :

    void Engage()
    {
        mFlagsLoading = false;

        auto uiBuilder = new Builder;
        uiBuilder.addFromFile( SystemPath( Config.GetValue("ui_project", "glade_file",  "glade/ui_project.glade")));

        mRootWidget     = cast(Frame)uiBuilder.getObject("frame1");

        ProjTitle       = cast(Label)uiBuilder.getObject("label2");
        ProjHide        = cast(Button)uiBuilder.getObject("hideBtn");

        ProjName        = cast(Entry)uiBuilder.getObject("projName");
        ProjRelPath     = cast(Entry)uiBuilder.getObject("relPath");
        ProjAbsPath     = cast(Label)uiBuilder.getObject("absPath");
        ProjTargetType  = cast(ComboBoxText)uiBuilder.getObject("targetType");
        ProjCompiler    = cast(ComboBoxText)uiBuilder.getObject("compiler");
        ProjNotes       = cast(TextView)uiBuilder.getObject("textview1");

        auto filesbox   = cast(Box)uiBuilder.getObject("box2");

        ProjFlagsView   = cast(TreeView)uiBuilder.getObject("flagsView");
        ProjFlagsStore  = cast(ListStore)uiBuilder.getObject("liststore1");
        ProjCellArgs    = cast(CellRendererText)uiBuilder.getObject("cellrenderertext2");
        ProjCellToggle  = cast(CellRendererToggle)uiBuilder.getObject("cellrenderertoggle1");
        auto condbox    = cast(Box)uiBuilder.getObject("conditionalBox");
        auto pathbox    = cast(Box)uiBuilder.getObject("pathsBox");

        auto linkerbox  = cast(Box)uiBuilder.getObject("box3");

        auto flagsbox   = cast(Box)uiBuilder.getObject("box4");
        auto scriptbox  = cast(Box)uiBuilder.getObject("box5");
        ProjCustomBuild = cast(CheckButton)uiBuilder.getObject("checkbutton1");
        ProjCustomBuildCommand = cast(Entry)uiBuilder.getObject("entry1");
        ProjGeneratedBuildCommand = cast(TextView)uiBuilder.getObject("textview2");

        //------ setup ui_lists
        with(LIST_NAMES)
        {
            ProjSrcFiles = new UI_LIST(SRC_FILES, ListType.FILES);
            filesbox.packStart(ProjSrcFiles.GetRootWidget(), 1, 1, 1);
            ProjRelFiles = new UI_LIST(REL_FILES, ListType.FILES);
            filesbox.packStart(ProjRelFiles.GetRootWidget(), 1, 1, 1);

            ProjVersions = new UI_LIST(VERSIONS, ListType.IDENTIFIERS);
            condbox.packStart(ProjVersions.GetRootWidget(), 1, 1, 1);
            ProjDebugs = new UI_LIST(DEBUGS, ListType.IDENTIFIERS);
            condbox.packStart(ProjDebugs.GetRootWidget(), 1, 1, 1);

            ProjImportPaths = new UI_LIST(IMPORT, ListType.PATHS);
            pathbox.packStart(ProjImportPaths.GetRootWidget(), 1, 1, 1);
            ProjStringExpressionPaths = new UI_LIST(STRING, ListType.PATHS);
            pathbox.packStart(ProjStringExpressionPaths.GetRootWidget(), 1, 1, 1);

            ProjLibraries = new UI_LIST(LIBRARIES, ListType.FILES);
            linkerbox.packStart(ProjLibraries.GetRootWidget(), 1, 1, 1);
            ProjLibraryPaths = new UI_LIST(LIBRARY_PATHS, ListType.PATHS);
            linkerbox.packStart(ProjLibraryPaths.GetRootWidget(), 1, 1, 1);

            ProjOtherFlags = new UI_LIST(OTHER, ListType.IDENTIFIERS);
            flagsbox.packStart(ProjOtherFlags.GetRootWidget(), 1, 1, 1);
            flagsbox.reorderChild(ProjOtherFlags.GetRootWidget(), 0);

            ProjPreBuildScripts = new UI_LIST(PREBUILD, ListType.FILES);
            ProjPostBuildScripts = new UI_LIST(POSTBUILD, ListType.FILES);
            scriptbox.packStart(ProjPreBuildScripts.GetRootWidget(), 1, 1, 0);
            scriptbox.packStart(ProjPostBuildScripts.GetRootWidget(), 1, 1, 0);
        }
        LoadFlags();

        //========================================================================
        // actions ===============================================================

        //new
        AddIcon("dcmp-proj-new", SystemPath( Config.GetValue("icons", "proj-new", "resources/color-new.png")));
        auto ActNew = "ActProjNew".AddAction("_New","Create a project", "dcmp-proj-new","<Control>F5",delegate void(Action a){Project.Create();});
        AddToMenuBar("ActProjNew", "_Project");

        //Open
        AddIcon("dcmp-proj-open", SystemPath( Config.GetValue("icons", "proj-open",  "resources/color-open.png")));
        auto ActOpen = "ActProjOpen".AddAction("_Open","Open a project", "dcmp-proj-open","<Control>F6",delegate void(Action a){Open();});
        AddToMenuBar("ActProjOpen", "_Project");

        //Save
        AddIcon("dcmp-proj-save", SystemPath( Config.GetValue("icons", "proj-save", "resources/color-save.png")));
        auto ActSave = "ActProjSave".AddAction("_Save","Save project", "dcmp-proj-save","<Control>F7",delegate void(Action a){Project.Save();});
        AddToMenuBar("ActProjSave", "_Project");

        //Edit
        AddIcon("dcmp-proj-edit", SystemPath( Config.GetValue("icons", "proj-edit",  "resources/color-edit.png")));
        auto ActEdit = "ActProjEdit".AddAction("_Edit","Edit project", "dcmp-proj-edit","<Control>F8",delegate void(Action a){Project.Edit();});
        AddToMenuBar("ActProjEdit", "_Project");

        //Build
        AddIcon("dcmp-proj-build", SystemPath( Config.GetValue("icons", "proj-build",  "resources/color-build.png")));
        auto ActBuild = "ActProjBuild".AddAction("_Build","Build project", "dcmp-proj-build","<Control>F9",delegate void(Action a){SetBusyCursor(true);Project.Build();SetBusyCursor(false);});
        AddToMenuBar("ActProjBuild", "_Project");

        //run
        AddIcon("dcmp-proj-run", SystemPath( Config.GetValue("icons", "proj-run", "resources/color-arrow.png")));
        auto ActRun = "ActProjRun".AddAction("_Run","Run project", "dcmp-proj-run","<Control>F10",delegate void(Action a){Project.Run();});
        AddToMenuBar("ActProjRun", "_Project");

        //run args
        AddIcon("dcmp-proj-run-args", SystemPath( Config.GetValue("icons", "proj-run-args",  "resources/color-run-args.png")));
        auto ActRunArgs = "ActProjRunArgs".AddAction("Run with _Args","Run project with arguments", "dcmp-proj-run-args","<Control><Shift>F10",delegate void(Action a){auto args = GetArgs(); Project.Run(args);});
        AddToMenuBar("ActProjRunArgs", "_Project");

        //Close
        AddIcon("dcmp-proj-close", SystemPath( Config.GetValue("icons", "proj-close",  "resources/color-close.png")));
        auto ActClose = "ActProjClose".AddAction("_Close","Close project", "dcmp-proj-close","<Control><Shift>F5",delegate void(Action a){Project.Close();mRootWidget.hide();});
        AddToMenuBar("ActProjClose", "_Project");

        //=============================================================================================================
        //=============================================================================================================
        //signals!!!

        ProjHide.addOnClicked(delegate void(Button b){mRootWidget.hide();});

        ProjName.addOnChanged(delegate void (EditableIF e)
        {
            auto xtext = ProjName.getText().removechars(`\/`);
            if(xtext.length == 0)xtext = "";
            ProjName.setText(xtext);
            ProjRelPath.setText(xtext);
            //CalculateFolder();
        });

        ProjRelPath.addOnChanged(delegate void (EditableIF)
        {
            CalculateFolder();
        });
        ProjTargetType.addOnChanged(delegate void (ComboBoxText cbt){Project.TargetType = cast(TARGET)ProjTargetType.getActive();});
        ProjCompiler.addOnChanged(delegate void (ComboBoxText cbt){Project.Compiler = cast(COMPILER)ProjCompiler.getActiveText();});
        ProjNotes.getBuffer().addOnChanged(delegate void (TextBuffer tb){Project.Lists["Notes"] = tb.getText();});
        ProjCustomBuild.addOnToggled(delegate void(ToggleButton tb){Project.UseCustomBuild = cast(bool)tb.getActive();ProjCustomBuildCommand.setEditable(ProjCustomBuild.getActive());});
        ProjCustomBuildCommand.addOnChanged(delegate void (EditableIF e){Project.CustomBuildCommand = ProjCustomBuildCommand.getText();});


        ProjLibraries.mStore.addOnRowInserted (delegate void(TreePath, TreeIter, TreeModelIF)
        {
            Project.SetListData(LIST_NAMES.LIBRARIES, ProjLibraries.GetItems());
        });


        ProjSrcFiles.connect(&WatchLists);
        ProjRelFiles.connect(&WatchLists);
        ProjImportPaths.connect(&WatchLists);
        ProjStringExpressionPaths.connect(&WatchLists);
        ProjVersions.connect(&WatchLists);
        ProjDebugs.connect(&WatchLists);
        ProjLibraries.connect(&WatchLists);
        ProjLibraryPaths.connect(&WatchLists);
        ProjPreBuildScripts.connect(&WatchLists);
        ProjPostBuildScripts.connect(&WatchLists);
        ProjOtherFlags.connect(&WatchLists);


        Project.Event.connect(&WatchProject);

        ProjCellToggle.addOnToggled(delegate void(string path, CellRendererToggle crt)
        {

            auto ti = new TreeIter(ProjFlagsStore, path);
            auto oldvalue = ProjFlagsStore.getValue(ti, 0);
            int bvalue = oldvalue.getBoolean();
            oldvalue.setBoolean(!bvalue);
            Project.SetFlag(ProjFlagsStore.getValueString(ti, 1), ProjFlagsStore.getValueString(ti, 3), cast(bool)oldvalue.getBoolean());

        }, cast(GConnectFlags)1);
        ProjCellArgs.addOnEdited(delegate void (string path, string text, CellRendererText crt)
        {
            if(mFlagsLoading == true)return;
            auto ti = new TreeIter(ProjFlagsStore, path);
            Project.SetFlagArgument(ProjFlagsStore.getValueString(ti, 1), ProjFlagsStore.getValueString(ti, 3), text);
        });

        bool IsVisible = Config.GetValue("ui_project", "is_visible", true);
        mRootWidget.setVisible(IsVisible);
        Log.Entry("Engaged");
    }

    void PostEngage()
    {

    }

    void Disengage()
    {
        bool IsVisible = cast(bool)mRootWidget.isVisible();
        Config.SetValue("ui_project", "is_visible", IsVisible);
        Log.Entry("Disengaged");
    }

    Widget GetRootWidget()
    {
        return cast(Widget) mRootWidget;
    }

    void Open()
    {
        string rv;
        FileChooserDialog OD = new  FileChooserDialog("What project do you wish to DCompose", MainWindow, FileChooserAction.OPEN);
        OD.setCurrentFolder(Project.DefaultProjectRootPath);
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
        Project.Open(rv) ;
    }
/** this is a comment!!!
 * */
    string[] GetArgs()
    {
        static string[] lastargs;

        auto ArgList = new UI_LIST("Program Arguments", ListType.IDENTIFIERS);
        ArgList.SetItems(lastargs);

        auto ArgDialog = new Dialog("Run with Arguments", ui.MainWindow, DialogFlags.MODAL, ["Ok",],[ResponseType.OK]);

        ArgDialog.getContentArea().packStart(ArgList.GetRootWidget(), 1, 1, 10);

        ArgDialog.run();
        ArgDialog.hide();

        lastargs = ArgList.GetItems();
        return lastargs;
    }

    void SetRootPath(string NuBasePath)
    {

        ProjDebugs.SetRootPath(NuBasePath);
        ProjImportPaths.SetRootPath(NuBasePath);
        ProjLibraries.SetRootPath(NuBasePath);
        ProjLibraryPaths.SetRootPath(NuBasePath);
        ProjOtherFlags.SetRootPath(NuBasePath);
        ProjPostBuildScripts.SetRootPath(NuBasePath);
        ProjPreBuildScripts.SetRootPath(NuBasePath);
        ProjRelFiles.SetRootPath(NuBasePath);
        ProjSrcFiles.SetRootPath(NuBasePath);
        ProjStringExpressionPaths.SetRootPath(NuBasePath);
        ProjVersions.SetRootPath(NuBasePath);
    }
}
