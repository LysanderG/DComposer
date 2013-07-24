//      indent.d
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

module indent;

import docman;
import document;
import elements;
import ui;
import dcore;

import std.signals;
import std.conv;
import std.stdio;
import std.string;

import gtk.TextBuffer;
import gtk.TextIter;
import gtk.CheckButton;
import gtk.Label;

import gsv.SourceView;
import gsv.SourceBuffer;

class BRACE_INDENT : ELEMENT
{
    private:

    bool mState;

    BRACE_INDENT_PREF mPrefPage;
    bool mEnabled;


    void CatchNewDocs(string EventId, DOCUMENT nu_doc)
    {
        auto docX = cast (DOCUMENT) nu_doc;

        docX.NewLine.connect(&CatchNewLine);
        docX.CloseBrace.connect(&CatchCloseBrace);
    }

    void CatchNewLine(TextIter ti, string text, TextBuffer Buffer)
    {
        //this function indexes strings. (is "indexes" a word??)
        //I'm no unicode guru (obviously) but I don't think indexing strings does what us simple minded people might assume
        //so be on the look out for strange behavior
        //emitter takes care of revalidating ti

		if(!mEnabled) return;
        auto tstart =  ti.copy;

        tstart.backwardLine;
        string x = tstart.getText(ti);
        if (x.length < 2) return; //just a new line ?? or totally blank line(is that possible?)

        if(x[$-2] == '{')// indent!!
        {
            Buffer.insert(ti, "\t");
            return;
        }

        return;
    }

    void CatchCloseBrace(TextIter ti, string text, TextBuffer Buffer)
    {
		//omg could I understand this less??

		//ok make a textiter tstart that sets at beginning of line --> ti == where } was inserted
        auto tstart = ti.copy;
        tstart.setLineOffset(0);

        //line = linetext[0..}] get it?
        auto line = tstart.getText(ti);

        //hmm remove leading and trailing whitespace (result is tossed)
        //simply -> if there is a non whitespace between 0 and } bail.  We wont unindent the line
        if(strip(line).length > 1)return;

		//if line[0] is a tab remove it ... unindenting (word?) done good bye
        if(line[0] == '\t')
        {
            ti.setLineOffset(1);
            Buffer.delet(tstart, ti);
            return;
        }

        auto twidth = Config.getInteger("DOCMAN", "tab_width", 4);

        //ok if not enough space to unindent don't ... bail
        if(line.length < twidth) return;

        //?? so much work to get notabs to equal number of spaces in a tab
        char[] notabs;
        notabs.length = twidth;
        foreach (ref c; notabs) c = ' ';

        //removes spaces equivalent to tab
        //but ... what if line[0..}] == "__t__" (_ = space t = tab)
        if(line[0..twidth] == notabs)
        {
            ti.setLineOffset(twidth);
            Buffer.delet(tstart, ti);
            return;
        }
    }

protected:
	void SetPagePosition(UI_EVENT uie)
	{}
	void Configure()
    {
		mEnabled = Config.getBoolean("BRACE_INDENT", "enabled", true);
	}

public:

    @property string Name() {return "BRACE_INDENT";}
    @property string Information(){return `Adjusts indentation following braces "{}".  Not related to Auto Indentation.`;}
    @property bool   State() {return mState;}
    @property void   State(bool nuState){mState = nuState;}


    void Engage()
    {
        mState = true;
        mPrefPage = new BRACE_INDENT_PREF;
        Configure();

        Config.Reconfig.connect(&Configure);
        dui.GetDocMan.Event.connect(&CatchNewDocs);
        Log.Entry("Engaged "~Name()~"\t\telement.");
    }



    void Disengage()
    {
        mState = false;
        Log.Entry("Disengaged "~Name()~"\t\telement.");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return mPrefPage;
    }
}


class BRACE_INDENT_PREF : PREFERENCE_PAGE
{
	CheckButton		mEnabled;

	this()
	{
		//using same simple glade file for proview  -- maybe change name to generice simple glade ??
		super("Elements", Config.getString("PREFERENCES", "glade_file_brace_indent", "$(HOME_DIR)/glade/proviewpref.glade"));
		mEnabled = cast (CheckButton)mBuilder.getObject("checkbutton1");
		Label  x = cast (Label)      mBuilder.getObject("label1");
		x.setMarkup("<b>Brace Indentation :</b>");

		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setBoolean("BRACE_INDENT", "enabled", mEnabled.getActive());
	}

	override void PrepGui()
	{
		mEnabled.setActive(Config.getBoolean("BRACE_INDENT", "enabled", true));
	}
}
