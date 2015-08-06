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

        AddIcon("nav-back", SystemPath(Config.GetValue("navigation_elem", "nav_back", "elements/resources/document-page-previous.png")));
        AddAction("NavBack", "Back", "Go back to last cursor location", "nav-back", "<Control>comma",
            delegate void(Action a){BackNavPoint();});
        AddToMenuBar("NavBack", mRootMenuNames[6], 0);

        AddIcon("nav-forward", SystemPath(Config.GetValue("navigation_elem", "nav_forward", "elements/resources/document-page-next.png")));
        AddAction("NavForward", "Forward", "Go forward to previous cursor location", "nav-forward", "<Control>period",
            delegate void(Action a){ForwardNavPoint();});
        AddToMenuBar("NavForward", mRootMenuNames[6], 0);

        AddIcon("nav-add", SystemPath(Config.GetValue("navigation_elem", "nav_add", "elements/resources/pin-small.png")));
        AddAction("NavAdd", "Add Nav Point", "Insert a navigation mark", "nav-add", "<Control>M",
            delegate void(Action a){AddNavPoint();});
        AddToMenuBar("NavAdd", mRootMenuNames[6], 0);

        AddIcon("nav-clear", SystemPath(Config.GetValue("navigation_elem", "nav_clear", "elements/resources/minus-small-circle.png")));
        AddAction("NavClear", "Clear Nav Points", "Clear all navigation marks", "nav-clear", "<Control><Shift>M",
            delegate void(Action a){ClearNavPoints();});
        AddToMenuBar("NavClear", mRootMenuNames[6], 0);


        Log.Entry("Engaged");
    }

    void Disengage()
    {
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

    NAV_POINT[] NavPoints;
    ulong       NavIndex;

    void PushNavPoint(DOC_IF docIF, int line, int column)
    {

        auto Doc = cast(DOCUMENT) docIF;
        if(Doc is null) return;
        if(Doc.Cursor.isEnd()) return;
        //auto mark = Doc.getBuffer.createSourceMark(null, "NavPoints", Doc.Cursor);

        auto newPoint = new NAV_POINT;
        newPoint.DocName = Doc.Name;
        newPoint.Line = line;
        newPoint.Col = column;

        if(NavPoints.length == 0)
        {
            NavPoints ~= newPoint;
            NavIndex = 0;
            return;
        }

        if( (newPoint.DocName == NavPoints[NavIndex].DocName) && (newPoint.Line == NavPoints[NavIndex].Line)) return;

        if(NavIndex == 0)
        {
            NavPoints = NavPoints[0..1];
            NavPoints ~= newPoint;
            NavIndex = 1;
            return;
        }

        NavPoints = NavPoints[0 .. NavIndex+1] ~ newPoint;
        NavIndex = NavPoints.length - 1;

    }

    void BackNavPoint()
    {
        if(NavPoints.length < 1) return;
        if(NavIndex > 0) NavIndex--;

        Go(NavPoints[NavIndex]);
    }

    void ForwardNavPoint()
    {
        if(NavIndex+1 >= NavPoints.length) return;
        NavIndex++;
        //DocMan.Open(NavPoints[NavIndex].DocName, NavPoints[NavIndex].Line);
        //Go(cast(DOCUMENT)DocMan.Open(NavPoints[NavIndex].DocName), NavPoints[NavIndex].Line);
        Go(NavPoints[NavIndex]);
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
        NavPoints.length = 0;
        NavIndex = 0;
    }

}

private :

class NAV_POINT
{
    string DocName;
    int Line;
    int Col;
}
