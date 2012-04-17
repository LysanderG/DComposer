//      terminal.d
//      
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//      
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//      
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//      
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.


module terminalui;

import std.string;
import std.stdio;
import std.file;

import dcore;
import ui;
import elements;

import gtk.ScrolledWindow;
import gtk.Widget;

import gtkc.gtk;
import gtkc.gobject;

extern(C) GtkWidget * vte_terminal_new();
extern(C) int   vte_terminal_fork_command_full(GtkWidget *terminal, int pty_flags, const char * working_directory, const char **argv, char **envv, int spawn_flags,void * child_setup, void * child_setup_data,void *child_pid, void *error);
extern(C) void  vte_terminal_feed_child(GtkWidget *terminal, const char *data, long length);
extern(C) int   vte_terminal_fork_command (GtkWidget *terminal, const char *command, char **argv, char **envv, const char *working_directory, gboolean lastlog, gboolean utmp, gboolean wtmp);
extern(C) void  vte_terminal_reset(GtkWidget *terminal, gboolean clear_tabstops, gboolean clear_history);



class TERMINAL_UI : ELEMENT
{
    private:

    string              mName;
    string              mInfo;
    bool                mState;

    
    ScrolledWindow      mScrWin;
    Widget              mTerminal;
    GtkWidget *         cvte;

    void NewDirectory(string EventType)
    {
        if(EventType == "WorkingPath")
        {
            
            immutable(char) * cdcmd = toStringz("cd " ~ getcwd() ~ "\n");
            vte_terminal_feed_child(cvte, cdcmd, getcwd().length +4);
        }
    }

    public:

    this()
    {
        mName = "TERMINAL_UI";
        mInfo = "A terminal";
        mState = false;
    }
    
    @property string Name(){ return mName;}
    @property string Information(){return mInfo;}
    @property bool   State(){ return mState;}
    @property void   State(bool nuState){mState = nuState;}


    

    void Engage()
    {
        mScrWin = new ScrolledWindow;
        cvte = vte_terminal_new();
        mTerminal = new Widget(cvte);

        mScrWin.add(mTerminal);
        mScrWin.showAll();
        dui.GetExtraPane.appendPage(mScrWin, "Terminal");
        dui.GetExtraPane.setTabReorderable ( mScrWin, true); 
        

        g_cvte = cvte;
        vte_terminal_fork_command (cvte, null, null, null, null,true, true, true);
        g_signal_connect_object(cvte, cast(char*)toStringz("child-exited"),&Reset,null, cast(GConnectFlags)0);

        Project.Event.connect(&NewDirectory);

        Log.Entry("Engaged TERMINAL_UI element");

        
    }
        
        

    void Disengage()
    {
        mState = false;
        mScrWin.hide();
        Project.Event.disconnect(&NewDirectory);
        Log.Entry("Disengaged TERMINAL_UI element");
        
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return null;
    }
}

private GtkWidget * g_cvte;

extern (C) void Reset()
{
    vte_terminal_fork_command (g_cvte, null, null, null, null,true, true, true);
}

