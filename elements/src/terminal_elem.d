module terminal_elem;

import std.file;

import dcore;
import ui;
import elements;


extern (C) string GetClassName()
{
    return "terminal_elem.TERMINAL";
}


class TERMINAL : ELEMENT
{
    private:
    
    Terminal        mVteTerm;
    Box             mBox;
    GPid            mShellPid;
    
    public:
    
    string Name()       {return "Terminal";}
    string Info()       {return "Integrated Terminal using libvte";}
    string Version()    {return "unversioned untested unshaven";}
    string License()    {return "Not sure quite yet";}
    string CopyRight()  {return "Yes it is";}
    string[] Authors()  {return ["Anthony Goins"];}


    
    void Engage()
    {
        auto userShell = Terminal.getUserShell();
        if(userShell is null) userShell = "/bin/sh";
        
        mBox = new Box(GtkOrientation.VERTICAL, 0);
        mVteTerm = new Terminal;
        
        
        
        
        
        mBox.packStart(mVteTerm, true, true, 0);
        mBox.showAll();
        ui.AddExtraPage(mBox, "Terminal");
        
        mVteTerm.spawnSync( VtePtyFlags.DEFAULT,
                            getcwd(),
                            [userShell],
                            [],
                            GSpawnFlags.DEFAULT,
                            null,
                            null,
                            mShellPid,
                            null);
        
        mVteTerm.watchChild(mShellPid);
        
        dwrite(mVteTerm.getEncoding(), " ", mVteTerm.getRewrapOnResize());
                            
        
        mVteTerm.addOnChildExited(delegate void(int exitStatus, Terminal term)
        {
            mVteTerm.spawnSync( VtePtyFlags.DEFAULT,
                getcwd(),
                [userShell],
                [],
                GSpawnFlags.DEFAULT,
                null,
                null,
                mShellPid,
                null);});

        Log.Entry("Engaged");
        
    }
    void Disengage()
    {
        ui.RemoveExtraPage(mBox);
        Log.Entry("Disengaged");
    }

    void Configure() {}
    PREFERENCE_PAGE PreferencePage() {return null;}


}
