module test;

import dcore;
import elements;
import ui_preferences;


import std.stdio;
import std.traits;


export extern(C) string GetClassName()
{
     return fullyQualifiedName!TEST;
}

class TEST :ELEMENT
{
     void Engage()
     {
          Log.Entry("Engaged");
     }


    void Disengage()
    {
          Log.Entry("Disenaged");
    }

    void Configure(){writeln("configured");}
	string Name (){return "TEST " ~ fullyQualifiedName!this;}
    string Info(){return "just a test case dude";}
	string Version() {return "00.01";}
	string CopyRight() {return "Anthony Goins © 2014";}
	string License() {return "New BSD license";}
	string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}
	PREFERENCE_PAGE PreferencePage(){return null;}
}
