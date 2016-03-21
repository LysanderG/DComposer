module ui_completion;

import std.container;
import std.string;
import std.datetime;
import std.algorithm.searching;

import dcore;
import ui;
import docman;
import document;




struct CALLTIP
{
    string      mLocationName;
    string[]    mCandidates;
}





class UI_COMPLETION
{
    private :

    Window              mCompWindow;
    ScrolledWindow      mCompScroll;
    TreeView            mCompTree;
    ListStore           mCompStore;
    TreeViewColumn      mCompCol1;
    TreeViewColumn      mCompCol2;
    SysTime             mCompWinLastShownTime;
    int mCompRows;



    Window          mTipWindow;
    ScrolledWindow  mTipScroll;
    TreeView        mTipTree;
    ListStore       mTipStore;
    TreeViewColumn  mTipCol;

    SList!(CALLTIP) mAnchor;



    void MapCallTipWindow()
    {

        //size
        int xoff, yoff, xlen, ylen;
        mTipCol.cellGetSize(null, xoff, yoff, xlen, ylen);
        ylen = cast(int)mAnchor.opSlice().front.mCandidates.length * ylen;
        mTipWindow.resize(xlen, ylen );

        //location
        auto doc = DocMan.Current();
        RECTANGLE Crect = doc.GetMarkRectangle(mAnchor.front.mLocationName);
        mTipWindow.move(Crect.x, Crect.y + Crect.yl);
    }



    void MapCompletionWindow()
    {

        //size
        int rows = mCompRows;
        if(rows > 8)rows = 8;
        int xoff, yoff, cellwidth, cellheight;
        int xoff2, yoff2, cellwidth2, cellheight2;
        mCompCol1.cellGetSize(null, xoff, yoff, cellwidth, cellheight);
        mCompCol2.cellGetSize(null, xoff2, yoff2, cellwidth2, cellheight2);
        mCompWindow.resize(cellwidth + cellwidth2 + 4, rows * cellheight);


        //position
        DOCUMENT doc = cast(DOCUMENT)DocMan.Current;
        RECTANGLE Crect = doc.GetCursorRectangle();
        mCompWindow.move(Crect.x, Crect.y + Crect.yl);
        mCompWinLastShownTime = Clock.currTime();
    }

    void WatchForLostFocus(DOC_IF doc)
    {
        KillCallTips();
        KillCompletionWindow();
    }


    void WatchForKeys(uint key, uint state)
    {
        if(mCompWindow.isVisible)ProcessCompletionKey(key);
        else if(mTipWindow.isVisible)ProcessCallTipKey(key);
    }

    void WatchForMouseButton(void * Event, DOC_IF doc)
    {
        KillCallTips();
        KillCompletionWindow();
    }

    void ProcessCallTipKey(uint key)
    {

        GdkKeysyms keysym = cast(GdkKeysyms)key;
        switch(keysym) with (GdkKeysyms)
        {
            //case    GDK_BackSpace   :
            //case    GDK_Delete      :
            case    GDK_Escape      :
            //case    GDK_Return      :
            //case    GDK_KP_Enter    :
            {
                DocMan.SetBlockDocumentKeyPress();
                PopCallTip();
                return;
            }
            case    GDK_KP_Down     :
            case    GDK_Down        :
            case    GDK_Tab         :
            {
                DocMan.SetBlockDocumentKeyPress();
                CallTipSelectionDown();
                return;
            }
            case    GDK_KP_Up       :
            case    GDK_Up          :
            case    GDK_ISO_Left_Tab:
            {
                DocMan.SetBlockDocumentKeyPress();
                CallTipSelectionUp();
                return;
            }
            case    GDK_Home        :
            {
                DocMan.SetBlockDocumentKeyPress();
                CallTipSelectionHome();
                return;
            }
            case    GDK_End         :
            {
                DocMan.SetBlockDocumentKeyPress();
                CallTipSelectionEnd();
                return;
            }
            case    GDK_Shift_R     :
            case    GDK_Shift_L     :
            {
               // DocMan.SetBlockDocumentKeyPress(false);
                return;
            }
            
            case    GDK_parenright  :
            {
                dwrite(")");
                auto doc = cast(DOCUMENT)DocMan.Current();
                auto buff = doc.getBuffer();
                auto tiStart = new TextIter;
                auto markStart = buff.getMark(mAnchor.front.mLocationName);
                buff.getIterAtMark(tiStart, markStart);
                
                string tipstring = buff.getText(tiStart, doc.Cursor(), false);
                if(tipstring.balancedParens('(', ')')) 
                {
                    PopCallTip();
                    return;
                }
            }
            default                 :
            {
                return;
            }
        }
    }



