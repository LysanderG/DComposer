module ui_completion;

import std.container;

import qore;
import ui;
import docman;
import document;
import text_objects;



struct CALLTIP
{
    string      mLocationMarkName;
    string[]    mCandidates;
}


void EngageCompletion()
{
    
    EngageTextObjects();
    uiCompletion = new UI_COMPLETION;   
    uiCompletion.Engage();
}
void MeshCompletion()
{
    MeshTextObjects();
    uiCompletion.Mesh();
}
void DisengageCompletion()
{
    uiCompletion.Disengage();
    DisengageTextObjects();
}

class UI_COMPLETION
{
    public:
    
    void Engage()
    {
        mComWindow = new Window(GtkWindowType.TOPLEVEL);
        mComWindow.setDecorated(false);
        mComScroll = new ScrolledWindow();
        mComStore = new ListStore([GType.STRING, GType.STRING]);
        mComTree = new TreeView(mComStore);
        mComTreeCol1 = new TreeViewColumn("Candidate", new CellRendererText(), "text", 0);
        mComTreeCol2 = new TreeViewColumn("Type", new CellRendererText(), "text", 1);
        mComTreeCol1.setSizing(TreeViewColumnSizing.AUTOSIZE);
        mComTreeCol2.setSizing(TreeViewColumnSizing.AUTOSIZE);
        
        mComWindow.add(mComScroll);
        mComScroll.add(mComTree);
        mComTree.setEnableSearch(false);
        mComTree.appendColumn(mComTreeCol1);
        mComTree.appendColumn(mComTreeCol2);
        mComScroll.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        mComTree.setHeadersVisible(false);
        mComTree.setCanFocus(true);
        mComWindow.setCanFocus(true);
        dwrite(mComWindow.getCanFocus());
        
        
        mTipWindow = new Window(GtkWindowType.TOPLEVEL);
        mTipWindow.setDecorated(false);
        mTipScroll = new ScrolledWindow();
        mTipStore = new ListStore([GType.STRING]);
        mTipTree = new TreeView(mTipStore);
        mTipCol = new TreeViewColumn("Tip", new CellRendererText(), "text", 0);
        mTipTree.appendColumn(mTipCol);
        
        Log.Entry("Engaged");
    }
    void Mesh()
    {
        mComTree.addOnKeyPress(delegate bool(Event evK, Widget wd)
        {
            DOCUMENT Doc = cast(DOCUMENT)GetCurrentDoc();
            uint keyVal;
            evK.getKeyval(keyVal);
            switch (keyVal)
            {
                case Keysyms.GDK_Tab:
                {
                    SelectionNext(mComTree);

                    break;
                }
                case Keysyms.GDK_ISO_Left_Tab:
                {
                    SelectionPrev(mComTree);
                    break;
                }
                case Keysyms.GDK_Return:
                {
                    CompleteSymbol();
                    break;
                }
                default:
                {
                    mComWindow.hide();
                    return Doc.event(evK);
                }
            }
            return true;
        });
        mComTree.addOnFocusOut(delegate bool(Event e, Widget w)
        {
            mComWindow.hide();
            return true;
        });
        mComWindow.addOnShow(delegate void(Widget w)
        {
            mComTree.grabFocus();
        });
        mComWindow.addOnHide(delegate void(Widget w)
        {
            Widget attached = mComWindow.getAttachedTo();
        });
        
        Log.Entry("Mesh");
    }
    void Disengage()
    {
        Log.Entry("Disengaged");
    }
    
    void ShowCompletion(DOC_IF doc, string[] Candidates, string[] info)
    {
        DOCUMENT Document = cast(DOCUMENT)doc;
        mComWindow.setAttachedTo(Document);
        mComWindow.hide();
        //load liststore
        mComStore.clear();
        foreach (ndx, proposal; Candidates)
        {
            TreeIter ti;
            mComStore.append(ti);    
            mComStore.setValue(ti, 0, proposal);
            mComStore.setValue(ti, 1, info[ndx]);
        }
        
        //size
        int xlen, ylen, xlencol1, xlencol2;
        int xoff, yoff;
        mComTreeCol1.cellGetSize(null, xoff, yoff, xlencol1, ylen);
        mComTreeCol2.cellGetSize(null, xoff, yoff, xlencol2, ylen);
        xlen = xlencol1 + xlencol2;
        ylen = ylen * cast(int)Candidates.length;
        mComScroll.setMinContentWidth(xlen);
        mComWindow.resize(xlen, ylen);
        
        //position
        GdkRectangle strong, weak;
        Document.getCursorLocations(null, strong, weak);
        int xpos, ypos;
        Document.bufferToWindowCoords(TextWindowType.TEXT, strong.x, strong.y, xpos, ypos);        
        ypos += strong.height;
        Document.getWindow(TextWindowType.TEXT).getOrigin(xoff, yoff);
        xpos += xoff;
        ypos += yoff;
        mComWindow.move(xpos,ypos);
        
        
        mComWindow.setSkipTaskbarHint(true);
        mComWindow.setSkipPagerHint(true);
        mComWindow.realize();
        mComWindow.showAll();
    }
    private:
    //completion stuffs
    Window          mComWindow;
    ScrolledWindow  mComScroll;
    TreeView        mComTree;
    ListStore       mComStore;
    TreeViewColumn  mComTreeCol1;
    TreeViewColumn  mComTreeCol2;
    
    //tip stuffs
    Window          mTipWindow;
    ScrolledWindow  mTipScroll;
    TreeView        mTipTree;
    ListStore       mTipStore;
    TreeViewColumn  mTipCol;
    SList!CALLTIP   mTipStack;
    
    void SelectionNext(TreeView tv)
    {
        TreeModelIF tmi = tv.getModel();
        TreeIter ti = tv.getSelectedIter();
        if(ti is null) return;
        if(!tmi.iterNext(ti))
            tmi.getIter(ti, new TreePath(true));
        tv.getSelection().selectIter(ti);
        tv.scrollToCell(ti.getTreePath(), null, false, 0, 0);       
    }
    void SelectionPrev(TreeView tv)
    {
        TreeModelIF tmi = tv.getModel();
        TreeIter ti = tv.getSelectedIter();
        
        if(ti is null)return;
        if(!tmi.iterPrevious(ti))
        {
            SelectionEnd(tv);
            return;
        }
        tv.getSelection().selectIter(ti);
        tv.scrollToCell(ti.getTreePath(), null, false, 0,0);
    }
    void SelectionEnd(TreeView tv)
    {
        TreeIter last = tv.getSelectedIter();
        TreeIter ti = tv.getSelectedIter();
        TreeModelIF tmi = tv.getModel();
        
        if(ti is null) return;
        while(tmi.iterNext(ti))tmi.iterNext(last);
        tv.getSelection.selectIter(last);
        tv.scrollToCell(last.getTreePath(), null, false, 0,0);
    }
    
    void CompleteSymbol()
    {
        DOC_IF Doc = GetCurrentDoc();
        if(Doc is null) return;
        TreeIter ti = mComTree.getSelectedIter();
        string chosenCandidate = mComStore.getValueString(ti, 0);
        
        
        Doc.CompleteSymbol(chosenCandidate);
    }
    
    
}
