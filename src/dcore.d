//      core.d
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



//darn core is already taken!
module dcore;


import config;
import log;
import project;
import symbols;


public import search;


import std.stdio;

private :

CONFIG		mConfig;
LOG 		mLog;
PROJECT 	mProject;
SYMBOLS	    mSymbols;


static this()
{
    mConfig	    = new CONFIG;
	mLog	    = new LOG;
	mProject    = new PROJECT;
	mSymbols    = new SYMBOLS;

}

static ~this()
{
    delete mLog;
}

public:

void Engage(string[] CmdArgs)
{
	mConfig	    .Engage(CmdArgs);
	mLog		.Engage();
	mProject    .Engage();
	mSymbols    .Engage();


    Log().Entry("Engaged dcore");
}

void Disengage()
{

	mSymbols .Disengage();
	mProject .Disengage();
	mConfig  .Disengage();
    
    Log      .Entry("Disengaged dcore");
	mLog     .Disengage();
}

CONFIG		Config() {return mConfig;}
LOG 		Log()    {return mLog;}
PROJECT 	Project(){return mProject;}
SYMBOLS		Symbols(){return mSymbols;}

