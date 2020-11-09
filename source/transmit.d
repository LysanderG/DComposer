module transmit;

import std.signals;

import qore;

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
    

    
    

}
