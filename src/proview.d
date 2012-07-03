//      proview.d
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


module proview;

import std.path;
import std.conv;
import std.stdio;
import core.memory;


import elements;
import ui;
import dcore;

import project;


import gtk.Builder;
import gtk.VBox;
import gtk.Label;
import gtk.TreeView;
import gtk.TreeIter;
import gtk.ComboBox;
import gtk.Toolbar;
import gtk.ListStore;
import gtk.TreePath;
import gtk.TreeViewColumn;
import gtk.ToolButton;
import gtk.FileChooserDialog;
import gtk.CellRendererText;
import gtk.Viewport;
import gtk.Frame;
import gtk.CheckButton;

import gobject.Value;

class PROJECT_VIEW : ELEMENT
{
    private:

    string          mName;
    string          mInfo;
    bool            mState;

    Builder         mBuilding;
    VBox            mRoot;

    Label           mLabel;
    Toolbar         mToolBar;
    ComboBox        mKeyBox;

    TreeView        mListView;
    CellRendererText mCellText;
    ListStore       mViewStore;
    ListStore       mComboStore;

    ToolButton      mAdd;
    ToolButton      mRemove;

    PROJECT_VIEW_PREF mPrefPage;
    bool			mEnabled;

    
    void UpdateList(ComboBox X)
    {
        GC.disable;
        
        TreeIter ti = new TreeIter;
        if (!X.getActiveIter(ti)) return;

        string key = mComboStore.getValueString(ti, 0);

        if( (key == VERSIONS ) || (key == DEBUGS)  || (key == "DESCRIPTION") || (key == "misc"))
        {
            mCellText.setProperty("mode", CellRendererMode.MODE_EDITABLE);
            mCellText.setProperty("editable",true);
        }
        else
        {
            mCellText.setProperty("editable", false);
            mCellText.setProperty("mode",CellRendererMode.MODE_ACTIVATABLE);
        }

        Value x = new Value(GType.INT);
        mCellText.getProperty("mode", x);
                        
        auto values = Project[key];



        mViewStore.clear();
        
        ti = new TreeIter;
        foreach(val; values)
        {
            mViewStore.append(ti);
            mViewStore.setValue(ti, 0, baseName(val));
            mViewStore.setValue(ti, 1, val);
            
        }
        GC.enable;
    }

    void UpdateList(string key, string[] Values)
    {
        version(all)
        {
        GC.disable;
        if( (key == VERSIONS ) || (key == DEBUGS) || (key == "DESCRIPTION") || (key == "misc") )
        {
            mCellText.setProperty("mode", CellRendererMode.MODE_EDITABLE);
            mCellText.setProperty("editable",true);
        }
        else
        {
            mCellText.setProperty("editable", false);
            mCellText.setProperty("mode",CellRendererMode.MODE_ACTIVATABLE);
        }

        Value x = new Value(GType.INT);
        mCellText.getProperty("mode", x);
                
        TreeIter ti = new TreeIter;
        if(mKeyBox.getActiveIter(ti))
        {
            string currentKey = mComboStore.getValueString(ti,0);
            if(key == currentKey)
            {
                mViewStore.clear();
                foreach(item; Values)
                {
                    mViewStore.append(ti);
                    mViewStore.setValue(ti, 0, baseName(item));
                    mViewStore.setValue(ti, 1, item);
                }
            }


        }
        GC.enable;
        }
        return;
    }

    void UpdateName(string nuName)
    {
        mLabel.setText(nuName);
    }

    void OpenFile(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        int CurKey = mKeyBox.getActive();

        if((CurKey == 0) || (CurKey == 1))
        {
            
            auto ti = tv.getSelectedIter();
            string Filename = ti.getValueString(1);
            dui.GetDocMan.Open(Filename);
        }
    }

    void UpdateProject(string EventType)
    {

        if(EventType == "ListChange")UpdateList(mKeyBox);
        if(EventType == "Name")mLabel.setText(Project.Name);
        if(EventType == "Opened")
        {
            UpdateList(mKeyBox);
            mLabel.setText(Project.Name);
            dui.GetSidePane.setCurrentPage(mRoot);
        }
        if(EventType == "Close")
        {
            UpdateList(mKeyBox);
            mLabel.setText("No Project Loaded");
        }
        if(EventType == "New")
        {
            dui.GetSidePane.setCurrentPage(mRoot);
        }
        
    }
    void AppendToolItems()
    {

        
        auto tmp = dui.Actions.getAction("ProNewAct"    );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.Actions.getAction("ProOpenAct"   );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.Actions.getAction("ProOptsAct"   );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.Actions.getAction("ProRefAct"    );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.Actions.getAction("ProBuildAct"  );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.Actions.getAction("ProRunAct"    );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.Actions.getAction("ProRunArgsAcg");
        mToolBar.insert(tmp.createToolItem());
    }

    void Add(ToolButton x)
    {
        Log.Entry("proview.Add");
        string CurrentKey;
        TreeIter ti = new TreeIter;
        if(mKeyBox.getActiveIter(ti))
        {
            CurrentKey = mComboStore.getValueString(ti,0);
        }
        else return;
        //yes yes I am aware that this is not an exactly "robust" way to handle the situation.
        switch (mKeyBox.getActive())
        {
            case 0 :
            case 1 :
            case 2 : AddAFile(CurrentKey); break;
            case 3 :
            case 4 :
            case 5 : AddAPath(CurrentKey); break;
            default : AddAIdentifier(CurrentKey);
            //case 6 :
            //case 7 : AddAIdentifier(CurrentKey); break;
            //default : return;
        }
        return;
    }

