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
    //log --log has its own signal -- created before transmittter is
    
    //message -> mainly toolchain errors but could be for anything
    //first string is format type (standard error, 
    mixin Signal!(string , string ) Message;
    
    //docman
    mixin Signal!(DOCMAN_EVENT, string ) DocManEvent;
    //document
    mixin Signal!(DOC_IF, DOC_EVENT, string) DocEvent;

    //ui_book
    mixin Signal!(string) DocStatusLine;
    mixin Signal!(DOC_IF) DocClose;
    
    //project
    mixin Signal!(PROJECT, PROJECT_EVENT,string) ProjectEvent;
    
}
