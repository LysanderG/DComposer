module ui_list;

import ui;
import dcore;

import std.path;
import std.conv;
import std.algorithm;
import std.signals;

import gtk.Builder;
import gtk.Frame;
import gtk.Label;
import gtk.TreeView;
import gtk.CellRendererText;
import gtk.ListStore;
import gtk.TreeIter;
import gtk.Window;
import gtk.Button;
import gtk.Entry;
import gtk.FileChooserDialog;
import gtk.Widget;
import gtk.Main;
import gtk.TreeModelIF;

import gdk.Event;
import gdk.Keysyms;

enum ListType { FILES, PATHS, IDENTIFIERS};

class UI_LIST
{
    ListType    mType;

    string      mBasePath;


    Frame       mRoot;

    Label       mTitle;
    TreeView    mView;
    ListStore   mStore;
    CellRendererText mCell;
    Button      mAddBtn;
    Button      mRemoveBtn;
    Button      mClearBtn;

    Window      mItemDialog;
    Entry       mItemEntry;
    Button      mItemAdd;
    Button      mItemCancel;

    this(string Title, ListType Type)
    {

        auto builder = new Builder;
        builder.addFromFile( SystemPath( Config.GetValue("ui_list", "glade_file",  "glade/ui_list.glade")));

        mRoot   = cast(Frame)builder.getObject("uilist");

        mTitle  = cast(Label)builder.getObject("title");
        mView   = cast(TreeView)builder.getObject("treeview1");
        mStore  = cast(ListStore)builder.getObject("liststore1");
        mCell   = cast(CellRendererText)builder.getObject("cellrenderertext1");
        mAddBtn = cast(Button)builder.getObject("addButton");
        mRemoveBtn = cast(Button)builder.getObject("removeButton");
        mClearBtn = cast(Button)builder.getObject("clearButton");
        mItemDialog = cast(Window)builder.getObject("addItem");
        mItemEntry = cast(Entry)builder.getObject("item");
        mItemAdd = cast(Button)builder.getObject("addbutton");
        mItemCancel = cast(Button)builder.getObject("cancelbutton");

        mType = Type;
        mTitle.setText(Title);

        mBasePath = "/naziHell";

        mClearBtn.addOnClicked(delegate void(Button b){mStore.clear();emit(mTitle.getText(), GetItems());});
        mRemoveBtn.addOnClicked(delegate void(Button b){RemoveString();});
        mView.addOnKeyRelease(delegate bool(Event e, Widget w)
        {
            uint kv;
            if(e.getKeyval(kv))
            {
                if(kv == GdkKeysyms.GDK_Delete)
                {
                    RemoveString();
                    return true;
                }
                if(kv == GdkKeysyms.GDK_Return)
                {
                    if(mType == ListType.IDENTIFIERS) return false;
                    mAddBtn.clicked();
                    return true;
                }
            }
            return false;
        });
        mStore.addOnRowChanged(delegate void(TreePath tp, TreeIter ti, TreeModelIF tmif)
        {
            //if(tmif.getValueString(ti,0).length == 0)return;
            emit(mTitle.getText(), GetItems());
        });
        mStore.addOnRowDeleted(delegate void(TreePath tp, TreeModelIF tmif)
        {
            //if(tmif.getValueString(ti,0).length == 0)return;
            emit(mTitle.getText(), GetItems());
        });

        mCell.addOnEdited(delegate void (string path, string text, CellRendererText c)
        {
            auto ti = new TreeIter(mStore, path);
            mStore.setValue(ti, 0, text);
            mStore.setValue(ti, 1, text);
            emit(mTitle.getText(), GetItems());
        });


        final switch(mType)
        {
            case ListType.IDENTIFIERS :
            {
                mCell.setProperty("editable", true);
                mAddBtn.addOnClicked(delegate void(Button b){AddIdentifier();});

                mItemAdd.addOnClicked(delegate void(Button b){mItemDialog.hide();auto nuString = mItemEntry.getText();if(nuString.length > 0)AddString(nuString);});
                mItemCancel.addOnClicked(delegate void(Button b){mItemEntry.setText("");mItemDialog.hide();});

                mItemDialog.setTransientFor(ui.MainWindow);
                mItemDialog.setModal(true);
                mItemDialog.setPosition(WindowPosition.MOUSE);
                break;
            }
            case ListType.FILES :
            {
                mCell.setProperty("editable", false);
                mAddBtn.addOnClicked(delegate void(Button b){AddFiles();});
                break;
            }
            case ListType.PATHS :
            {
                mCell.setProperty("editable", false);
                mAddBtn.addOnClicked(delegate void(Button b){AddPaths();});
                break;
            }
        }
        mRoot.unparent();
    }

