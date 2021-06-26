module base_element;



import qore;
import ui;
import elements;

extern(C) string GetElementName()
{
    return "base2_element.BASE2";
}

class BASE :ELEMENT
{
    
    void Engage(){Log.Entry("Engaged 0");}
    void Mesh(){Log.Entry("Meshed");}
    void Disengage(){Log.Entry("Disengaged");}

    void Configure(){Log.Entry("Configure");}

    string Name(){return "BASE 0".idup;}
    string Info(){return "Helpful information about this element".idup;}
    string Version(){return "Nightly Build".idup;}
    string License(){return "to kill".idup;}
    string CopyRight(){return "reserved".idup;}
    string Authors(){return "Lysander".idup;}

    Dialog SettingsDialog()
    {
        dwrite("hi");
        return new MessageDialog(mMainWindow, DialogFlags.MODAL, MessageType.OTHER, ButtonsType.CLOSE, "Hey this is working");
    }
}
