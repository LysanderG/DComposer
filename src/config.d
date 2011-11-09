//      config.d
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


module config;

import std.stdio;
import std.signals;
import std.getopt;
import std.string;
import std.path;

import glib.KeyFile;


class CONFIG
{
	string mCfgFile;
	KeyFile	mKeyFile;

    alias mKeyFile this;

    this()
    {
        mCfgFile = "/home/anthony/.neontotem/dcomposer/dcomposer.cfg";
        mKeyFile = new KeyFile;
    }

    void Engage(string[] CmdArgs)
    {

        string TmpForLog = " ";
        string openers;
        
        getopt(CmdArgs, config.passThrough, "c|config", &mCfgFile, "l|log", &TmpForLog);

        mKeyFile.loadFromFile(mCfgFile, GKeyFileFlags.KEEP_COMMENTS);

        mKeyFile.setString("CONFIG", "this_file",mCfgFile);

        //getopt(CmdArgs,std.getopt.config.passThrough);
        if(TmpForLog != " ") mKeyFile.setString("LOG","log_file", TmpForLog);

        foreach(filetoopen; CmdArgs[1..$])
        {
            if(filetoopen[0] != '-') openers ~= buildNormalizedPath((absolutePath(filetoopen))) ~ ";";
        }
        openers = openers.chomp(";");
        if(openers.length > 0)mKeyFile.setString("DOCMAN","files_to_open",openers);

    }

    void Disengage()
    {
        ulong len;
        
        string data = mKeyFile.toData(len);
        std.file.write(mCfgFile, data);
        mKeyFile.free();
    }

    void Save()
    {
        ulong len;
        string data = mKeyFile.toData(len);
        std.file.write(mCfgFile, data);
        Saved.emit();
    }

    string getString(string GroupName, string Key, string Default = "")
    {
        scope (failure)
        {
            mKeyFile.setString(GroupName, Key, Default);
            return Default;
        }
        string rVal  = mKeyFile.getString(GroupName, Key);

        return rVal; 
    }

    bool getBoolean(string GroupName, string Key, bool Default = false)
    {

        scope(failure)
        {
            mKeyFile.setBoolean(GroupName, Key, Default);
            return Default;
        }
        bool rVal = cast(bool)mKeyFile.getBoolean(GroupName, Key);

        return rVal;

    }

    int getInteger(string GroupName, string Key, int Default = 0)
    {
       int rVal = mKeyFile.getInteger(GroupName,  Key);
       scope(failure)
       {
           mKeyFile.setInteger(GroupName, Key , Default);
           return Default;
       }
       return rVal;
    }
        
        


    mixin Signal!()Saved;     

}


/*
 * list of all the configuration stuff i can think of (as i think of it)
 *
 * config "CONFIG"
 * 		configuration file <- the one that really counts
 * 		verbose?
 * 		quiet?
 *		version?
 * 
 * log  "LOG"
 * 		logfile
 * 		logfile size before overwriting it
 * 		logbuffer size / or how often to flush the buffer
 *
 * 
 * project "DPROJECT"
 * 		default file project
 *      project version
 *      flagfile ,, the json file`
 *
 * symbols "SYMBOLS"
 * 		sure there will be plenty here
 *      key=file
 *      std=~/.neontotem/dcomposer/phobos.tags
 *      gtk=~/.neontotem/dcomposer/gtk.tags
 *
 * ----------------------------
 * ui   "UI"
 * 		mainbuilder file
 * 		lotsa gui stuff --- sizes of all the components and splitter windows ....
 * 		which actions to add to toolbar
 * 
 * docman "DOCMAN"
 * 		files_to_open  list of commnand line files to open
 *      files_left_open list of fiies from last session
 *
 *
 *
 * ok nevermind this ... see ~/.neontotem/dcomposer/domposer.log
 */
	

	

	
