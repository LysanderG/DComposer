module element_base;


import qore;
import elements;

extern(C) string GetElementName()
{
    return "element_base.BASE_ELEMENT";
}


class BASE_ELEMENT : ELEMENT
{
    void Engage(){Log.Entry("Engaged");}
    void Mesh(){Log.Entry("Meshed");}
    void Disengage(){Log.Entry("Disengaged");}

    void Configure(){Log.Entry("Configure??");}

    string Name(){return "Simple Interface".idup;}
    string Info(){return "Minimal example of the element interface".idup;}
    string Version(){return "unVersioned".idup;}
    string License(){return "unSpecified Open Source License".idup;}
    string CopyRight() {return "Of course Anthony Goins copy right 2021".idup;}
    string Authors() {return "Just me, and you".idup;}

 }
