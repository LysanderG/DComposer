module message_view;

import std.algorithm;
import std.conv;
import std.format;
import std.path;

import ui;
import qore;
import elements;

import gtk.ScrolledWindow;


extern(C) string GetElementName()
{
    return "message_view.MESSAGE_VIEW";
}

class MESSAGE_VIEW : ELEMENT
{
    
    void Engage()
    {
        mRoot = new ScrolledWindow();
        mMessageList = new ListStore([GType.STRING, GType.INT, GType.INT, GType.STRING]);
        mMessageTree = new TreeView(mMessageList);
        TreeViewColumn tvcFile = new TreeViewColumn("File", new CellRendererText, "text", 0);
        TreeViewColumn tvcLine = new TreeViewColumn("Line", new CellRendererText, "text", 1);
        TreeViewColumn tvcCol =  new TreeViewColumn("Column", new CellRendererText, "text", 2);
        TreeViewColumn tvcMessage = new TreeViewColumn("Message", new CellRendererText, "text", 3);
        
        mMessageTree.appendColumn(tvcFile);
        mMessageTree.appendColumn(tvcLine);
        mMessageTree.appendColumn(tvcCol);
        mMessageTree.appendColumn(tvcMessage);
        
        mRoot.add(mMessageTree);
        mRoot.showAll();
        
        mMessageTree.addOnRowActivated(delegate void(TreePath tp, TreeViewColumn tvc, TreeView tv)
        {
            TreeIter ti =new TreeIter();
            mMessageList.getIter(ti, tp);
            string docfile;
            int line, col;
            docfile = mMessageList.getValueString(ti, 0);
            line = mMessageList.getValueInt(ti, 1);
            col = mMessageList.getValueInt(ti, 2);
            if(line <= 0)return;
            docfile = absolutePath(docfile);
            OpenDocAt(docfile, line-1, col-1);
        });
        
        AddExtraPane(mRoot, "Messages");
        Transmit.Message.connect(&WatchForMessages);
    }
 
    void Mesh(){Log.Entry("Meshed");}
    void Disengage()
    {
        Transmit.Message.disconnect(&WatchForMessages);
        RemoveExtraPaneWidget(mRoot);
        Log.Entry("Disengaged");
    }

    void Configure(){Log.Entry("Configure");}

    string Name(){return "message_vew".idup;}
    string Info(){return "Shows messages from various tools.".idup;}
    string Version(){return "Nightly Build".idup;}
    string License(){return "to kill".idup;}
    string CopyRight(){return "very much so".idup;}
    string Authors(){return "Lysander, Anthony Goins".idup;}

    Dialog SettingsDialog()
    {
        return new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.OTHER, ButtonsType.CLOSE, "Font selector coming soon");
    }
    
    private:
    
    ScrolledWindow      mRoot;
    TreeView            mMessageTree;
    ListStore            mMessageList;
    
    
    void WatchForMessages(string Source, string message)
    {
        
        string file, msgPayload, toolStatus;
        int line;
        int column;
        dwrite(Source, " ", message);
        switch(Source)
        {
            case "rdmd":
            case COMPILER.DMD :
            { 
                if(message.startsWith("end"))
                {
                    TreeIter ti;
                    mMessageList.getIterFromString(ti, "0");
                    mMessageList.remove(ti);
                    if(message.length > 3)
                    {
                        string status = message[4.. $];
                        AppendStore(" ", 0,0, Source ~ ": exit status " ~ status);
                    ApplyErrorLineTag();
                        return;
                    }
                    AppendStore(" ", 0,0, Source ~ " finished");
                    ApplyErrorLineTag();
                }
                if(message == "begin")
                {
                    SwitchExtraPage(mRoot);
                    ResetMessages();
                    RemoveErrorLineTag();
                    AppendStore(" ", 0, 0, "Tool running");
                    break;
                }

                {
                    auto errorMsg = message.idup;
                    scope(failure)
                    {
                        AppendStore(" ", 0,0,errorMsg);
                        return;
                    }
                    formattedRead(message, "%s(%s,%s): %s", file, line, column, msgPayload);
                    AppendStore(file, line, column, msgPayload);
                }                
                break;
            } 
            default:break;
        }           
    }
    
    void ResetMessages()
    {   
        mMessageList.clear();
    }
    void AppendStore(string file, int line, int col, string error)
    {
        TreeIter ti;
        mMessageList.append(ti);
        mMessageList.setValue(ti, 0, file);
        mMessageList.setValue(ti, 1, line);
        mMessageList.setValue(ti, 2, col);
        mMessageList.setValue(ti, 3, error);
    }
    
    void ApplyErrorLineTag()
    {
        dwrite("applyerrorlinetag");
        TreeIter ti;
        TextIter tiStart, tiEnd;
        bool looping = mMessageList.getIterFirst(ti);
        
        while(looping)
        {
        
            string fname = mMessageList.getValueString(ti, 0);
            int eline = mMessageList.getValueInt(ti, 1)-1;
            fname = fname.absolutePath();
            dwrite(fname);
            if(Opened(fname))
            {
                dwrite("\there");
                DOCUMENT edoc = cast(DOCUMENT)GetDoc(fname);
                edoc.buff.getIterAtLine(tiStart, eline);
                tiEnd = tiStart.copy();
                tiEnd.forwardToLineEnd();
                edoc.buff.applyTagByName("error_line", tiStart, tiEnd);
            }
            looping = mMessageList.iterNext(ti);
        }
    }
    
    void RemoveErrorLineTag()
    {
        TextIter tiStart, tiEnd;
        foreach(doc; GetDocs)
        {
            DOCUMENT edoc = cast(DOCUMENT)doc;
            edoc.buff.getStartIter(tiStart);
            edoc.buff.getEndIter(tiEnd);
            edoc.buff.removeTagByName("error_line", tiStart, tiEnd);
        }
    }
}

/*
message structure
    begin tool notice (ie dmd messages begin)
    tool id  dscanner dfmt dmd whatever
    normal file:line error  | some info line
    end tool notice & return status
    */
