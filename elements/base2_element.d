module base2_element;

import qore;
import ui;
import elements;

extern(C) string GetElementName()
{
    return "base2_element.BASE2";
}

class BASE2 :ELEMENT
{
    
    void Engage(){Log.Entry("Engaged 3");}
    void Mesh(){Log.Entry("Meshed");}
    void Disengage(){Log.Entry("Disengaged");}

    void Configure(){Log.Entry("Configure");}

    string Name(){return "BASE2".idup;}
    string Info(){return "Info stuff".idup;}
    string Version(){return "Current version".idup;}
    string License(){return "to kill".idup;}
    string CopyRight(){return "right now".idup;}
    string Authors(){return "me, billy, jim, evan".idup;}

    Dialog SettingsDialog()
    {
        return new MessageDialog(mMainWindow, DialogFlags.USE_HEADER_BAR, 
            MessageType.OTHER, ButtonsType.CLOSE, "my message");
    }
}
