module ui_list;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.process: environment;
import core.memory;

import gio.FileIF;


import ui;
import qore;

class UI_LIST
{
    private:
    Box         mRootBin;
    Label       mListTitle;
    TreeView    mListView;
    CellRendererText mCellRenderText;
    ListStore   mListStore;
    string      mListKey;
    bool        mEditable;
    
    Button      mAddButton;
    Button      mRemoveButton;
    Button      mClearButton;
    
    string[] UpdateDataList()
    {
        string[] rv;
        TreeIter ti = new TreeIter;
        mListStore.getIterFirst(ti);
        do
        {
            rv ~= ti.getValueString(0);
        }while (mListStore.iterNext(ti));
        return rv;
        
    }
    
    string FindLibrary(string library)
    {
        scope(exit)GC.enable();
        GC.disable();
        string rv;
        string[] searchPaths;
        string bigEnvString;
        
        //ld env variable
        if("LD_LIBRARY_PATH" in environment) bigEnvString = environment["LD_LIBRARY_PATH"];
        searchPaths = split(bigEnvString,':');
        
        //projects library paths
        searchPaths ~= Project.List(LIST_KEYS.LIBRARY_PATHS);
        
        //ld.conf stuff
        //--ok save for a minute
        
        searchPaths ~= "/usr";
        searchPaths ~= "/usr/lib";
        
        foreach(path;searchPaths)
        {
            foreach(string item; dirEntries(path,SpanMode.shallow))
            {

                if(canFind(library, item))rv ~= buildNormalizedPath(item) ~ '\n';
            }
             //rv ~= dirEntries(path, SpanMode.shallow).filter!(f => f.name.canFind(library)).to!string;
        }

        return rv;
    }
    
