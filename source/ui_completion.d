module ui_completion;

import std.container;
import std.conv;

import qore;
import ui;
import docman;
import document;
import text_objects;



class CALLTIP
{
    DOCUMENT    mDoc;
    string      mLocationMarkName;
    string[]    mCandidates;
    
    this(DOC_IF doc, string locationMark, string[] candidates)
    {
        mDoc = cast(DOCUMENT)doc;
        mLocationMarkName = locationMark;
        mDoc.getBuffer.createMark(mLocationMarkName, mDoc.Cursor, true);
        mCandidates = candidates;
    }
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
        mTipCol.setSizing(TreeViewColumnSizing.AUTOSIZE);
        mTipTree.appendColumn(mTipCol);
        
        mTipWindow.add(mTipScroll);
        mTipScroll.add(mTipTree);mComTree.setEnableSearch(false);
        mTipScroll.setPolicy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        mTipTree.setHeadersVisible(false);
        mTipTree.setCanFocus(false);
        mTipWindow.setCanFocus(false);
        mTipScroll.setCanFocus(false);
        mTipScroll.setVisible(true);
        mTipTree.setVisible(true);
        
        
        Log.Entry("Engaged");
    }
    void Mesh()
    {
        Transmit.DocKeyPress.connect(&WatchForKeyPress);
        Transmit.DocFocusChange.connect(&WatchForFocusChange);
        Log.Entry("Mesh");
    }
    void Disengage()
    {
        Transmit.DocFocusChange.disconnect(&WatchForFocusChange);
        Transmit.DocKeyPress.disconnect(&WatchForKeyPress);
        Log.Entry("Disengaged");
    }
    void PushCallTip(DOC_IF doc, string[] Candidates)
    {
        static int markID;        
        CALLTIP nu = new CALLTIP(doc, markID.to!string, Candidates);
        markID++;
        
        mTipStack.insertFront(nu);
        ShowCallTip();
    }
    void PopCallTips()
    {
        if(mTipStack.empty) return;
        mTipStack.removeFront();
        if(mTipStack.empty)
        {
            mTipWindow.setVisible(false);
            return;
        }
        ShowCallTip();
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
        
        if(ylen > maxWinY) ylen = maxWinY;
        mComWindow.resize(xlen, ylen);
        
        //position
        PositionWindow(mComWindow, Document, xlen, ylen);

        mTipWindow.setVisible(false);
        mComWindow.setVisible(true);
        mComScroll.setVisible(true);
        mComTree.setVisible(true);

        mComTree.setCursor(new TreePath("0"), null, false);
    }
    
  void ShowCallTip()
    {
        if(mTipStack.empty)return;
        
        DOCUMENT Document = cast(DOCUMENT)(mTipStack.front.mDoc);
        mTipWindow.setAttachedTo(Document);
        //load liststore
        mTipStore.clear();
        foreach (proposal; mTipStack.front.mCandidates)
        {
            TreeIter ti;
            mTipStore.append(ti);    
            mTipStore.setValue(ti, 0, proposal);
        }
        
        //size
        int xlen, ylen, xlencol1;
        int xoff, yoff;
        int maxWinY;
        mTipCol.cellGetSize(null, xoff, yoff, xlencol1, ylen);
        xlen = xlencol1;
        maxWinY = ylen * 8;
        ylen = ylen * cast(int)(mTipStack.front.mCandidates.length-1);
        mTipScroll.setMinContentWidth(xlen);
        
        if(ylen > maxWinY) ylen = maxWinY;
        mTipWindow.resize(xlen, ylen);
        
        //position
        PositionWindow(mTipWindow, Document, xlen, ylen, mTipStack.front.mLocationMarkName);

        mTipWindow.setVisible(true);
        mTipScroll.setVisible(true);
        mTipTree.setVisible(true);

        mTipTree.setCursor(new TreePath("0"), null, false);
        
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


    void PositionWindow(Window win, DOCUMENT doc, int xlen, int ylen , string markName = "insert")
    {
        int gXpos, gYpos;
        int gXlen, gYlen;
        
        doc.getWindow(TextWindowType.TEXT).getOrigin(gXpos, gYpos);
        gXlen = doc.getWindow(TextWindowType.TEXT).getWidth();
        gYlen = doc.getWindow(TextWindowType.TEXT).getHeight();
        dwrite(gXlen, ",<<<<<>>>>>");
        
        int cXpos, cYpos, cXlen, cYlen;
        GdkRectangle strong, weak;
        TextIter ti; 
        doc.buff.getIterAtMark(ti, doc.buff.getMark(markName));
        doc.getCursorLocations(ti, strong, weak);
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
        
        win.move(fXpos, fYpos);       
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
        uint keyVal;
        ModifierType modState;
        keyEvent.getKeyval(keyVal);
        keyEvent.getState(modState);
        
        if(doc.GetHasKeyEventBeenHandled) return;
        
        if(mComWindow.isVisible())
        {
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
                    ShowCallTip();
                    return;
                default:
                    mComWindow.setVisible(false);
                    ShowCallTip();
                    return;
            }
        }
        if(mTipWindow.isVisible())
        {
            switch(keyVal)
            {
                case Keysyms.GDK_Tab :
                    SelectionNext(mTipTree);
                    doc.SetKeyEventHasBeenHandled();
                    return;
                case Keysyms.GDK_ISO_Left_Tab:
                    SelectionPrev(mTipTree);
                    doc.SetKeyEventHasBeenHandled();
                    return;
                case Keysyms.GDK_Shift_L:
                case Keysyms.GDK_Shift_R:
                    return;
                case Keysyms.GDK_Return:
                case Keysyms.GDK_KP_Enter:
                    doc.SetKeyEventHasBeenHandled();
                    PopCallTips();
                    return;
                case Keysyms.GDK_parenright:
                    PopCallTips();
                    return;
                case Keysyms.GDK_Escape:
                    mTipStack.clear();
                    mTipWindow.setVisible(false);
                    return;
                default:
                    return;
            }
        }        
    }
    
    void WatchForFocusChange(DOC_IF doc, bool FocusIn)
    {
        mComWindow.setVisible(false);
        mTipStack.clear();
        mTipWindow.setVisible(false);
    }
            

}