    void Remove(ToolButton x)
    {
        TreeIter ti = new TreeIter;
        string CurrentKey;

        if(mKeyBox.getActiveIter(ti))
        {
            CurrentKey = mComboStore.getValueString(ti,0);
        }
        else return;

        ti = mListView.getSelectedIter();
        
        Project.RemoveItem(CurrentKey, mViewStore.getValueString(ti,1));
        
        
    }


    void AddAFile(string CurrentKey)
    {
		auto FileDialog = new FileChooserDialog("Select Files", dui.GetWindow(), FileChooserAction.OPEN);
		FileDialog.setSelectMultiple(true);

		auto DialogResponse = FileDialog.run();
		FileDialog.hide();

		if(DialogResponse != ResponseType.GTK_RESPONSE_OK)return;

        string afile;
		TreeIter ti = new TreeIter;


		auto SelFiles = FileDialog.getFilenames();
		while(SelFiles !is null)
		{
            afile = toImpl!(string, char *)(cast(char *)SelFiles.data()); 
            Project.AddItem(CurrentKey, afile);
            //Project[CurrentKey] ~= afile;
            SelFiles = SelFiles.next();
		}

    }
    void AddAPath(string CurrentKey)
    {
   		auto FileDialog = new FileChooserDialog("Select Files", dui.GetWindow(), FileChooserAction.SELECT_FOLDER);
		FileDialog.setSelectMultiple(true);

		auto DialogResponse = FileDialog.run();
		FileDialog.hide();

		if(DialogResponse != ResponseType.GTK_RESPONSE_OK)return;

		string afile;
		TreeIter ti = new TreeIter;


		auto SelFiles = FileDialog.getFilenames();
		while(SelFiles !is null)
		{
			afile = toImpl!(string, char *)(cast(char *)SelFiles.data()); 
			Project.AddItem(CurrentKey, afile);
			SelFiles = SelFiles.next();
		}
		
    }
    void AddAIdentifier(string CurrentKey)
    {
        
        TreeIter ti = new TreeIter;
        mViewStore.append(ti);
        mViewStore.setValue(ti, 0, "NewValue");
        mViewStore.setValue(ti, 1, "NewValue");
           
    }

    void EditIdentifier(string Path, string text, CellRendererText crt)
    {

        TreeIter ti = new TreeIter;
        if(mKeyBox.getActiveIter(ti))
        {
            string CurrentKey = mComboStore.getValueString(ti,0);
            if(mKeyBox.getActive > 5) Project.AddItem(CurrentKey, text);
        }
    }

    void Configure()
    {
		mEnabled = Config.getBoolean("PROJECT_VIEW", "enabled", true);
		mRoot.setVisible(mEnabled);
	}
        
        

    
    public:

    this()
    {
        mName = "PROJECT_VIEW";
        mInfo = "A convenient view of the current project for the side panel";

        mPrefPage = new PROJECT_VIEW_PREF;
    }
    
    @property string Name(){return mName;}
    @property string Information(){return mInfo;}
    @property bool   State(){return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        (mState) ? Engage() : Disengage();
    }

    void Engage()
    {
        mBuilding = new Builder;
        mBuilding.addFromFile(Config.getString("PROJECT_VIEW", "glade_file", "$(HOME_DIR)/glade/proview.glade"));
        mRoot       = cast(VBox)        mBuilding.getObject("vbox1");
        mLabel      = cast(Label)       mBuilding.getObject("label2");
        mToolBar    = cast(Toolbar)     mBuilding.getObject("toolbar1");
        mListView   = cast(TreeView)    mBuilding.getObject("treeview1");
        mKeyBox     = cast(ComboBox)    mBuilding.getObject("combobox1");
        mViewStore  = cast(ListStore)   mBuilding.getObject("liststore2");
        mComboStore = cast(ListStore)   mBuilding.getObject("liststore1");
        mAdd        = cast(ToolButton)  mBuilding.getObject("toolbutton1");
        mRemove     = cast(ToolButton)  mBuilding.getObject("toolbutton2");
        mCellText   = cast(CellRendererText) mBuilding.getObject("cellrenderertext2");

        dui.GetSidePane.appendPage(mRoot, "Project");
        dui.GetSidePane.setTabReorderable ( mRoot, true); 

        mCellText.addOnEdited(&EditIdentifier);

        AppendToolItems();
        
        mKeyBox.addOnChanged(&UpdateList);
        
        mListView.addOnRowActivated(&OpenFile);

        mRemove.addOnClicked(&Remove); 
        mAdd.addOnClicked(&Add);
        Project.Event.connect(&UpdateProject);

        mKeyBox.setActive(0);
        UpdateList(mKeyBox);

        mRoot.showAll();
        mToolBar.setFocusChild(mRemove);

        Config.Reconfig.connect(&Configure);
        Configure();

        Log.Entry("Engaged PROJECT_VIEW element");
    }

    void Disengage()
    {
        Project.Event.disconnect(&UpdateProject);
        Config.Reconfig.disconnect(&Configure);
        Log.Entry("Disengaged PROJECT_VIEW element");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return mPrefPage;
    }
}
    
class PROJECT_VIEW_PREF : PREFERENCE_PAGE
{
	CheckButton		mEnabled;
	
	this()
	{
		super("Elements", Config.getString("PREFERENCES", "glade_file_project_view", "$(HOME_DIR)/glade/proviewpref.glade"));
		mEnabled = cast (CheckButton)mBuilder.getObject("checkbutton1");
		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setBoolean("PROJECT_VIEW", "enabled", mEnabled.getActive());
	}

	override void PrepGui()
	{
		mEnabled.setActive(Config.getBoolean("PROJECT_VIEW", "enabled", true));
	}
}
