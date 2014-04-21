module messageview;

import std.traits;
import std.regex;
import std.conv;
import std.algorithm;
import std.path;

import dcore;
import ui;
import elements;
import document;


import gtk.ListStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.ScrolledWindow;
import gtk.CellRendererText;
import gtk.TextIter;

import gsv.SourceView;

export extern(C) string GetClassName()
{
     return fullyQualifiedName!MESSAGE_VIEW;
}


class MESSAGE_VIEW :ELEMENT
{
    private:

    ListStore       mStore;
    TreeView        mErrorView;
    ScrolledWindow  mScrollWin;

	void WatchForNewDocument(string Event, DOC_IF Doc)
	{
		if((Event == "Create") || (Event == "Open"))
		{
			auto xDoc = cast(DOCUMENT)Doc;

			auto tag = xDoc.getBuffer.createTag("ErrorUnderLine", "underline", PangoUnderline.ERROR);
			if(tag is null) ShowMessage("crap", "error creating an error tag:)", "OK");
		}
	}


    void WatchCompiler(string line)
    {
        if(line == "BEGIN") //SIGNALS COMPILER HAS JUST STARTED NEW MSGS COMING
        {
           mStore.clear();
           foreach(docif; DocMan.GetOpenDocs())
           {
			   auto xdoc = cast(DOCUMENT)docif;
			   auto tiStart = new TextIter;
			   auto tiEnd = new TextIter;
			   xdoc.getBuffer().getStartIter(tiStart);
			   xdoc.getBuffer().getEndIter(tiEnd);
			   xdoc.getBuffer().removeTagByName("ErrorUnderLine",tiStart,tiEnd);
		   }
           ui.mExtraPane.setCurrentPage(mScrollWin);
           return;
        }
        if(line == "END") return;

		auto rgx = regex(`\([\d]+,?[\d]+\)`);  //regex to look for [323,45]

        auto caps = line.matchFirst(rgx); //caps = what is found (captures)

        auto ti = new TreeIter;

        if(caps.empty())
        {
            mStore.append(ti);
            //mStore.setValue(ti, 0, " ");
            //mStore.setValue(ti, 1, " ");
            mStore.setValue(ti, 3, line);
            return;
        }
        else
        {
			int lno;
			int cno;

            string location = caps.hit()[1..$-1];
            auto hits = location.findSplit(",");

           	lno = to!int(hits[0]);

            if(hits[2].length > 0) cno = to!int(hits[2]);

            mStore.append(ti);
            mStore.setValue(ti, 0, caps.pre()); //part before regex found ... file
            mStore.setValue(ti, 1, lno);
            mStore.setValue(ti, 2, cno);
            mStore.setValue(ti, 3, caps.post());

            //set the error underline thingy
            auto errorfile = absolutePath(caps.pre());
            if(DocMan.IsOpen(errorfile))
            {
				auto xDoc = cast(DOCUMENT)DocMan.GetDoc(errorfile);
				assert(xDoc.Name == errorfile);
				auto TextIterBegin = new TextIter;
				auto TextIterEnd = new TextIter;
				xDoc.getBuffer.getIterAtLine(TextIterBegin, lno-1);
				TextIterEnd = TextIterBegin.copy();
				TextIterEnd.forwardToLineEnd();
				xDoc.getBuffer.applyTagByName("ErrorUnderLine", TextIterBegin, TextIterEnd);
			}

        }
    }

    void RowActivated(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter;

        mStore.getIter(ti, tp);
        string file = mStore.getValueString(ti, 0);
        file = file.absolutePath();
        int line = mStore.getValueInt(ti, 1) - 1;

        if(line < 0) return; //if this is not an error line (ie an info line) then do not try to open
        DocMan.Open(file, line);
    }


    public:

    this()
    {
        mScrollWin = new ScrolledWindow;
        mStore = new ListStore([GType.STRING, GType.INT, GType.INT, GType.STRING]);

        mErrorView = new TreeView;
        mErrorView.insertColumn(new TreeViewColumn("File",   new CellRendererText, "text", 0), -1);
        mErrorView.insertColumn(new TreeViewColumn("Line",   new CellRendererText, "text", 1), -1);
        mErrorView.insertColumn(new TreeViewColumn("Column", new CellRendererText, "text", 2), -1);
        mErrorView.insertColumn(new TreeViewColumn("Error",  new CellRendererText, "text", 3), -1);

        mErrorView.setModel(mStore);
        mErrorView.setActivateOnSingleClick (true);
        mScrollWin.add(mErrorView);
        AddExtraPage(mScrollWin, Name());
    }



    void Engage()
    {

        mErrorView.addOnRowActivated (&RowActivated);

        mScrollWin.showAll();
        DocMan.Event.connect(&WatchForNewDocument);
        DocMan.Message.connect(&WatchCompiler);
        Project.BuildOutput.connect(&WatchCompiler);
        Log.Entry("Engaged");

    }
    void Disengage()
    {
        mScrollWin.hide();
        Project.BuildOutput.disconnect(&WatchCompiler);
        DocMan.Message.disconnect(&WatchCompiler);
        DocMan.Event.disconnect(&WatchForNewDocument);
        Log.Entry("Disengaged");
    }
    void Configure()
    {
    }

    string Name (){return "Message View";}
    string Info(){return "View output from compiler";}
	string Version() {return "00.01";}
	string CopyRight() {return "Anthony Goins © 2014";}
	string License() {return "New BSD license";}
	string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}
	PREFERENCE_PAGE PreferencePage(){return null;}
}