    void ShowCallTip()
    {
        mTipWindow.hide();

        if(mAnchor.empty())return;

        auto doc = cast(DOCUMENT)DocMan.Current();
        auto buf = doc.getBuffer();

        mTipStore.clear();
        auto treeIter = new TreeIter;
        foreach(candi; mAnchor.front.mCandidates)
        {
            mTipStore.append(treeIter);
            mTipStore.setValue(treeIter, 0, candi);
        }
        mTipWindow.showAll();
        MapCallTipWindow();
    }

    void CallTipSelectionDown()
    {
        TreeIter ti = mTipTree.getSelectedIter();
        if(ti is null) return;
        //if(!mTipStore.iterNext(ti))mTipStore.getIterFirst(ti); getIterFirst fails!!
        //if(!mTipStore.iterNext(ti))mTipStore.getIterFirst(ti); 
        if(!mTipStore.iterNext(ti)) mTipStore.getIter(ti, new TreePath("0"));
        
        mTipTree.getSelection().selectIter(ti);
        mTipTree.scrollToCell(ti.getTreePath(), null, false, 0, 0);
    }

    void CallTipSelectionEnd()
    {
        TreeIter last = mTipTree.getSelectedIter();
        TreeIter ti = mTipTree.getSelectedIter();
        if(ti is null)return;
        while(mTipStore.iterNext(ti)) mTipStore.iterNext(last);
        mTipTree.getSelection().selectIter(last);
        mTipTree.scrollToCell(last.getTreePath(),null, false, 0, 0);
    }

    void CallTipSelectionUp()
    {
        TreeIter ti = mTipTree.getSelectedIter();
        if(ti is null) return;
        if(!mTipStore.iterPrevious(ti))
        {
            CallTipSelectionEnd();
            return;
        }
        mTipTree.getSelection().selectIter(ti);
        mTipTree.scrollToCell(ti.getTreePath(), null, false, 0, 0);
    }

    void CallTipSelectionHome()
    {
        TreeIter ti = new TreeIter;
        mTipStore.getIterFirst(ti);
        mTipTree.getSelection().selectIter(ti);
        mTipTree.scrollToCell(ti.getTreePath(), null, false, 0, 0);
    }

    void ProcessCompletionKey(uint key)
    {
        DocMan.SetBlockDocumentKeyPress(false);
        GdkKeysyms keysym = cast(GdkKeysyms)key;
        switch(keysym) with (GdkKeysyms)
        {
            case    GDK_BackSpace   :
            case    GDK_Delete      :
            case    GDK_Escape      :
            {
                DocMan.SetBlockDocumentKeyPress();
                KillCompletionWindow();
                return;
            }
            case    GDK_Return      :
            case    GDK_KP_Enter    :
            {
                DocMan.SetBlockDocumentKeyPress();
                CompleteSymbol();
                KillCompletionWindow();
                return;
            }
            case    GDK_KP_Down     :
            case    GDK_Down        :
            case    GDK_Tab         :
            {
                DocMan.SetBlockDocumentKeyPress();
                CompletionSelectionDown();
                return;
            }
            case    GDK_KP_Up       :
            case    GDK_Up          :
            case    GDK_ISO_Left_Tab:
            {
                DocMan.SetBlockDocumentKeyPress();
                CompletionSelectionUp();
                return;
            }
            case    GDK_Home        :
            {
                DocMan.SetBlockDocumentKeyPress();
                CompletionSelectionHome();
                return;
            }
            case    GDK_End         :
            {
                DocMan.SetBlockDocumentKeyPress();
                CompletionSelectionEnd();
                return;
            }
            case    GDK_Shift_R     :
            case    GDK_Shift_L     :
            {
                return;
            }

            default                 :
            {
                KillCompletionWindow();
                return;
            }
        }
    }

    void KillCompletionWindow()
    {
        mCompWindow.hide();
        ShowCallTip();
    }

    void KillCallTips()
    {
        if(!mAnchor.empty())mAnchor.clear();
        mTipWindow.hide();
    }

    void CompleteSymbol()
    {
        TreeIter ti = mCompTree.getSelectedIter();
        if(ti !is null)
        {
            string selCandidate = mCompStore.getValueString(ti, 0);
            DocMan.Current.CompleteSymbol(selCandidate);
        }
    }

    void CompletionSelectionDown()
    {
        TreeIter ti = mCompTree.getSelectedIter();
        if(ti is null) return;
        if(!mCompStore.iterNext(ti)) //getIterFirst fails here ??
            mCompStore.getIter(ti, new TreePath("0"));
        mCompTree.getSelection().selectIter(ti);

        mCompTree.scrollToCell(ti.getTreePath(), null, false, 0, 0);
    }

    void CompletionSelectionEnd()
    {
        TreeIter last = mCompTree.getSelectedIter();
        TreeIter ti = mCompTree.getSelectedIter();
        if(ti is null)return;
        while(mCompStore.iterNext(ti)) mCompStore.iterNext(last);
        mCompTree.getSelection().selectIter(last);
        mCompTree.scrollToCell(last.getTreePath(),null, false, 0, 0);
    }

