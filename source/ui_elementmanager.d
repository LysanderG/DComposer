module ui_elementmanager;

import std.conv;
import std.format;

import qore;
import ui;
import elements;


void EngageElementManager()
{
    mListener = new LISTENER;
    Transmit.PreferencesUpdateUI.connect(&mListener.LoadStore);
    mBuilder = new Builder(Config.GetResource("ui_elementmanager", "glade", "glade", "ui_elementmanager.glade"));
    mRootBox = cast(Box)mBuilder.getObject("rootbox");
    mTree = cast(TreeView)mBuilder.getObject("elem_tree");
    mStore = cast(ListStore)mBuilder.getObject("liststore1");
    mScroll = cast(ScrolledWindow)mBuilder.getObject("scroll_label");
    mEnableToggle = cast(CellRendererToggle)mBuilder.getObject("enable_toggle");
    mBrokentoggle = cast(CellRendererToggle)mBuilder.getObject("broken_toggle");
    mBrokenNotice = cast(ScrolledWindow)mBuilder.getObject("broken_notice");
    mInfoLabel = cast(Label)mBuilder.getObject("info_label");
    mSettingsButton = cast(Button)mBuilder.getObject("settings_button");
    
    //dwrite (mBuilder, "/", mRootBox,"/",mTree, "/", mStore);
    
    mTree.getSelection.addOnChanged(delegate void(TreeSelection ts)
    {
        TreeIter ti = ts.getSelected();
        if(ti is null)
        {
            mBrokenNotice.setVisible(false);
            mSettingsButton.setSensitive(false);
            mInfoLabel.setText("No element selected");
            return;
        }

        Value BrokenValue = mStore.getValue(ti, 3, null);

        mBrokenNotice.setVisible(BrokenValue.getBoolean());
        mInfoLabel.setMarkup(GetInfoString(ti));
        bool active;  // this should be part of registeredLibrary
        string currentLibraryID = mStore.getValueString(ti, 0); 
        if(GetRegisterdElements[currentLibraryID].mPtr !is null) active = true;
        mSettingsButton.setSensitive(active);
    });
    
    mEnableToggle.addOnToggled(delegate void(string path, CellRendererToggle crt)
    {
        TreeIter ti = new TreeIter(mStore, path); 
        Value bval = new Value;
        
        mStore.getValue(ti, 2, bval);  
        bool nuState = !bval.getBoolean;
        //dwrite(nuState);
          
        string key = mStore.getValueString(ti, 0); 
        
        if(nuState) EnableElement(key);
        else DisableElement(key);
        //dwrite(">>", GetRegisterdElements[key].mEnabled);
        mListener.LoadStore();
        
    });
    mBrokentoggle.addOnToggled(delegate void(string path, CellRendererToggle crt)
    {
        TreeIter ti = new TreeIter(mStore, path); 
        Value bval = new Value;
        
        bval.init(GType.BOOLEAN);
        mStore.getValue(ti, 3, bval);  
        bool nuState = !bval.getBoolean;
          
        string key = mStore.getValueString(ti, 0); 
        
        if(nuState) BreakElement(key);
        else UnbreakElement(key);
        
        mListener.LoadStore();
    });
    
    mSettingsButton.addOnClicked(delegate void(Button)
    {
        TreeIter ti = mTree.getSelectedIter();
        assert(mStore.iterIsValid(ti));
        string id = mStore.getValueString(ti, 0);
        //dwrite(" button id >",id);
        ShowSettingDialog(id);        
    });
    
    Log.Entry("Engaged");
}

void MeshElementManager()
{
    AppPreferenceAddWidget("Elements", mRootBox);
    Log.Entry("Meshed");
}

void DisengageElementManager()
{
    Transmit.PreferencesUpdateUI.disconnect(&mListener.LoadStore);
    Log.Entry("Disengaged");
}

void ElementManagerPreferences()
{
    
}

Builder             mBuilder;
Box                 mRootBox;
TreeView            mTree;
ListStore           mStore;
ScrolledWindow      mScroll;
CellRendererToggle  mEnableToggle;
CellRendererToggle  mBrokentoggle;
ScrolledWindow      mBrokenNotice;
Label               mInfoLabel;
Button              mSettingsButton;

LISTENER mListener;
class LISTENER
{
   void LoadStore()
    {
        mStore.clear();
        TreeIter ti;
        foreach (element; GetRegisterdElements())
        {
            //dwrite(element);
            mStore.append(ti);
            mStore.setValue(ti, 0, element.mID);
            mStore.setValue(ti, 1, element.mInfo);
            mStore.setValue(ti, 2, element.mEnabled);
            mStore.setValue(ti, 3, element.mBroken);
            mStore.setValue(ti, 4, element.mVersion);
            mStore.setValue(ti, 5, element.mSuppressed);
            mStore.setValue(ti, 6, element.mFile);
            mStore.setValue(ti, 7, element.mAuthors);
        } 
    }    
}

string GetInfoString(TreeIter ti)
{
    string fmt = format("NAME       :%s\nAUTHORS    :%s\nCOPYRIGHT  :%s\nLICENSE    :%s\nVERSION    :%s\nDESCRIPTION:%s",
        mStore.getValueString(ti, 0),
        mStore.getValueString(ti, 7),
        "Copyright",
        "license",
        mStore.getValueString(ti, 4),
        mStore.getValueString(ti, 1)); 
        return fmt;
}
