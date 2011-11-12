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

import gsv.SourceView;
import gsv.SourceBuffer;

class BRACE_INDENT : ELEMENT
{
    private:

    bool mState;

    void CatchNewDocs(DOCUMENT_IF nu_doc)
    {
        auto docX = cast (DOCUMENT) nu_doc;

        docX.NewLine.connect(&CatchNewLine);
        docX.CloseBrace.connect(&CatchCloseBrace);
    }

    void CatchNewLine(TextIter ti, string text, TextBuffer Buffer)
    {
        //this function indexes strings. (is "indexes" a word??)
        //I'm no unicode guru (obviously) but I don't think indexing strings does what us simpled minded people might assume
        //so be on the look out for strange behavior
        //emiter takes care of revalidating ti

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
        auto tstart = ti.copy;
        tstart.setLineOffset(0);
        
        auto line = tstart.getText(ti);
        if(strip(line).length > 1)return;

        if(line[0] == '\t')
        {
            ti.setLineOffset(1);
            Buffer.delet(tstart, ti);
            return;
        }
        auto twidth = Config.getInteger("DOCMAN", "tab_width");
        if(line.length < twidth) return;
        char[] notabs;
        notabs.length = twidth;
        foreach (ref c; notabs) c = ' ';
        if(line[0..twidth] == notabs)
        {
            ti.setLineOffset(twidth);
            Buffer.delet(tstart, ti);
            return;
        }       
    }

    public:
    
    @property string Name() {return "BRACE_INDENT";}
    @property string Information(){return "automatically indents new lines follow an open '{' and unindents prior to '}\n'";}
    @property bool   State() {return mState;}
    @property void   State(bool nuState){mState = nuState;}
    

    void Engage()
    {
        mState = true;
        dui.GetDocMan.Appended.connect(&CatchNewDocs);
        Log.Entry("Engaged BRACE_INDENT element");
    }

    

    void Disengage()
    {
        mState = false;
        Log.Entry("Disengaged BRACE_INDENT element");
    }
}    
