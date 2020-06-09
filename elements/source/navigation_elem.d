module navigation_elem;

import std.container;

import dcore;
import ui;
import elements;

import document;



extern (C) string GetClassName()
{
    return "navigation_elem.NAVIGATION_ELEM";
}

class NAVIGATION_ELEM : ELEMENT
{
    public:

    string Name(){return "Navigation element";}
    string Info(){return "Ways to get around code quickly and easily";}
    string Version(){return "00.01";}
    string License(){return "Unknown";}
    string CopyRight(){return "Anthony Goins © 2015";}
    string[] Authors(){return ["Anthony Goins <neontotem@gmail.com>"];}


    void Engage()
    {
        DocMan.PreCursorJump.connect(&PushNavPoint);
        DocMan.CursorJump.connect(&PushNavPoint);

        AddToMenuBar("-", mRootMenuNames[6]);

        AddIcon("nav-back", ElementPath(Config.GetValue("navigation_elem", "nav_back", "resources/document-page-previous.png")));
        AddAction("NavBack", "Back", "Go back to last cursor location", "nav-back", "<Control>comma",
            delegate void(Action a){BackNavPoint();});
        mActionMenuItems ~= AddToMenuBar("NavBack", mRootMenuNames[6]);

        AddIcon("nav-forward", ElementPath(Config.GetValue("navigation_elem", "nav_forward", "resources/document-page-next.png")));
        AddAction("NavForward", "Forward", "Go forward to previous cursor location", "nav-forward", "<Control>period",
            delegate void(Action a){ForwardNavPoint();});
        mActionMenuItems ~= AddToMenuBar("NavForward", mRootMenuNames[6]);

        AddIcon("nav-add", ElementPath(Config.GetValue("navigation_elem", "nav_add", "resources/pin-small.png")));
        AddAction("NavAdd", "Add Nav Point", "Insert a navigation mark", "nav-add", "<Control>M",
            delegate void(Action a){AddNavPoint();});
        mActionMenuItems ~= AddToMenuBar("NavAdd", mRootMenuNames[6]);

        AddIcon("nav-clear", ElementPath(Config.GetValue("navigation_elem", "nav_clear", "resources/minus-small-circle.png")));
        AddAction("NavClear", "Clear Nav Points", "Clear all navigation marks", "nav-clear", "<Control><Shift>M",
            delegate void(Action a){ClearNavPoints();});
        mActionMenuItems ~= AddToMenuBar("NavClear", mRootMenuNames[6]);


        Log.Entry("Engaged");
    }

    void Disengage()
    {

        foreach(item; mActionMenuItems)RemoveFromMenuBar(item, mRootMenuNames[6]);
        RemoveAction("NavBack");
        RemoveAction("NavForward");
        RemoveAction("NavClear");
        RemoveAction("NavAdd");

        DocMan.CursorJump.disconnect(&PushNavPoint);
        DocMan.PreCursorJump.disconnect(&PushNavPoint);
        Log.Entry("Disengaged");
    }


    void Configure()
    {
    }
    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }

    private:

    NAV_POINT[] mNavPoints;
    ulong       mNavIndex;

    MenuItem[]  mActionMenuItems;   //save these to remove them on disengage with out crashing


    void PushNavPoint(DOC_IF docIF, int line, int column)
    {
        scope(exit)UpdateGutters();
        auto Doc = cast(DOCUMENT) docIF;
        if(Doc is null) return;
        if(Doc.Cursor.isEnd()) return;
        //auto mark = Doc.getBuffer.createSourceMark(null, "NavPoints", Doc.Cursor);

        auto newPoint = new NAV_POINT;
        newPoint.DocName = Doc.Name;
        newPoint.Line = line;
        newPoint.Col = column;

        if(mNavPoints.length == 0)
        {
            mNavPoints ~= newPoint;
            mNavIndex = 0;
            return;
        }

        if( (newPoint.DocName == mNavPoints[mNavIndex].DocName) && (newPoint.Line == mNavPoints[mNavIndex].Line)) return;

        if(mNavIndex == 0)
        {
            mNavPoints = mNavPoints[0..1];
            mNavPoints ~= newPoint;
            mNavIndex = 1;
            return;
        }

        mNavPoints = mNavPoints[0 .. mNavIndex+1] ~ newPoint;
        mNavIndex = mNavPoints.length - 1;

    }

    void BackNavPoint()
    {
        if(mNavPoints.length < 1) return;
        if(mNavIndex > 0) mNavIndex--;

        Go(mNavPoints[mNavIndex]);
    }

    void ForwardNavPoint()
    {
        if(mNavIndex+1 >= mNavPoints.length) return;
        mNavIndex++;
        //DocMan.Open(mNavPoints[mNavIndex].DocName, mNavPoints[mNavIndex].Line);
        //Go(cast(DOCUMENT)DocMan.Open(mNavPoints[mNavIndex].DocName), mNavPoints[mNavIndex].Line);
        Go(mNavPoints[mNavIndex]);
    }

    void Go(NAV_POINT np)
    {

        if(np.Line < 0) return;
        if(np.Col  < 0) np.Col = 0;

        //auto Doc = cast(DOCUMENT)DocMan.GetDoc(np.DocName);
        //if(Doc is null) Doc = cast(DOCUMENT)DocMan.Open(np.DocName);
        auto Doc = cast(DOCUMENT)DocMan.Open(np.DocName, -1, -1);

        auto tiline = new TextIter;
        Doc.getBuffer().getIterAtLine(tiline, np.Line);
        if(np.Col > tiline.getCharsInLine())np.Col = 0;
        Doc.getBuffer().getIterAtLineIndex(tiline, np.Line, np.Col);
        Doc.getBuffer().placeCursor(tiline);
        Doc.scrollToIter(tiline, 0.25, false, 0, 0);
    }

    void AddNavPoint()
    {
        if(DocMan.Current() is null) return;
        PushNavPoint(DocMan.Current(), DocMan.Current.Line(), DocMan.Current.Column());
    }

    void ClearNavPoints()
    {
        mNavPoints.length = 0;
        mNavIndex = 0;
        UpdateGutters();
    }
    void UpdateGutters()
    {
        foreach(doc_if; DocMan.GetOpenDocs())
        {
            auto doc = cast(DOCUMENT)doc_if;
            TextIter tiStart, tiEnd;
            doc.getBuffer.getStartIter(tiStart);
            doc.getBuffer.getEndIter(tiEnd);
            doc.getBuffer.removeSourceMarks(tiStart, tiEnd, "NavPoints");
        }
        foreach(nvpt; mNavPoints)
        {
            auto doc = cast(DOCUMENT)DocMan.GetDoc(nvpt.DocName);
            if(doc)
            {
                TextIter ti = new TextIter;
                doc.getBuffer().getIterAtLineOffset(ti, nvpt.Line, nvpt.Col);
                doc.getBuffer().createSourceMark(null, "NavPoints", ti);
            }            
        }

    }



}

private :

class NAV_POINT
{
    string DocName;
    int Line;
    int Col;
}
