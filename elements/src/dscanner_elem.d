module dscanner_elem;


import std.algorithm;
import std.conv;
import std.process : pipeProcess, wait;
import std.string;

import dcore;
import elements;
import ui;


export extern (C) string GetClassName()
{
    return "dscanner_elem.DSCANNER_ELEM";
}


class DSCANNER_ELEM : ELEMENT
{
    void Engage()
    {
        //dscanner functions
        //-count lines of code  stdin
        //-count tokens         stdin
        //-htmlhighting         stdin
        //-import list          stdin
        //-syntaxCheck          stdin
        //-styleCheck           ?????
        //-ctags                -----
        //-etags                -----
        //-etagsall             -----
        //-ast                  stdin
        //-declaration          -----
        //-report               ?????
        //-outline              stdin

        mDScannerCommand = Config.GetValue("dscanner_elem", "dscanner_command", "/home/anthony/apps/dscanner/dscanner");
        TestDScannerCommand();

        EngageOutline();
        Log.Entry("Engaged");
    }
    void Disengage()
    {
        DisengageOutline();
        Log.Entry("Disengaged");
    }

    void Configure()
    {
    }

    string Name(){return "dscanner element";}
    string Info(){return "Provide functionality of HackerPilot's dscanner utility";}
    string Version(){return "00.01";}
    string License(){return "Unknown";}
    string CopyRight(){return "Anthony Goins © 2015";}
    string[] Authors(){return ["Anthony Goins <neontotem@gmail.com>"];}

    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }

    private:

    string              mDScannerCommand;


    //outline
    string[]            mOutlineCommand;
    Box                 mOutlineRoot;
    ScrolledWindow      mOutlineScroll;
    TreeView            mOutlineTree;
    TreeStore           mOutlineStore;
    bool                mBlockCursorChangeOnUpdate;
    bool                mBadDscannerBinary;



    void TestDScannerCommand()
    {
        scope(failure)
        {
            Log.Entry("Please check dscanner_elem preferences for correct dscanner binary", "Error");
            mBadDscannerBinary = true;
            return;
        }
        scope(success) mBadDscannerBinary = false;
        execute(mDScannerCommand);
    }


    void EngageOutline()
    {

        mOutlineCommand = [mDScannerCommand] ~ "--outline";

        mOutlineRoot = new Box(Orientation.VERTICAL, 1);
        mOutlineScroll = new ScrolledWindow();

        mOutlineTree = new TreeView;
        mOutlineStore = new TreeStore([GType.STRING, GType.INT, GType.STRING]);
        mOutlineTree.appendColumn(new TreeViewColumn("symbol", new CellRendererText, "text", 2));
        mOutlineTree.appendColumn(new TreeViewColumn("line", new CellRendererText, "text", 1));
        mOutlineTree.getColumn(0).setSortColumnId(2);
        mOutlineTree.getColumn(1).setSortColumnId(1);
        mOutlineTree.setTooltipColumn(0);
        mOutlineTree.setModel(mOutlineStore);

        mOutlineRoot.setVexpand(true);
        mOutlineScroll.setVexpand(true);
        mOutlineTree.setEnableTreeLines(true);
        mOutlineTree.setLevelIndentation(5);

        mOutlineTree.addOnRowActivated(delegate void(TreePath tp, TreeViewColumn tvc, TreeView tv)
        {
            if(mBadDscannerBinary) return;
            if(DocMan.Current is null) return;
            auto ti = new TreeIter;
            mOutlineStore.getIter(ti, tp);
            auto lineno = mOutlineStore.getValueInt(ti, 1);
            DocMan.Current.GotoLine(lineno -1, 0);
        });

        mOutlineTree.addOnCursorChanged(delegate void(TreeView tv)
        {
            if(mBadDscannerBinary)return;
            if(mBlockCursorChangeOnUpdate)return;

            auto ti = tv.getSelectedIter();
            if (ti is null) return;
            auto candidate = mOutlineStore.getValueString(ti, 2).findSplitBefore("(");
            auto line = mOutlineStore.getValueInt(ti, 1);
            DSYMBOL[] results;
            foreach(eyetem; Symbols.GetCompletions([candidate[0]]))
            {
                //hah! close as I can get
                if(eyetem.Line == line) results ~= eyetem;
            }
            Symbols.emit(results);
        });

        DocMan.Insertion.connect(&WatchForInsertion);
        DocMan.PageFocusIn.connect(&WatchForPageFocus);




        mOutlineScroll.add(mOutlineTree);
        mOutlineRoot.add(mOutlineScroll);
        mOutlineRoot.showAll();
        AddSidePage(mOutlineRoot, "Module");

        //UpdateOutline();
    }

    void DisengageOutline()
    {
        DocMan.PageFocusIn.disconnect(&WatchForPageFocus);
        DocMan.Insertion.disconnect(&WatchForInsertion);
        RemoveSidePage(mOutlineRoot);
        mOutlineRoot.destroy();

    }

    void UpdateOutline()
    {
        if(mBadDscannerBinary)return;
        mBlockCursorChangeOnUpdate = true;
        scope(exit)mBlockCursorChangeOnUpdate = false;

        auto ctp = new TreePath;
        auto ctvc = new TreeViewColumn;

        scope(exit) if (ctp !is null) mOutlineTree.setCursor(ctp, cast(TreeViewColumn)null, false);
        //mOutlineTree.getCursor(ctp, ctvc);

        mOutlineStore.clear();

        if(DocMan.Current() is null)return;

        //dummy scope
        {
            scope(failure)
            {
                Log.Entry("dscanner --outline failed.", "Error");
                return;
            }
            auto pipes = pipeProcess(mOutlineCommand);

            pipes.stdin.write(DocMan.Current.GetText());
            pipes.stdin.flush();
            pipes.stdin.close();

            char[]  buff;
            long     colonPosition;
            string  sym;
            int     position;
            long     prevNestLevel;
            TreeIter ti = new TreeIter;
            while(pipes.stdout.readln(buff))
            {

                colonPosition = buff.indexOf(':');
                if(colonPosition == -1)continue;
                sym = buff[0..colonPosition].idup;
                position = to!int(buff[colonPosition+1..$].idup.strip());

                auto nest = countUntil!("a != b")(sym, ' ');

                if(nest < 0) //impossible?? a full line of \t ?
                {
                    continue; //??
                }
                nest = nest / 4;

                if(nest == 0) //root
                {
                    ti = mOutlineStore.append(null);
                    mOutlineStore.setValue(ti, 0, sym.strip());
                    mOutlineStore.setValue(ti, 1, position);
                    mOutlineStore.setValue(ti, 2, GetSymName(sym));

                    prevNestLevel = nest;
                    continue;
                }

                if(nest == prevNestLevel) //sibling but not root siblings
                {
                    //ti = mOutlineStore.append(ti.getParent());
                    ti.setModel(mOutlineStore);
                    auto pops = ti.getParent();
                    mOutlineStore.insert(ti, pops, -1);
                    mOutlineStore.setValue(ti, 0, sym.strip());
                    mOutlineStore.setValue(ti, 1, position);
                    mOutlineStore.setValue(ti, 2, GetSymName(sym));

                    prevNestLevel = nest; //c'est la meme chose
                    continue;
                }
                if(nest > prevNestLevel) //by one only, me hopes
                {
                    mOutlineStore.append(ti, ti);
                    mOutlineStore.setValue(ti, 0, sym.strip());
                    mOutlineStore.setValue(ti, 1, position);
                    mOutlineStore.setValue(ti, 2, GetSymName(sym));

                    prevNestLevel = nest;
                    continue;
                }
                if(nest < prevNestLevel) //again
                {
                    //hmmm....
                    ti.setModel(mOutlineStore);
                    while (nest <= prevNestLevel)
                    {
                        ti = ti.getParent();
                        prevNestLevel--;
                    }
                    mOutlineStore.append(ti, ti);
                    mOutlineStore.setValue(ti, 0, sym.strip());
                    mOutlineStore.setValue(ti, 1, position);
                    mOutlineStore.setValue(ti, 2, GetSymName(sym));

                    prevNestLevel = nest;
                    continue;
                }
            }
            pipes.stdout.flush();

            pipes.stdout.close();
            wait(pipes.pid);

        }

        mOutlineTree.expandAll();

    }

    void WatchForInsertion(void* iter, string text, int len, void* buffer)
    {
        UpdateOutline();
    }

    void WatchForPageFocus(DOC_IF doc)
    {
        static string DocName = "";
        if(DocName == doc.Name) return;
        DocName = doc.Name;
        UpdateOutline();
    }

    string GetSymName(string longName)
    {
        auto rv = longName.strip();
        auto ndx = rv.countUntil(' ');
        if (ndx == -1) return rv;
        return rv[ndx+1..$];
    }

}