    string GetTitle()
    {
        return mTitle.getText();
    }

    ListType GetType()
    {
        return mType;
    }

    string[] GetItems()
    {
        string[] rv;

        TreeIter ti = new TreeIter;

        if(mStore.getIterFirst(ti))
        {
            rv ~= mStore.getValueString(ti, 1);
            while(mStore.iterNext(ti)) rv ~= mStore.getValueString(ti, 1);
        }
        return rv.dup;
    }

    void SetItems(string[] items)
    {
        mStore.clear();
        foreach(i; items)AddString(i);
        emit(mTitle.getText(), GetItems());
    }


    void AddString(string nuString)
    {
        TreeIter ti = new TreeIter;
        mStore.append(ti);
        mStore.setValue(ti, 0, baseName(nuString));
        mStore.setValue(ti, 1, nuString);
        emit(mTitle.getText(), GetItems());
    }

    void RemoveString()
    {
        TreeIter ti = new TreeIter;
        auto viewselection = mView.getSelection();
        TreeModelIF tmif;
        viewselection.getSelected(tmif, ti);

        if(ti)mStore.remove(ti);
        emit(mTitle.getText(), GetItems());
    }

    void AddIdentifier()
    {
        mItemEntry.setText("\0");
        mItemDialog.present();
        mItemEntry.grabFocus();

        emit(mTitle.getText(), GetItems());
    }

    void AddFiles()
    {
        auto filechooser = new FileChooserDialog("Choose Files",MainWindow, FileChooserAction.OPEN);
        filechooser.setSelectMultiple(true);
        auto rv = filechooser.run();
        filechooser.hide();
        if(rv != ResponseType.OK) return;

        auto ChosenFiles = filechooser.getFilenames();
        while(ChosenFiles !is null)
        {
            string afile = toImpl!(string, char *)(cast(char *)ChosenFiles.data());
            //don't add duplicates
            if(!GetItems.canFind(afile))
            {
                auto afileAbsPath = afile.absolutePath();
                //auto projectAbsPath = Project.Folder.absolutePath(); //assume project folder is a normalized path ( no . .. or ~)
                if(afileAbsPath.startsWith(mBasePath))afile = afile.relativePath(mBasePath);
                else afile = afileAbsPath.buildNormalizedPath();
                AddString(afile);
            }
            ChosenFiles = ChosenFiles.next();
        }
    }

    void AddPaths()
    {
        auto pathchooser = new FileChooserDialog("Choose Paths",MainWindow, FileChooserAction.SELECT_FOLDER);
        pathchooser.setSelectMultiple(true);
        auto rv = pathchooser.run();
        pathchooser.hide();
        if(rv != ResponseType.OK) return;

        auto chosenpaths = pathchooser.getFilenames();

        while(chosenpaths !is null)
        {
            string apath = toImpl!(string, char *)(cast(char *)chosenpaths.data());
            if(!GetItems.canFind(apath))
            {
                auto apathAbsPath = apath.absolutePath();

                if(apathAbsPath.startsWith(mBasePath))apath = apath.relativePath(mBasePath);
                else apath = apathAbsPath.buildNormalizedPath();
                AddString(apath);
            }
            chosenpaths = chosenpaths.next();
        }
    }

    Widget GetRootWidget()
    {
        return cast(Widget)mRoot;
    }

    mixin Signal!(string, string[]);

    void WatchProj(PROJECT_EVENT event)
    {
        scope(failure) return;
        UpdateItems(Project.Lists[GetTitle()]);
    }

    void UpdateItems(string[] items)
    {
        if(items == GetItems) return;
        mStore.clear();
        if(items.length < 1) return;
        foreach(i; items)UpdateString(i);

    }


    void UpdateString(string nuString)
    {
        TreeIter ti = new TreeIter;
        mStore.append(ti);
        mStore.setValue(ti, 0, baseName(nuString));
        mStore.setValue(ti, 1, nuString);
    }

    void SetRootPath(string NuBasePath)
    {
        mBasePath = NuBasePath;
    }

}

