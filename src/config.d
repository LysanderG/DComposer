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
import std.algorithm;
import std.process;

import core.stdc.stdlib;
import core.runtime;


import glib.KeyFile;

string DCOMPOSER_VERSION;
string DCOMPOSER_COPYRIGHT;

string HOME_DIR ;
string SYSTEM_DIR;


//creating an actual static this causes an error
//"Cycle detected between modules with ctors/dtors:"
//so I made this function and call it from dcore.this
void PseudoStaticThis()
{
	DCOMPOSER_VERSION = "0.01a";
	DCOMPOSER_COPYRIGHT = "Copyright 2011 Anthony Goins";
	HOME_DIR = "$(HOME_DIR)/";
	SYSTEM_DIR  = "$(SYSTEM_DIR)/";
}


class CONFIG
{
	string 	mCfgFile;               //name of the CONFIG file
	KeyFile	mKeyFile;               //CONFIG file object... didn't want dcore to depend on gtk+ libs, must fix
	bool	mShowHelp;				//show help and then exit		
    alias 	mKeyFile this;

    string	mHomeDir;				//this should be where user settings will be saved -->default ~/.config/dcomposer/
    string 	mSysDir;     			//this is where stuff the user shouldn't change will reside -->default /usr/local/
    bool	mInstalled;

    this()
    {
		mInstalled = true;
		mSysDir  = import("systemdir");  //prefix (id /usr /usr/local /opt or whatever
		mSysDir = buildNormalizedPath(mSysDir, "share/dcomposer/"); //now its pointed at our root!
		mHomeDir = std.path.expandTilde("~/.config/dcomposer");
		
		if(!exists(mSysDir))
		{
			mInstalled = false;
			mSysDir = absolutePath(dirName(Runtime.args[0]));  //not installed so lets work in binary's folder
		}

		if(!exists(mHomeDir))
		{
			if(mInstalled )
			{
				FirstUserRun();
			}
			else mHomeDir = absolutePath(dirName(Runtime.args[0]));
		}
		
        mCfgFile = ExpandPath("$(HOME_DIR)/dcomposer.cfg");
        mKeyFile = new KeyFile;
    }

    void Engage(string[] CmdArgs)
    {

        string TmpForLog = " ";                 //can't pass a space as a commandline arg
        string openers;                         //put files on cmdline in ';' seperated list store in mKeyfile to be
                                                //read when Docman is Engaged
                                                
        
        getopt(CmdArgs, config.passThrough, "c|config", &mCfgFile, "l|log", &TmpForLog, "help", &mShowHelp);

		if(mShowHelp){ShowHelp();}
		
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
			//guess I'm assuming here if it starts with '-' its a flag otherwise its a file to open
			//but... what about -c 
            if(filetoopen[0] != '-') openers ~= buildNormalizedPath((absolutePath(filetoopen))) ~ ";";
        }
        openers = openers.chomp(";");
        if(openers.length > 0)mKeyFile.setString("DOCMAN","files_to_open",openers);
        Log.Entry("Engaged CONFIG");

    }

    void Disengage()
    {
		Save();
        mKeyFile.free();
        Log.Entry("Disengaged config");
    }

    void Save()
    {
		scope (failure)
		{
			Log.Entry("Unable to save configuration file "~mCfgFile, "Error");
			return;
		}
		
        gsize len;
        string data = mKeyFile.toData(len);
        std.file.write(mCfgFile, data);
        Saved.emit();
    }

    string[] getStringList (string GroupName, string Key, string[] Default = [""])
    {
		gsize UnusedLength;
		scope(failure)
		{
			mKeyFile.setStringList(GroupName, Key, Default);
			return Default;
		}
		string[] rval = mKeyFile.getStringList(GroupName, Key, UnusedLength);
		return rval;
	}

    string getString(string GroupName, string Key, string Default = "")
    {
        scope (failure)
        {
            Default = ExpandPath(Default);
            mKeyFile.setString(GroupName, Key, Default);

            return Default;
        }
        string rVal  = mKeyFile.getString(GroupName, Key);

        return rVal; 
    }

    void setString(string GroupName, string Key, string Value)
    {
		mKeyFile.setString(GroupName, Key,ExpandPath( Value));
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
            return Default;
        }
        ulong rVal = mKeyFile.getUint64(GroupName, Key);
        return rVal;
    }

    string[] getKeys (string groupName)
    {
        scope (failure) return null;

        gsize waste;
        string[] rVal =  mKeyFile.getKeys(groupName, waste);
        return rVal;
    }

    void Reconfigure()
    {
        mCfgFile = getString("CONFIG", "this_file", mCfgFile);
        Save();
        Reconfig.emit();
    }

    void PrepPreferences()
    {
        //preps a gui dialog to set all elements to keyfile values
        ShowConfig.emit();
    }

    void ShowHelp()
    {
		writeln("DComposer a Naive IDE for the D programming Language");
		writeln("Version :",DCOMPOSER_VERSION);
		writeln(DCOMPOSER_COPYRIGHT);
		writeln();
		writeln("Usage:");
		writeln("  dcomposer [OPTION...] [FILES...]");
		writeln();
		writeln("OPTIONS");
		writeln("  -c,  --config=CFG_FILE    specify session configuration file");
		writeln("                            (~/.neontotem/dcomposer/dcomposer.cfg is default)");
		writeln("  -l,  --log=LOG_FILE       specify session log file");
		writeln("                            (~/.neontotem/dcomposer/dcomposer.log is default)");
		writeln("  -h, --help                show this help message");
		writeln("\nFILES");
		writeln("Any text files to open for editing.  Must be valid utf8 encoded files for this version");
		writeln("Also at this time project files are only opened as text files");
		exit(0);
	}


	
	string ExpandSysDir(string Input) { return buildNormalizedPath(mSysDir, Input);}

	string ExpandHomeDir(string Input) {return buildNormalizedPath(mHomeDir, Input);}
	string ExpandPath(string Input)
	{
		if (Input.skipOver(HOME_DIR))
		{
			return ExpandHomeDir(Input);
		}
		if (Input.skipOver(SYSTEM_DIR))
		{
			return ExpandSysDir(Input);
		}
		Input = expandTilde(Input);

		return Input;
	}


	void FirstUserRun()
	{
		//copy system directory folders to local directory
		string src = buildPath(mSysDir, "*");
		string cpCommand = "cp -r " ~ src ~ " " ~ mHomeDir;
		shell("mkdir " ~ mHomeDir);
		writeln(shell(cpCommand));
		FirstRun.emit();
	}
		


		
    mixin Signal!()ShowConfig;  //will be emitted before showing a gui pref dialog ... to set gui elements from keyfile
    mixin Signal!()Reconfig;    //emitted when keyfile changes warrent all modules to reconfigure them selves
    mixin Signal!()Saved;
    mixin Signal!()FirstRun;	//maybe show a welcome screen or allow preconfiguration or whatever

}


import dcore :Log;


	
