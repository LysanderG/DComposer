module terminal;

import dcore;
import ui;
import elements;
import ui_preferences;

import vte.Terminal;

import gtk.Box;
import gtk.ScrolledWindow;
import gtk.Builder;
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.Entry;
import gtk.ColorButton;
import gtk.FontButton;
import gtk.Grid;
import gtk.Widget;
import gtk.Frame;

import gdk.RGBA;
import gdk.Color;

import std.traits;
import std.file;

extern (C) string GetClassName()
{
	return "terminal.TERMINAL";
}


class TERMINAL : ELEMENT
{
	private:

	Box				mRoot;
	ScrolledWindow	mScroll;
	Terminal		mTerminal;

	void ResetTerminal()
	{
		GPid childPid;
		mTerminal.forkCommandFull (VtePtyFlags.DEFAULT, getcwd(), ["/bin/bash"], [], GSpawnFlags.DEFAULT, null, null, childPid);
	}

	void WatchProjectEvents(PROJECT_EVENT event)
	{
		if(event == PROJECT_EVENT.FOLDER) mTerminal.feedChild("cd " ~ Project.Folder() ~ ";clear\n");
	}

	public:

	string Name() { return "Terminal";}
	string Info() { return "an Embedded terminal";}
	string Version() {return "00.01";}
	string CopyRight() {return "Anthony Goins © 2014";}
	string License() {return "New BSD license";}
	string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}

	void Engage()
	{
		mRoot = new Box(Orientation.VERTICAL,0);
		mScroll = new ScrolledWindow;

		mTerminal = new Terminal;
		//Configure();

		mScroll.add(mTerminal);
		mRoot.packStart(mScroll, 1, 1, 0);

		mRoot.showAll();
		AddExtraPage(mRoot, "Terminal");

		GPid childPid;
		mTerminal.forkCommandFull (VtePtyFlags.DEFAULT, getcwd(), ["/bin/bash"], [], GSpawnFlags.DEFAULT, null, null, childPid);

		mTerminal.addOnChildExited(delegate void(Terminal){ResetTerminal();});
		mTerminal.feedChild("clear\n");

		Configure();

		Project.Event.connect(&WatchProjectEvents);
		Log.Entry("Engaged");
	}


	void Disengage()
	{

		RemoveExtraPage(mRoot);

		mRoot.destroy();

		Log.Entry("Disengage");
	}

	void Configure()
	{

		long scrollBackLines = Config.GetValue("terminal", "scroll_back_lines", -1);
		bool visibleBell = Config.GetValue("terminal", "visible_bell", true);
		bool allowBold = Config.GetValue("terminal", "allow_bold", true);
		bool scrollOnOutput = Config.GetValue("terminal", "scroll_on_output", true);
		bool scrollOnKey = Config.GetValue("terminal", "scroll_on_key", true);
		string colorBold = Config.GetValue("terminal", "color_bold", "#FFFF00");
		string colorFore = Config.GetValue("terminal", "color_fore", "#008000");
		string colorBack = Config.GetValue("terminal", "color_back", "#4D4D4D");
		string colorHilite=Config.GetValue("terminal", "color_hilite", "#ADD8E6");
		string font = Config.GetValue("terminal", "font", "Inconsolata Bold 8");


		mTerminal.setScrollbackLines(scrollBackLines);

		RGBA fore = new RGBA;
		fore.parse(colorFore);

		RGBA back = new RGBA;
		back.parse(colorBack);


		mTerminal.setColorsRgba(fore, back, cast(RGBA)null, 0L);
		mTerminal.setFontFromString(font);
	}

	PREFERENCE_PAGE PreferencePage()
	{
		PREFERENCE_PAGE mtmp = new UI_TERMINAL_PREFERENCE_PAGE;
		return mtmp;
	}
}


