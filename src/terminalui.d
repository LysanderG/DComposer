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

import std.algorithm;
import std.string;
import std.stdio;
import std.file;
import std.conv;
import std.uni;

import core.sys.posix.unistd;

import dcore;
import ui;
import elements;
import document;

import gdk.Color;

import gtk.ScrolledWindow;
import gtk.Widget;
import gtk.FontButton;
import gtk.ColorButton;
import gtk.Notebook;

import pango.PgFontDescription;

import gtkc.gtk;
import gtkc.gobject;

extern(C) GtkWidget * vte_terminal_new();
extern(C) int   vte_terminal_fork_command_full(GtkWidget *terminal, int pty_flags, const char * working_directory, const char **argv, char **envv, int spawn_flags,void * child_setup, void * child_setup_data,void *child_pid, void *error);
extern(C) void  vte_terminal_feed_child(GtkWidget *terminal, const char *data, long length);
extern(C) void  vte_terminal_feed(GtkWidget *terminal, const char *data, long length);
extern(C) void  vte_terminal_feed_child_binary(GtkWidget *terminal, const char *data, long length);
extern(C) int   vte_terminal_fork_command (GtkWidget *terminal, const char *command, char **argv, char **envv, const char *working_directory, gboolean lastlog, gboolean utmp, gboolean wtmp);
extern(C) void  vte_terminal_reset(GtkWidget *terminal, gboolean clear_tabstops, gboolean clear_history);
extern(C) int 	vte_terminal_match_add(GtkWidget *terminal, const char *match); //underlines word under mouse if it matches match
extern(C) void  vte_terminal_set_font (GtkWidget *terminal, const PangoFontDescription *font_desc);
extern(C) void  vte_terminal_set_font_from_string(GtkWidget *terminal,  const char *name);
extern(C) void  vte_terminal_set_scrollback_lines(GtkWidget *terminal, glong lines);
extern(C) VtePty * vte_terminal_get_pty_object         (GtkWidget *terminal);

struct VtePty;
extern(C) int   vte_pty_get_fd(VtePty *pty);

extern(C) gboolean 	gdk_color_parse(const gchar *spec, GdkColor *color);
extern(C) gchar   	*gdk_color_to_string(const GdkColor *color);



extern(C) void vte_terminal_set_colors(GtkWidget *terminal,  const GdkColor *foreground,const GdkColor *background,const GdkColor *palette, glong palette_size);

class TERMINAL_UI : ELEMENT
{
    private:

    string              mName;
    string              mInfo;
    bool                mState;

    
    ScrolledWindow      mScrWin;
    Widget              mTerminal;
    GtkWidget 			*cvte;
    GdkColor 			*ForeColor;	
	GdkColor 			*BackColor;

	TERMINAL_PAGE		PrefPage;

    void WatchProject(ProEvent EventType)
    {

        if(EventType == ProEvent.PathChanged)
        {
            
            immutable(char) * cdcmd = toStringz("cd " ~ getcwd() ~ "\n");
            vte_terminal_feed_child(cvte, cdcmd, getcwd().length +4);
        }
		
    }		

    void Configure()
    {
		//************** colors
		auto foreColor = Config.getString("TERMINAL", "forecolor", "#000000000000");
		ForeColor = new GdkColor;		
		gdk_color_parse(toStringz(foreColor), ForeColor);
		gdk_color_to_string(ForeColor);
		
		auto backColor = Config.getString("TERMINAL", "backcolor", "#0000ffff0000");
		BackColor = new GdkColor;
		gdk_color_parse(toStringz(backColor), BackColor);
		gdk_color_to_string(BackColor);
		
		vte_terminal_set_colors(cvte, ForeColor, BackColor, null, 0);
		
		//*******************font

		string FullFontName = Config.getString("TERMINAL", "font", "DejaVu Sans Mono 8");
		vte_terminal_set_font_from_string(cvte, toStringz(FullFontName));

		//*******************infinite scrolling
		vte_terminal_set_scrollback_lines(cvte, -1);
		
	}
		

    public:

    this()
    {
        mName = "TERMINAL_UI";
        mInfo = "A terminal";
        mState = false;

        PrefPage = new TERMINAL_PAGE;
    }
    
    @property string Name(){ return mName;}
    @property string Information(){return mInfo;}
    @property bool   State(){ return mState;}
    @property void   State(bool nuState){mState = nuState;}


    

    void Engage()
    {
        mScrWin = new ScrolledWindow;
        cvte = vte_terminal_new();
        g_cvte = cvte;

        Configure();
        vte_terminal_fork_command (cvte, null, null, null, null,true, true, true);

		
        g_signal_connect_object(cvte, cast(char*)toStringz("child-exited"),&Reset  , null, cast(GConnectFlags)0);
        //g_signal_connect_object(cvte, cast(char*)toStringz("commit")      ,cast(GCallback)&ProcessInput     , null, cast(GConnectFlags)0);

		
		
        mTerminal = new Widget(cvte);
        
        mScrWin.add(mTerminal);
        mScrWin.showAll();
        dui.GetExtraPane.appendPage(mScrWin, "Terminal");
        dui.GetExtraPane.setTabReorderable ( mScrWin, true); 

        Project.Event.connect(&WatchProject);
        Config.Reconfig.connect(&Configure);
        
        Log.Entry("Engaged "~mName~"\t\telement.");

    }
        
        

    void Disengage()
    {
        mState = false;
        mScrWin.hide();
        Project.Event.disconnect(&WatchProject);
        Config.Reconfig.disconnect(&Configure);
        Log.Entry("Disengaged "~mName~"\t\telement.");
        
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return PrefPage;
    }
}

private GtkWidget * g_cvte;

extern (C) void Reset()
{
    vte_terminal_fork_command (g_cvte, null, null, null, null,true, true, true);    
}

string vtetext;


class TERMINAL_PAGE : PREFERENCE_PAGE
{
	private:
	
	FontButton		mFontButton;
	ColorButton		mForeColor;
	ColorButton		mBackColor;

	GdkColor fcolor;
	GdkColor bcolor;
	
	

	public:

	this()
	{
		super("Elements", Config.getString("PREFERENCES", "glade_file_terminal", "$(HOME_DIR)/glade/terminalpref.glade"));

		mFontButton = cast(FontButton)  mBuilder.getObject("fontbutton1");
		mForeColor  = cast(ColorButton) mBuilder.getObject("colorbutton1");
		mBackColor  = cast(ColorButton) mBuilder.getObject("colorbutton2");

		mFrame.showAll();
	}

	override void PrepGui()
	{
		mFontButton.setFontName(Config.getString("TERMINAL", "font", "DejaVu Sans Mono 8"));

		
		Color.parse(Config.getString("TERMINAL", "forecolor", "#000044440000"), fcolor);
		mForeColor.setColor(new Color(&fcolor));

		
		Color.parse(Config.getString("TERMINAL", "backcolor",  "#000000000000"), bcolor);
		mBackColor.setColor(new Color(&bcolor));
	}

	override void Apply()
	{
		Config.setString("TERMINAL", "font", mFontButton.getFontName());

		Color f = new Color;

		mForeColor.getColor(f);

		Config.setString("TERMINAL", "forecolor", f.toString());
		Color b = new Color;

		mBackColor.getColor(b);
		Config.setString("TERMINAL", "backcolor", b.toString());
	}

		
}