    public:
    this (string ListKey)
    {
        auto mBuilder = new Builder(Config.GetResource("ui_list", "glade_file", "glade", "ui_list.glade"));
        mRootBin = cast(Box)mBuilder.getObject("ui_list_root");
        mListStore = cast(ListStore)mBuilder.getObject("liststore1");
        mListView = cast(TreeView)mBuilder.getObject("list_view");
        mCellRenderText = cast(CellRendererText)mBuilder.getObject("lv_text");
        mListView.setModel(mListStore);
        mListKey = ListKey; 
        mListTitle = cast(Label)mBuilder.getObject("list_title_label");
        mListTitle.setText(ListKey);
        mListStore.clear();
        
        mEditable = true;
        if ((mListKey == LIST_KEYS.IMPORT_PATHS) ||
            (mListKey == LIST_KEYS.LIBRARY_PATHS)||
            (mListKey == LIST_KEYS.POST_SCRIPTS) ||
            (mListKey == LIST_KEYS.PRE_SCRIPTS)  ||
            (mListKey == LIST_KEYS.POST_SCRIPTS) ||
            (mListKey == LIST_KEYS.RELATED)      ||
            (mListKey == LIST_KEYS.SOURCE)       ||
            (mListKey == LIST_KEYS.STRING_PATHS)) mEditable = false;
        if(mListKey == LIST_KEYS.LIBRARIES) mEditable = true;
        
        
        mCellRenderText.addOnEdited(delegate void(string path, string nu_text, CellRendererText crt)
        {
            string tooltip = nu_text;
            if(mListKey == LIST_KEYS.LIBRARIES)
            {
                tooltip = FindLibrary(nu_text);                
            }
           
            auto ti = new TreeIter(mListStore, path);
            mListStore.setValue(ti, 0, nu_text);
            mListStore.setValue(ti, 1, nu_text);
            mListStore.setValue(ti, 2, tooltip);
            mListStore.setValue(ti, 3, mEditable);
            Project.ListSet(mListKey, GetItems());         
        });
        
        mAddButton = cast(Button)mBuilder.getObject("new_button");
        mAddButton.addOnClicked(delegate void(Button btn)
        {
            if(endsWith(mListKey, "Files"))
            {
                AppendFile();
                return;
            }
            if(endsWith(mListKey, "Paths"))
            {
                AppendPath();
                return;
            }
            if(mListKey == LIST_KEYS.LIBRARIES)
            {
                AppendLibrary("library");
                return;
            }
            AppendItem("new " ~ mListKey);

        });
        mRemoveButton = cast(Button)mBuilder.getObject("remove_button");
        mRemoveButton.addOnClicked(delegate void(Button btn)
        {
            RemoveSelectedItems();
        });
        
        mClearButton = cast(Button)mBuilder.getObject("clear_button");
        mClearButton.addOnClicked(delegate void(Button btn)
        {
             ClearItems();   
        });
        
    }
    Widget GetRootWidget()
    {
        return mRootBin;
    }
    string[] GetItems()
    {
        string[] rv;
        TreeIter ti;
        mListStore.getIterFirst(ti);        
        if(ti is null) return rv;
        while(mListStore.iterIsValid(ti))
        {
            rv ~= mListStore.getValueString(ti, 0);
            mListStore.iterNext(ti);
        }
        return rv;
    }
    void SetItems(string[] Items)
    {
        auto ti = new TreeIter;
        mListView.setModel(null);
        mListStore.clear();
        
        foreach(item; Items)
        {
            mListStore.append(ti);
            mListStore.setValue(ti, 0, item);
            mListStore.setValue(ti, 1, item);
            mListStore.setValue(ti, 2, item);
            mListStore.setValue(ti, 3, mEditable);   
        }
        mListView.setModel(mListStore);
        
    }
    void AppendItem(string Item)
    { 
        auto ti = new TreeIter;
        mListStore.append(ti);  
        mListStore.setValue(ti, 0, Item);  
        mListStore.setValue(ti, 1, Item);
        mListStore.setValue(ti, 2, Item);
        mListStore.setValue(ti, 3, mEditable);   
        mListView.setCursor(mListStore.getPath(ti), mListView.getColumn(0), true);
    }
    void AppendFile()
    {
        auto fileDialog = new FileChooserDialog("Find Library", mMainWindow, FileChooserAction.OPEN);
        fileDialog.setModal(true);
        fileDialog.setSelectMultiple(true);
        fileDialog.setCurrentFolder(Project.FullPath.dirName());

        auto resp = fileDialog.run();
        if(resp == ResponseType.OK)
        {
            auto items = fileDialog.getFilenames().toArray!string();
            auto folder = fileDialog.getCurrentFolder();
            
            foreach(item; items)
            {
                string base = baseName(item);
                string abs = item;
                string relative = asRelativePath(item, Project.FullPath().dirName()).to!string;
                //relative = buildNormalizedPath(Project.FullPath().dirName(), relative);
                auto ti = new TreeIter;
                mListStore.append(ti);  
                mListStore.setValue(ti, 0, relative);  
                mListStore.setValue(ti, 1, abs);
                mListStore.setValue(ti, 2, base);
                mListStore.setValue(ti, 3, mEditable);      
                Project.ListAppend(mListKey, relative);     //this is not right mLists should be private               
            }
        }
        fileDialog.close();
    }
    void AppendPath()
    {
        auto fileDialog = new FileChooserDialog("Find Library", mMainWindow, FileChooserAction.SELECT_FOLDER);
        fileDialog.setModal(true);
        fileDialog.setSelectMultiple(true);
        fileDialog.setCurrentFolder(Project.FullPath.dirName());

        auto resp = fileDialog.run();
        if(resp == ResponseType.OK)
        {
            auto items = fileDialog.getFilenames().toArray!string();
            auto folder = fileDialog.getCurrentFolder();
            
            foreach(item; items)
            {
                string base = item;
                string abs = item;
                string relative = relativePath(item, Project.FullPath().dirName());
                relative = buildNormalizedPath(Project.Location().dirName(), relative);
                auto ti = new TreeIter;
                mListStore.append(ti);  
                mListStore.setValue(ti, 0, relative);  
                mListStore.setValue(ti, 1, abs);
                mListStore.setValue(ti, 2, base);
                mListStore.setValue(ti, 3, mEditable);      
                Project.ListAppend(mListKey, relative);    //this is not right mLists should be private                
            }
        }
        fileDialog.close();
    }
    void AppendLibrary(string library)
    {

        string status = library ~ " not found";
        string[] paths;
        string bigString;
        string foundFiles = FindLibrary(library);
        
        auto ti = new TreeIter;
        mListStore.append(ti);
        mListStore.setValue(ti, 0, library);
        mListStore.setValue(ti, 1, library);
        mListStore.setValue(ti, 2, foundFiles);
        mListStore.setValue(ti, 3, mEditable);
        Project.ListAppend(mListKey, library);  
        mListView.setCursor(mListStore.getPath(ti), mListView.getColumn(0), true);
    }
    void RemoveSelectedItems()
    {
        string[] nuItems;
        auto ti = new TreeIter;
        mListStore.getIterFirst(ti);
        while(mListStore.iterIsValid(ti))
        {
            if(!mListView.getSelection.iterIsSelected(ti))
            {
                nuItems ~= mListStore.getValueString(ti, 0);
            }
            mListStore.iterNext(ti);
        }
        Project.ListSet(mListKey, nuItems);
        SetItems(nuItems);
    }
    void ClearItems()
    {
        mListStore.clear();
        Project.ListSet(mListKey, []);
    }   
}

enum LIST_TYPE
{
    FILE_RELATIVE,
    PATH_RELATIVE,
    FILE_ABSOLUTE,
    PATH_ABSOLUTE,
    IDENTIFIER,
}



/*
library should be a simple name eg dl or gtkd-3 vs libdl.so or libgtkd-3.so.3.9.0
will search in order
project library paths
LD_LIBRARY_PATHS
ld.so.conf paths
/usr/
/usr/lib/
*/

string[] FindLibraries(string library)
{
    string[] rv = [library ~ " not found on system"];
    
    return rv;
}
