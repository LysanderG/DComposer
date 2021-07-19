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
        mComWindow = new Window(GtkWindowType.POPUP);
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
        mComTree.setCanFocus(false);
        mComWindow.setCanFocus(false);
        mComScroll.setCanFocus(false);
        mComScroll.setVisible(true);
        mComTree.setVisible(true);
        
        
        mTipWindow = new Window(GtkWindowType.POPUP);
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
        Transmit.DocKeyPress.connect(&WatchForKeyPress);
        Log.Entry("Mesh");
    }
    void Disengage()
    {
        Transmit.DocKeyPress.disconnect(&WatchForKeyPress);
        Log.Entry("Disengaged");
    }
    
    void ShowCompletion(DOC_IF doc, string[] Candidates, string[] info)
    {
        DOCUMENT Document = cast(DOCUMENT)doc;
        mComWindow.setAttachedTo(Document);
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
        int maxWinY;
        mComTreeCol1.cellGetSize(null, xoff, yoff, xlencol1, ylen);
        mComTreeCol2.cellGetSize(null, xoff, yoff, xlencol2, ylen);
        xlen = xlencol1 + xlencol2;
        maxWinY = ylen * 8;
        ylen = ylen * cast(int)Candidates.length;
        mComScroll.setMinContentWidth(xlen);
        //mComScroll.setMinContentHeight(ylen * 6);
        //mComScroll.setMaxContentHeight(ylen * 8);
        
        if(ylen > maxWinY) ylen = maxWinY;
        mComWindow.resize(xlen, ylen);
        
        //position
        PositionWindow(mComWindow, Document, xlen, ylen);
        //GdkRectangle strong, weak;
        //Document.getCursorLocations(null, strong, weak);
        //int xpos, ypos;
        //Document.bufferToWindowCoords(TextWindowType.TEXT, strong.x, strong.y, xpos, ypos);        
        //ypos += strong.height;
        //Document.getWindow(TextWindowType.TEXT).getOrigin(xoff, yoff);
        //xpos += xoff;
        //ypos += yoff;
        //mComWindow.move(xpos,ypos);

        mComWindow.setVisible(true);
        mComScroll.setVisible(true);
        mComTree.setVisible(true);

        mComTree.setCursor(new TreePath("0"), null, false); 

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


    void PositionWindow(Window win, DOCUMENT doc, int xlen, int ylen)
    {
        int gXpos, gYpos;
        int gXlen, gYlen;
        
        doc.getWindow(TextWindowType.TEXT).getOrigin(gXpos, gYpos);
        gXlen = doc.getWindow(TextWindowType.TEXT).getWidth();
        gYlen = doc.getWindow(TextWindowType.TEXT).getHeight();
        dwrite(gXlen, ",<<<<<>>>>>");
        
        int cXpos, cYpos, cXlen, cYlen;
        GdkRectangle strong, weak;
        doc.getCursorLocations(null, strong, weak);
        doc.bufferToWindowCoords(TextWindowType.TEXT, strong.x, strong.y, cXpos, cYpos);        
        cYpos += strong.height;
        cXpos += gXpos;
        cYpos += gYpos;
        
        //x
        int fXpos = cXpos;
        while(fXpos + xlen > gXpos + gXlen + strong.width) fXpos--;
        //y
        int fYpos = cYpos;
        if(fYpos + ylen > gYpos + gYlen)
        {
            fYpos = fYpos - strong.height - ylen;
        }
        
        mComWindow.move(fXpos, fYpos);       
    }

    
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
    
    void WatchForKeyPress(DOC_IF doc, Event keyEvent)
    {
        
        if(!mComWindow.isVisible())return;
        dwrite("uicomplete got key press");
        if(doc.GetHasKeyEventBeenHandled) return;
        uint keyVal;
        ModifierType modState;
        keyEvent.getKeyval(keyVal);
        keyEvent.getState(modState);
        
        switch(keyVal)
        {
            case Keysyms.GDK_Tab :
                SelectionNext(mComTree);
                doc.SetKeyEventHasBeenHandled();
                return;
            case Keysyms.GDK_ISO_Left_Tab:
                SelectionPrev(mComTree);
                doc.SetKeyEventHasBeenHandled();
                return;
            case Keysyms.GDK_Shift_L:
            case Keysyms.GDK_Shift_R:
                return;
            case Keysyms.GDK_Return:
            case Keysyms.GDK_KP_Enter:
                CompleteSymbol();
                doc.SetKeyEventHasBeenHandled();
                mComWindow.setVisible(false);
                return;
            default:
                mComWindow.setVisible(false);
                return;
        }
    }
            

}
