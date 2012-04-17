//      element.d
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

module elements;

import std.array;
import std.file;
import std.string;


import dcore;
import ui;
public import gtk.Frame;

interface ELEMENT
{
    @property string Name();
    @property string Information();
    @property bool   State();
    @property void   State(bool);

    void Engage();

    void Disengage();

    PREFERENCE_PAGE GetPreferenceObject();
    
}


ELEMENT[string] mElements;

void Engage()
{
    AcquireElements();

    Log.Entry("Engaging Elements ...");
    foreach(E; mElements) E.Engage();
}

void Disengage()
{
    Log.Entry("Disengaging Elements ...");
    foreach_reverse(E; mElements) E.Disengage();
}

void AcquireElements()
{
    ELEMENT tmp;
    
    string elementlist = readText(Config.getString("ELEMENTS","element_list", "/home/anthony/projects/dcomposer2/elementlist"));
        
    foreach (line; elementlist.splitLines())
    {
        line = removechars!(string)(line, whitespace);
        if (line.startsWith('#')) continue;
        if (line.length < 1) continue;

        tmp = cast(ELEMENT)Object.factory(line);
        if(tmp is null) Log.Entry("Failed to Acquire " ~ line ~ " element!", "Error");
        else
        {
            Log.Entry("Acquired " ~ line ~ " element.");
            mElements[tmp.Name] = tmp;
        }
    }
}




/* old acquire elements
void AcquireElements()
{
    //redo this function when I learn what the hell I'm doing

    //element number one logui
    ELEMENT tmp = cast(ELEMENT)Object.factory("logui.LOG_UI");
    if(tmp is null) Log.Entry("Failed to Engage LOG_UI","Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;
    

    tmp = cast(ELEMENT)Object.factory("searchui.SEARCH_UI");
    if(tmp is null) Log.Entry("Failed to Engage SEARCH_UI","Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;


    tmp = cast(ELEMENT)Object.factory("projectdui.PROJECT_UI");
    if(tmp is null) Log.Entry("Failed to Engage PROJECT_UI", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;

    tmp = cast(ELEMENT)Object.factory("symbolview.SYMBOL_VIEW");
    if(tmp is null) Log.Entry("Failed to Engage SYMBOL_VIEW", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;

    tmp = cast(ELEMENT)Object.factory("indent.BRACE_INDENT");
    if(tmp is null) Log.Entry("Failed to Engage BRACE_INDENT", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;

    tmp = cast(ELEMENT)Object.factory("symcompletion.SYMBOL_COMPLETION");
    if(tmp is null) Log.Entry("Failed to Engage SYMBOL_COMPLETTION", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;
    
    tmp = cast(ELEMENT)Object.factory("scopelist.SCOPE_LIST");
    if(tmp is null) Log.Entry("Failed to Engage SCOPE_LIST", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;

    tmp = cast(ELEMENT)Object.factory("calltips.CALL_TIPS");
    if(tmp is null) Log.Entry("Failed to Engage CALL_TIPS", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;

    tmp = cast(ELEMENT)Object.factory("terminalui.TERMINAL_UI");
    if(tmp is null) Log.Entry("Failed to Engage TERMINAL_UI", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;

    tmp = cast(ELEMENT)Object.factory("proview.PROJECT_VIEW");
    if(tmp is null) Log.Entry("Failed to Engage PROJECT_VIEW", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;

    tmp = cast(ELEMENT)Object.factory("dirview.DIR_VIEW");
    if(tmp is null) Log.Entry("Failed to Engage DIR_VIEW", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;   

    tmp = cast(ELEMENT)Object.factory("historyview.HISTORY_VIEW");
    if(tmp is null) Log.Entry("Failed to Engage HISTORY_VIEW", "Error");
    if(tmp !is null) mElements[tmp.Name] = tmp;   

    

    //next'll be ??? projectui or dirview or search or indentation or symview or docview or ....   
}    
*/
