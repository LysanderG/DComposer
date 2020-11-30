module transmit;

import std.signals;

import qore;
import project;

public:

TRANSMITTER Transmit;

void Engage(string[] args)
{
    Transmit = new TRANSMITTER;
    Log.Entry("Engaged");
}

void Mesh()
{
    Log.Entry("Meshed");
}

void Disengage()
{
    Log.Entry("Disengaged");
}
class TRANSMITTER
{
    //ui_preferences
    mixin Signal!() SigUpdateAppPreferencesUI;
    mixin Signal!() SigUpdateAppPreferencesOptions;
    //log
    
    //message -> mainly toolchain errors but could be for anything
    //first string is format type (standard error, 
    mixin Signal!(string , string ) Message;
    
    //document
    mixin Signal!(string) DocStatusLine;
    mixin Signal!(DOC_IF) DocClose;
    
    //project
    mixin Signal!(PROJECT, PROJECT_EVENT) ProjectEvent;
    
}
