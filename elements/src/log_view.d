module log_view;

import std.string;

import dcore;
import ui;
import elements;
import ui_preferences;



import pango.PgFontDescription;


extern (C) string GetClassName()
{
    return "log_view.LOG_VIEW";
}


class LOG_VIEW :ELEMENT
{
    private:

    ScrolledWindow mScrollWin;
    TreeView mTree;
    ListStore mList;

    void LogCatcher(string Mesg, string Level, string Module)
    {
        if(Level.strip() == "Error") Mesg = `<span foreground="red"><b>`~Mesg~ `</b></span>`;
        if(Level.strip() == "Debug" ) Mesg = `<span foreground="blue">`~Mesg~ "</span>";

        string xtry = format ("%8s [%20s] : %s", Level, Module,  Mesg);

        auto trit = new TreeIter;

        mList.append(trit);
        mList.setValue(trit, 0, xtry);
        auto path = mList.getPath(trit);
        mTree.setCursor(path, null, false);
    }



    public :
    this()
    {
        mScrollWin = new ScrolledWindow;
        mTree = new TreeView;
        mList = new ListStore([GType.STRING, GType.STRING]);

        auto tvc = new TreeViewColumn("Log Entry", new CellRendererText, "markup", 0);
        mTree.appendColumn(tvc);
        mTree.setRulesHint(1);
        mTree.setModel(mList);
        mScrollWin.add(mTree);
        mScrollWin.showAll();

        mTree.addOnSizeAllocate(delegate void(GdkRectangle*, Widget){
            auto Vadj = mScrollWin.getVadjustment();
            Vadj.setValue(Vadj.getUpper() - Vadj.getPageSize());
        });
    }

    string Name() {return "Log Viewer";}
    string Info() {return "Display log messages in a pretty window.";}
    string Version() {return "00.01";}
    string CopyRight() {return "Anthony Goins © 2014";}
    string License() {return "New BSD license";}
    string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}

    void Engage()
    {
        Configure;
        ui.AddExtraPage(cast(Container)mScrollWin, "Log Viewer");

        foreach (entry; Log.GetEntries())LogCatcher(entry[34..$], entry[0..8], entry[10..30]);
        Log.SetLockEntries(false);
        Log.connect(&LogCatcher);

        //mExtraPane.reorderChild(mScrollWin, Config.GetValue("log_view", "page_position", 0));

        Log.Entry("Engaged");
    }


    void Disengage()
    {
        Log.disconnect(&LogCatcher);
        RemoveExtraPage(mScrollWin);
        mScrollWin.destroy();

        //Config.SetValue("log_view", "page_position", mExtraPane.pageNum(mScrollWin));

        Log.Entry("Disengaged");
    }

    void Configure()
    {
        mTree.modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.GetValue("log_view", "font", "Inconsolata Bold 12")));
    }

    PREFERENCE_PAGE PreferencePage()
    {
        PREFERENCE_PAGE page = new LOG_VIEW_PREFERENCE_PAGE;
        return page;
    }
}

final class LOG_VIEW_PREFERENCE_PAGE : PREFERENCE_PAGE
{
    this()
    {
        Title = "Log viewer preferences";
        ContentWidget = new Box(GtkOrientation.HORIZONTAL, 1);
        auto label = new Label ("Font:");
        auto fontbtn = new FontButton;

        auto CastBox = cast(Box)ContentWidget;

        CastBox.packStart(label, 1,1,10);
        CastBox.packStart(fontbtn, 1,1,10);

        fontbtn.setFontName(Config.GetValue!string("log_view", "font"));
        fontbtn.addOnFontSet(delegate void(FontButton){Config.SetValue("log_view", "font", fontbtn.getFontName());});

        ContentWidget.showAll();
    }
}



