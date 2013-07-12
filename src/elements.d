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

import std.stdio;
import std.array;
import std.file;
import std.string;
import std.parallelism;


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
    Log.Entry("Elements Engaged !!!");
}

void Disengage()
{
    Log.Entry("Disengaging Elements ...");
    foreach_reverse(E; mElements) E.Disengage();
}

void AcquireElements()
{

    string elementlist = readText(Config.getString("ELEMENTS","element_list", "$(HOME_DIR)/elementlist"));
    foreach (line; (elementlist.splitLines()))
    {
		ELEMENT tmp = null;
        line = removechars!(string)(line, std.ascii.whitespace);
        if (line.startsWith('#')) continue;
        if (line.length < 1) continue;
        tmp = cast(ELEMENT)Object.factory(line);

        if(tmp is null) Log.Entry("AcquireElements : Failed to Acquire " ~ line ~ " element!", "Error");
        else
        {
            Log.Entry("Acquired " ~ line ~ " element.");
            mElements[tmp.Name] = tmp;
            Log.Entry("  :>" ~ tmp.Information);
        }
    }
}

