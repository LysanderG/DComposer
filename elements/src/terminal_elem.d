module terminal_elem;

import std.file;

import dcore;
import ui;
import ui_preferences;
import elements;

import pango.PgFontDescription;


extern (C) string GetClassName()
{
    return "terminal_elem.TERMINAL";
}


class TERMINAL : ELEMENT
{
    private:
    
    Terminal        mVteTerm;
    ScrolledWindow  mParent;
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
        
        mParent = new ScrolledWindow;
        mVteTerm = new Terminal;
        
        
        
        
        
        mParent.add(mVteTerm);
        mParent.showAll();
        ui.AddExtraPage(mParent, "Terminal");
        
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
                            
        Configure();
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
        ui.RemoveExtraPage(mParent);
        Log.Entry("Disengaged");
    }

    void Configure()
    {
        auto allowBold = Config.GetValue("terminal_elem", "allow_bold", true);
        auto colorBackground = Config.GetValue("terminal_elem", "color_background", "#000000");
        auto colorBold = Config.GetValue("terminal_elem", "color_bold", "#00FFFF");
        auto colorCursor = Config.GetValue("terminal_elem", "color_cursor", "#FFFFFF");
        auto colorForeground = Config.GetValue("terminal_elem", "color_foreground", "#44AA44");
        auto font = Config.GetValue("terminal_elem", "font", "terminus 16");
        
        mVteTerm.setAllowBold(allowBold);
        auto backgroundColor = new RGBA;
        backgroundColor.parse(colorBackground);
        auto boldColor = new RGBA;
        boldColor.parse(colorBold);
        auto cursorColor = new RGBA;
        cursorColor.parse(colorCursor);
        auto foregroundColor = new RGBA;
        foregroundColor.parse(colorForeground);
        
        
        mVteTerm.setColorBackground(backgroundColor);
        mVteTerm.setColorBold(boldColor);
        mVteTerm.setColorCursor(cursorColor);
        mVteTerm.setColorForeground(foregroundColor);
        
        mVteTerm.setFont(PgFontDescription.fromString(font));
    }
    PREFERENCE_PAGE PreferencePage() {return new TERMINAL_ELEMENT_PREFERENCE_PAGE;}


}

final class TERMINAL_ELEMENT_PREFERENCE_PAGE : PREFERENCE_PAGE
{
    private:
    
    ColorButton backgroundColor;
    ColorButton foregroundColor;
    ColorButton boldColor;
    ColorButton cursorColor;
    FontButton  textFont;
    
    public:
    this()
    {
        Title = "Terminal Preferences";
        SplashWidget = null;
        
        auto termBuilder = new Builder;
        termBuilder.addFromFile(SystemPath(Config.GetValue("terminal_elem", "glade_file", "elements/resources/terminal_elem_pref.glade")));
        
        ContentWidget = cast(Grid)termBuilder.getObject("grid1");
        
        backgroundColor =   cast(ColorButton)termBuilder.getObject("colorbutton1");
        foregroundColor =   cast(ColorButton)termBuilder.getObject("colorbutton4");
        boldColor =         cast(ColorButton)termBuilder.getObject("colorbutton2");
        cursorColor =       cast(ColorButton)termBuilder.getObject("colorbutton3");
        textFont =          cast(FontButton)termBuilder.getObject("fontbutton1");
        
        auto InitialColors = new RGBA;
        
        
        InitialColors.parse(Config.GetValue("terminal_elem","color_background", "#000000"));
        backgroundColor.setRgba(InitialColors);
        backgroundColor.addOnColorSet(delegate void( ColorButton cb)
        {
            RGBA color;
            cb.getRgba(color);            
            Config.SetValue("terminal_elem", "color_background", color.toString());
        });
                
        InitialColors.parse(Config.GetValue("terminal_elem","color_foreground", "#00FFFF"));
        foregroundColor.setRgba(InitialColors);
        foregroundColor.addOnColorSet(delegate void( ColorButton cb)
        {
            RGBA color;
            cb.getRgba(color);            
            Config.SetValue("terminal_elem", "color_foreground", color.toString());
        });
                
        InitialColors.parse(Config.GetValue("terminal_elem","color_bold", "#FFFFFF"));
        boldColor.setRgba(InitialColors);
        boldColor.addOnColorSet(delegate void( ColorButton cb)
        {
            RGBA color;
            cb.getRgba(color);            
            Config.SetValue("terminal_elem", "color_bold", color.toString());
        });
                
        InitialColors.parse(Config.GetValue("terminal_elem","color_cursor", "#0F0F0F"));
        cursorColor.setRgba(InitialColors);
        cursorColor.addOnColorSet(delegate void( ColorButton cb)
        {
            RGBA color;
            cb.getRgba(color);            
            Config.SetValue("terminal_elem", "color_cursor", color.toString());
        });
        
        textFont.setFont(Config.GetValue("terminal_elem", "font", "terminus 16"));
        textFont.addOnFontSet(delegate void(FontButton fb)
        {
            Config.SetValue("terminal_elem", "font", fb.getFont());
        });
    }
        
    
}