    void CompletionSelectionUp()
    {
        TreeIter ti = mCompTree.getSelectedIter();
        if(ti is null) return;
        if(!mCompStore.iterPrevious(ti))
        {
            CompletionSelectionEnd();
            return;
        }
        mCompTree.getSelection().selectIter(ti);
        mCompTree.scrollToCell(ti.getTreePath(), null, false, 0, 0);
    }

    void CompletionSelectionHome()
    {
        TreeIter ti = new TreeIter;
        mCompStore.getIterFirst(ti);
        mCompTree.getSelection().selectIter(ti);
        //interesting .. not using "0" in constructor will not scroll correctly
        mCompTree.scrollToCell(new TreePath("0"), null, false, 0,0);
    }



    public  :

    void Engage()
    {

        mCompStore = new ListStore([GType.STRING, GType.STRING]);
        mCompCol1 = new TreeViewColumn("Candidate", new CellRendererText,  "text",0);
        mCompCol2 = new TreeViewColumn("Info", new CellRendererText,  "text",1);
        mCompTree = new TreeView(mCompStore);
        mCompScroll = new ScrolledWindow;
        mCompWindow = new Window(GtkWindowType.POPUP);

        mCompTree.appendColumn(mCompCol1);
        mCompTree.appendColumn(mCompCol2);

        mCompScroll.add(mCompTree);

        mCompWindow.add(mCompScroll);

        mCompWindow.setKeepAbove(true);
        mCompTree.setHeadersVisible(false);
        mCompTree.setEnableSearch(false);

        //------

        mTipStore = new ListStore([GType.STRING]);
        mTipCol = new TreeViewColumn("Candidate", new CellRendererText,  "text",0);
        mTipTree = new TreeView(mTipStore);
        mTipScroll = new ScrolledWindow;
        mTipWindow = new Window(GtkWindowType.POPUP);

        mTipTree.appendColumn(mTipCol);

        mTipScroll.add(mTipTree);
        mTipWindow.add(mTipScroll);

        mTipWindow.setKeepAbove(true);
        mTipTree.setHeadersVisible(false);



        //----------------

        DocMan.DocumentKeyDown.connect(&WatchForKeys);
        DocMan.PageFocusOut.connect(&WatchForLostFocus);
        DocMan.MouseButton.connect(&WatchForMouseButton);

        Log.Entry("Engaged");
    }

    void PostEngage()
    {
        Log.Entry("PostEngaged");
    }

    void Disengage()
    {
        DocMan.MouseButton.disconnect(&WatchForMouseButton);
        DocMan.PageFocusOut.disconnect(&WatchForLostFocus);
        DocMan.DocumentKeyDown.disconnect(&WatchForKeys);
        Log.Entry("Disengaged");
    }


    void ShowCompletion(string[] Candidates, string[] Info)
    {

        mCompWindow.hide();
        mTipWindow.hide();

        auto ti = new TreeIter;

        mCompRows = cast(int)Candidates.length;

        mCompStore.clear();
        foreach(idx, candi; Candidates)
        {
            mCompStore.append(ti);
            mCompStore.setValue(ti, 0, candi);
            mCompStore.setValue(ti, 1, Info[idx]);
        }

        mCompTree.setModel(mCompStore);
        mCompWindow.showAll();
        MapCompletionWindow();
        
        mCompTree.setCursor(new TreePath("0"), null, false);
            
    }

    void PushCallTip(string[] Candidates)
    {

        static string unique_name = "aaa000";
        scope(exit) unique_name = unique_name.succ();

        CALLTIP pushtip;

        mAnchor.insert(pushtip);
        mAnchor.front.mCandidates = Candidates;
        mAnchor.front.mLocationName = unique_name;

        auto doc = cast(DOCUMENT)DocMan.Current();
        auto buf = doc.getBuffer();
        auto txtIter = doc.Cursor();
        buf.createMark(unique_name, txtIter, true);

        ShowCallTip();
    }

    void PopCallTip()
    {
        if(mAnchor.empty)return;
        auto doc = cast(DOCUMENT)DocMan.Current();
        auto buf = doc.getBuffer();
        buf.deleteMarkByName(mAnchor.front.mLocationName);
        mAnchor.removeFront();
        if(mAnchor.empty())
        {
            mTipWindow.hide();
            return;
        }
        ShowCallTip();
    }


    COMPLETION_STATUS GetState()
    {
        COMPLETION_STATUS rv = COMPLETION_STATUS.INERT;
        with(COMPLETION_STATUS)
        {

            if(!mAnchor.empty()) rv = rv & CALLTIP & ACTIVE;
            if(mCompWindow.isVisible()) rv = rv & COMPLETION & ACTIVE;
        }
        return rv;


    }
}


enum COMPLETION_STATUS
{
    INERT     ,
    ACTIVE    ,
    COMPLETION,
    CALLTIP   ,
}
