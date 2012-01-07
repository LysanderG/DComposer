//      dcomposer.d
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


///hello
module dcomposer;

import core.memory;
import std.stdio;



import dcore;
import ui;
import elements;


int main(string[] args)
{
    //GC.disable();
    //scope(exit) Log().Flush();

	dcore.Engage(args);
	dui.Engage(args);
	elements.Engage();

	dui.Run();

    
    
	elements.Disengage();
	dui.Disengage();
	dcore.Disengage();

    //GC.enable();
    scope(exit)Log().Flush();
	return 0;
}