final class UI_TERMINAL_PREFERENCE_PAGE : PREFERENCE_PAGE
{
	this()
	{
		Color xcolor = new Color; //for use converting color from string

		auto builder = new Builder;
		builder.addFromFile(Config.GetValue("terminal", "glade_file", SystemPath("elements/resources/pref_terminal.glade")));

		SplashWidget = cast(Frame)builder.getObject("frame1");

		ContentWidget = cast(Grid)builder.getObject("grid1");
		Title = "Terminal Preferences";
		auto ScrollLimit = cast(SpinButton)builder.getObject("scrollspbtn");
		auto VisibleBell = cast(CheckButton)builder.getObject("visiblebellchkbtn");
		auto AllowBold = cast(CheckButton)builder.getObject("allowboldchkbtn");
		auto ScrollOutPut = cast(CheckButton)builder.getObject("scrolloutputchkbtn");
		auto ScrollInput = cast(CheckButton)builder.getObject("scrollinputchkbtn");
		auto BoldColor = cast(ColorButton)builder.getObject("boldcolorbtn");
		auto NormalColor = cast(ColorButton)builder.getObject("normalcolorbtn");
		auto BackColor = cast(ColorButton)builder.getObject("backcolorbtn");
		auto HiLiteColor = cast(ColorButton)builder.getObject("hilitecolorbtn");
		auto ShellCmd = cast(Entry)builder.getObject("shellentry");
		auto Font = cast(FontButton)builder.getObject("fontbtn");




		ScrollLimit.setValue(Config.GetValue!int("terminal", "scroll_back_lines"));
		ScrollLimit.addOnChangeValue (delegate void(GtkScrollType, SpinButton)
		{
			Config.SetValue("terminal", "scroll_back_lines", ScrollLimit.getValueAsInt());
		});
		VisibleBell.setActive(Config.GetValue!bool("terminal", "visible_bell"));
		VisibleBell.addOnToggled (delegate void(ToggleButton)
		{
			Config.SetValue("terminal", "visible_bell", VisibleBell.getActive());
		});
		AllowBold.setActive(Config.GetValue!bool("terminal", "allow_bold"));
		AllowBold.addOnToggled (delegate void(ToggleButton)
		{
			Config.SetValue("terminal", "allow_bold", AllowBold.getActive());
		});
		ScrollOutPut.setActive(Config.GetValue!bool("terminal", "scroll_on_output"));
		ScrollOutPut.addOnToggled (delegate void(ToggleButton)
		{
			Config.SetValue("terminal", "scroll_on_output", ScrollOutPut.getActive());
		});
		ScrollInput.setActive(Config.GetValue!bool("terminal", "scroll_on_key"));
		ScrollInput.addOnToggled (delegate void(ToggleButton)
		{
			Config.SetValue("terminal", "scroll_on_key", ScrollInput.getActive());
		});

		xcolor.parse(Config.GetValue!string("terminal", "color_bold"),xcolor);
		BoldColor.setColor(xcolor);
		BoldColor.addOnColorSet (delegate void(ColorButton cb)
		{
			auto color = new Color;
			cb.getColor(color);
			Config.SetValue("terminal", "color_bold", color.toString);
		});
		xcolor.parse(Config.GetValue!string("terminal", "color_fore"),xcolor);
		NormalColor.setColor(xcolor);
		NormalColor.addOnColorSet (delegate void(ColorButton cb)
		{
			auto color = new Color;
			cb.getColor(color);
			Config.SetValue("terminal", "color_fore", color.toString);
		});
		xcolor.parse(Config.GetValue!string("terminal", "color_back"),xcolor);
		BackColor.setColor(xcolor);
		BackColor.addOnColorSet (delegate void(ColorButton cb)
		{
			auto color = new Color;
			cb.getColor(color);
			Config.SetValue("terminal", "color_back", color.toString);
		});
		xcolor.parse(Config.GetValue!string("terminal", "color_hilite"),xcolor);
		HiLiteColor.setColor(xcolor);
		HiLiteColor.addOnColorSet (delegate void(ColorButton cb)
		{
			auto color = new Color;
			cb.getColor(color);
			Config.SetValue("terminal", "color_hilite", color.toString);
		});
		Font.setFontName(Config.GetValue!string("terminal", "font"));
		Font.addOnFontSet (delegate void(FontButton)
		{
			Config.SetValue("terminal", "font", Font.getFontName());
		});


	}
}
