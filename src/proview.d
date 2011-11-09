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

import elements;
import ui;
import dcore;

import dproject;


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

    
    void UpdateList(ComboBox X)
    {
        TreeIter ti = new TreeIter;
        X.getActiveIter(ti);

        string key = mComboStore.getValueString(ti, 0);
        auto values = GetProject.Get(key);

        if( (key == VERSIONS ) || (key == DEBUGS)) mCellText.setProperty("mode", CellRendererMode.MODE_EDITABLE);
        else mCellText.setProperty("mode",CellRendererMode.MODE_ACTIVATABLE);

        mViewStore.clear();
        
        ti = new TreeIter;
        foreach(val; values)
        {
            mViewStore.append(ti);
            mViewStore.setValue(ti, 0, baseName(val));
            mViewStore.setValue(ti, 1, val);
            
        }
    }

    void UpdateList(string key, string[] Values)
    {
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
            if( (key == VERSIONS ) || (key == DEBUGS)) mCellText.setProperty("mode", CellRendererMode.MODE_EDITABLE);
            else mCellText.setProperty("mode",CellRendererMode.MODE_ACTIVATABLE);

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
            dui.GetDocMan.OpenDoc(Filename);
        }
    }  

    void AppendToolItems()
    {

        
        auto tmp = dui.GetActions.getAction("ProNewAct"    );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.GetActions.getAction("ProOpenAct"   );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.GetActions.getAction("ProOptsAct"   );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.GetActions.getAction("ProRefAct"    );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.GetActions.getAction("ProBuildAct"  );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.GetActions.getAction("ProRunAct"    );
        mToolBar.insert(tmp.createToolItem());
        tmp = dui.GetActions.getAction("ProRunArgsAcg");
        mToolBar.insert(tmp.createToolItem());
    }

    void Add(ToolButton x)
    {
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
            case 6 :
            case 7 : AddAIdentifier(CurrentKey); break;
            default : return;
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
        
        GetProject.Remove(CurrentKey, mViewStore.getValueString(ti,1));
        
        
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
            GetProject.Add(CurrentKey, afile);
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
			GetProject.Add(CurrentKey, afile);
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
            GetProject.Add(CurrentKey, text);
        }
    }
        
        

    
    public:

    this()
    {
        mName = "PROJECT_VIEW";
        mInfo = "A convienant view of the current project for the side panel";
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
        mBuilding.addFromFile(GetConfig.getString("PROJECT_VIEW", "glade_file", "/home/anthony/.neontotem/dcomposer/proview.glade"));

        mRoot       = cast(VBox)        mBuilding.getObject("vbox1");
        mLabel      = cast(Label)       mBuilding.getObject("label1");
        mToolBar    = cast(Toolbar)     mBuilding.getObject("toolbar1");
        mListView   = cast(TreeView)    mBuilding.getObject("treeview1");
        mKeyBox     = cast(ComboBox)    mBuilding.getObject("combobox1");
        mViewStore  = cast(ListStore)   mBuilding.getObject("liststore2");
        mComboStore = cast(ListStore)   mBuilding.getObject("liststore1");
        mAdd        = cast(ToolButton)  mBuilding.getObject("toolbutton1");
        mRemove     = cast(ToolButton)  mBuilding.getObject("toolbutton2");
        mCellText   = cast(CellRendererText) mBuilding.getObject("cellrenderertext2");


        mAdd.addOnClicked(&Add);
        mRemove.addOnClicked(&Remove);    

        mCellText.addOnEdited(&EditIdentifier);

        AppendToolItems();

        mKeyBox.addOnChanged(&UpdateList);
        mListView.addOnRowActivated(&OpenFile);
        
        GetProject.ListChanged.connect(&UpdateList);
        GetProject.NameChanged.connect(&UpdateName);

        mRoot.showAll();

        dui.GetSidePane.appendPage(mRoot, "Project");

        GetLog.Entry("Engaged PROJECT_VIEW element");
    }

    void Disengage()
    {
        GetLog.Entry("Disengaged PROJECT_VIEW element");
    }
}
    


