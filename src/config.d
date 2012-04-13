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
import std.file;


import glib.KeyFile;




class CONFIG
{
	string mCfgFile;                //name of the CONFIG file
	KeyFile	mKeyFile;               //CONFIG file object... didn't want dcore to depend on gtk+ libs, must fix

    alias mKeyFile this;            

    this()
    {
        mCfgFile = expandTilde("~/.neontotem/dcomposer/dcomposer.cfg");
        
        mKeyFile = new KeyFile;
    }

    void Engage(string[] CmdArgs)
    {

        string TmpForLog = " ";                 //can't pass a space as a commandline arg
        string openers;                         //put files on cmdline in ';' seperated list store in mKeyfile to be
                                                //read when Docman is Engaged
                                                
        
        getopt(CmdArgs, config.passThrough, "c|config", &mCfgFile, "l|log", &TmpForLog);


        if(!mCfgFile.exists)
        {
            {
            scope(failure)
            {
                Log.Entry("Unable to create configuration file: " ~ mCfgFile, "Error");
                return;
            }
            File tmp;
            tmp.open(mCfgFile, "w");
            tmp.write("[CONFIG]\nthis_file="~mCfgFile~"\n");
            
            }
        }

        mKeyFile.loadFromFile(mCfgFile, GKeyFileFlags.KEEP_COMMENTS);
        
        mKeyFile.setString("CONFIG", "this_file", mCfgFile);


        if(TmpForLog != " ") mKeyFile.setString("LOG","interim_log_file", TmpForLog);

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
            Default = Default.expandTilde();
            mKeyFile.setString(GroupName, Key, Default);
            //Save();
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
            //Save();
            return Default;
        }
        bool rVal = cast(bool)mKeyFile.getBoolean(GroupName, Key);

        return rVal;

    }

    int getInteger(string GroupName, string Key, int Default = 0)
    {
       scope(failure)
       {
           mKeyFile.setInteger(GroupName, Key , Default);
           //Save();
           return Default;
       }
       int rVal = mKeyFile.getInteger(GroupName,  Key);

       return rVal;
    }

    ulong getUint64(string GroupName, string Key, ulong Default = 0uL)
    {
        scope(failure)
        {
            mKeyFile.setUint64(GroupName, Key, Default);
            Save();
            return Default;
        }
        ulong rVal = mKeyFile.getUint64(GroupName, Key);

        return rVal;
    }

    string[] getKeys (string groupName)
    {
        scope (failure) return null;

        ulong waste;
        string[] rVal =  mKeyFile.getKeys(groupName, waste);
        return rVal;
    }

    void Reconfigure()
    {
        Reconfig.emit();
    }

    void PrepPreferences()
    {
        //preps a gui dialog to set all elements to keyfile values
        ShowConfig.emit();
    }
        
    mixin Signal!()ShowConfig;  //will be emitted before showing a gui pref dialog ... to set gui elements from keyfile
    mixin Signal!()Reconfig;    //emitted when keyfile changes warrent all modules to reconfigure them selves
    mixin Signal!()Saved;     

}

import dcore :Log;
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
	

	

	
