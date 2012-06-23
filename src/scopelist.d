//      scopelist.d
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


module scopelist;

import ui;
import dcore;
import symbols;
import elements;

import autopopups;
import docman;
import document;


import std.stdio;
import std.ascii;
import std.string;
import std.conv;
import std.path;




import gsv.SourceView;
import gsv.SourceBuffer;

import gtk.TextIter;
import gtk.Widget;

import gdk.Rectangle;
import gtk.CheckButton;



class SCOPE_LIST : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;

    SCOPE_LIST_PAGE mPrefPage;
    bool		mEnabled;   //This is what mState should be for but mState (d)evolved  into an Engage/Disengage (read permanent) solution.
							//A superfluous solution at that.


	void Configure()
	{
		mEnabled = Config.getBoolean("SCOPE_LIST", "enabled", true);
	}

    void WatchForNewDocument(string EventId, DOCUMENT Doc)
    {
        if (Doc is null ) return;
        if ((extension(Doc.Name) == ".d") || (extension(Doc.Name) == ".di"))
        {   
			Doc.TextInserted.connect(&WatchDoc);
		}
    }

    void WatchDoc(DOCUMENT sv, TextIter ti, string text, SourceBuffer buffer)
    {
        int xpos, ypos;
        
        if (text != ".") return;
        if (!mEnabled) return;
        if (sv.Pasting) return;

        
        //pull out candidate
        TextIter WordStart = new TextIter;
        WordStart = GetCandidate(ti);
        string Candidate2 = WordStart.getText(ti);

        string Candidate = to!(string)(GetLongCandidate(ti));

        if(Candidate.length < 1) return;
        DSYMBOL[] possibles = Symbols.Match(Candidate);

        IterGetPostion(sv, ti, xpos, ypos);
        dui.GetAutoPopUps.CompletionPush(possibles, xpos, ypos, STATUS_SCOPE);
    }

    void IterGetPostion(DOCUMENT Doc, TextIter ti, out int xpos, out int ypos)
    {
        GdkRectangle gdkRect;
        int winX, winY, OrigX, OrigY;

        Rectangle LocationRect = new Rectangle(&gdkRect);
        Doc.getIterLocation(ti, LocationRect);
        Doc.bufferToWindowCoords(GtkTextWindowType.TEXT, gdkRect.x, gdkRect.y, winX, winY);
        Doc.getWindow(GtkTextWindowType.TEXT).getOrigin(OrigX, OrigY);
        xpos = winX + OrigX;
        ypos = winY + OrigY + gdkRect.height;
        int OrigXlen, OrigYlen;
        Doc.getWindow(GtkTextWindowType.TEXT).getSize(OrigXlen, OrigYlen);
        if((ypos + dui.GetAutoPopUps.Height) > (OrigY + OrigYlen))
        {
            ypos = ypos - gdkRect.height - dui.GetAutoPopUps.Height;
        }
        return;        
    }

    TextIter GetCandidate(TextIter ti)
    {
        bool GoForward = true;
        
        string growingtext;
        TextIter tstart = new TextIter;
        tstart = ti.copy();
        do
        {
            if(!tstart.backwardChar())
            {
                GoForward = false;
                break;
            }
            growingtext = tstart.getText(ti);
        }
        while( (isAlphaNum(growingtext[0])) || (growingtext[0] == '_') || (growingtext[0] == '.'));
        if(GoForward)tstart.forwardChar();
        
        return tstart;
        
    }

    dstring GetLongCandidate(TextIter ti)
    {

            
        dchar[127] Buffer;
        int index = 126;
        auto frontTI = ti.copy();
        frontTI.backwardChar(); //ti is already advanced past the '.'
        dchar CurChar = frontTI.getChar();
        //while pos is a idchar pos--
        //if pos == ) skip to matching (
        //if pos == whitespace skip to nextchar if nextchar != ) or . done
        //if pos == nonid done


		void SkipParens()
		{
			int Pdepth = 1;
			frontTI.backwardChar();//skip the first ).
			while( Pdepth > 0)
			{
				
				dchar tchar = frontTI.getChar();
				if (tchar == ')') Pdepth ++;
				if (tchar == '(') Pdepth --;
				if (!frontTI.backwardChar()) break;
			}
			CurChar = frontTI.getChar();                
		}
		void SkipSpaces()
		{
		}

        while(isLegalIdChar(CurChar))
        {
            index--;
            if(CurChar == ')') SkipParens();
            if( (CurChar == ' ') || (CurChar == '\t')) SkipSpaces();
            
            Buffer[index] = CurChar;
            if(!frontTI.backwardChar()) break;

            if(index < 1) break;
            CurChar = frontTI.getChar();
        }
        return Buffer[index .. $-1].idup;
    }

    bool isLegalIdChar(dchar character)
    {
        if (isAlphaNum(character)) return true;
        if (character == ')') return true;
        if (character == '.') return true;

        return false;
    }         

    public:
    
    this()
    {
        mName = "SCOPE_LIST";
        mInfo = "present all members of a scope for easy pickins";
        mState = false;

        mPrefPage = new SCOPE_LIST_PAGE;
    }

        
    @property string Name() { return mName;}
    @property string Information(){ return mInfo;}
    @property bool   State(){return mState;}
    @property void   State(bool nuState)
    {
        mState = nuState;
        
        if(mState)  Engage();
        else        Disengage();
    }

        

    void Engage()
    {
        
        dui.GetDocMan.Event.connect(&WatchForNewDocument);
        Config.Reconfig.connect(&Configure);

        Log.Entry("Engaged SCOPE_LIST element");
    }

    void Disengage()
    {
		dui.GetDocMan.Event.disconnect(&WatchForNewDocument);
		Config.Reconfig.disconnect(&Configure);
        Log.Entry("Disengaging SCOPE_LIST element");
    }


    PREFERENCE_PAGE GetPreferenceObject()
    {
        return mPrefPage;
    }
}

class SCOPE_LIST_PAGE : PREFERENCE_PAGE
{
	CheckButton 	mEnabled;


	this()
	{
		super("Elements", Config.getString("PREFERENCES", "glade_file_scope_list", "$(HOME_DIR)/scopelistpref.glade"));
		mEnabled = cast(CheckButton)mBuilder.getObject("checkbutton1");
		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setBoolean("SCOPE_LIST", "enabled", mEnabled.getActive());
	}

	override void PrepGui()
	{
		mEnabled.setActive(Config.getBoolean("SCOPE_LIST","enabled"));
	}
}
