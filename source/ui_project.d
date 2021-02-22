module ui_project;

import std.format;

import qore;
import ui;

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
    
    auto pBuilder = new Builder(Config.GetResource("ui_project", "glade_file", "glade", "ui_project.glade"));
    mRoot = cast(ScrolledWindow)pBuilder.getObject("ui_project_root");
    Log.Entry("\tui_project Engaged");
}

void Mesh()
{
    mRoot.setVisible(false);
    mDocBook.prependPage(mRoot, new Label("Project Editor"));
    
    Log.Entry("\tui_project Meshed");
}

void Disengage()
{
    Log.Entry("\tui_project Disengaged");
}

string StatusLine()
{
    string layout = "Project: %s";
    string retString = format(layout, mProject.Name);
    return retString;
}

extern(C) 
{
    void action_ProjNew(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        Project.Close();
        
        dwrite("projNew");
    }
    void action_ProjOpen(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
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
        
    }
    void action_ProjSave(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        Project.Save();
        
    }
        void action_ProjClose(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        dwrite("projClose");
    }
    void action_ProjBuild(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        dwrite("projBuild");
    }
    void action_ProjRun(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        dwrite("projRun");
    }
    void action_ProjEdit(GSimpleAction * action, GVariant * parameter, void * user_data)
    {
        mRoot.showAll();
        mDocBook.setCurrentPage(mRoot);
        dwrite("projEdit");
    }
}


private:

ScrolledWindow mRoot;


