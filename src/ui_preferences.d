module ui_preferences;

import std.file;
import std.path;
import std.conv;
import std.array;

import dcore;
import ui;

import gtk.Label;
import gtk.Dialog;
import gtk.Widget;
import gtk.Frame;
import gtk.Container;
import gtk.Switch;
import gtk.FileChooserDialog;
import gsv.SourceStyleSchemeManager;


import gobject.ParamSpec;
import gobject.ObjectG;

abstract class PREFERENCE_PAGE
{
    package:
    string mPageTitle;          //what the caller can display on its tab or titlebar or whatever
    Widget mRootWidget;         //where all the config ui stuff goes ... and call backs and what nots
    Widget mSplashWidget;       //what ever the element designer wants to show (logos, credits, liscensing ...)


    public:

    this()
    {
        mPageTitle = "Not Implemented";
        mRootWidget = null;
        mSplashWidget = null;
    }

    @property string Title(){return mPageTitle;}
    @property void Title(string nuTitle){mPageTitle = nuTitle;}

    @property Widget ContentWidget(){return mRootWidget;}
    @property void ContentWidget(Widget nuRoot){mRootWidget = nuRoot;}
    @property Widget SplashWidget(){return mSplashWidget;}
    @property void SplashWidget(Widget nuSplash){mSplashWidget = nuSplash;}

}


bool ShowPreferencePageDialog(PREFERENCE_PAGE Page)
{

    //load page with config values
    //display page -- change values
    //destroy diplay
    //return true to configure whatever was modified or false if no changes or canceled


    auto dialog = new Dialog("Preferences Dialog", MainWindow, GtkDialogFlags.MODAL, ["Close"], [cast(GtkResponseType)0]);

    auto contentArea = dialog.getContentArea();
    auto actionArea = dialog.getActionArea();

    if(Page is null)
    {
            auto pageFrame = new Frame(new Label("No Options Available! :)"), Page.Title);
            pageFrame.showAll();
            contentArea.packStart(pageFrame, 0, 0, 2);
    }
    else
    {
        auto tmpcon = cast(Container)(Page.ContentWidget);
        tmpcon.setBorderWidth(10);
        auto pageFrame = new Frame(Page.ContentWidget, Page.Title);
        contentArea.packStart(pageFrame, 1, 1, 5);
        if(Page.SplashWidget !is null)contentArea.packStart(Page.SplashWidget, 1, 1, 0);
    }

    contentArea.showAll();
    actionArea.showAll();
    dialog.run();
    dialog.destroy();
    return false;
}

void ShowAppPreferences()
{
    //Create a dialog
    auto dialog = new Dialog("DComposer Preferences", MainWindow, DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT, ["DONE"], [ResponseType.CLOSE]);
    dialog.setPosition(WindowPosition.CENTER_ON_PARENT);

    auto theNoteBook = new Notebook;

    dialog.getContentArea.add(theNoteBook);
    theNoteBook.setTabPos(PositionType.LEFT);
    theNoteBook.setHexpand(true);
    theNoteBook.setVexpand(true);


    //fill it with components from each module
    //General tab
    auto genPage = BuildGenPrefPage();
    auto genTab = new Label("General");

    theNoteBook.appendPage(genPage, genTab);

    //Editor tab
    auto docRoot = BuildDocPrefPage();
    auto docTab = new Label("Editor");

    theNoteBook.appendPage(docRoot, docTab);



    //show it
    dialog.showAll();
    dialog.run();


    //dispose of it
    dialog.destroy();
}


Widget BuildGenPrefPage()
{
    auto genBuilder = new Builder;
    genBuilder.addFromFile(SystemPath("glade/pref_general.glade"));

    auto root = cast(Frame)genBuilder.getObject("frame1");
    auto grid = cast(Grid)genBuilder.getObject("grid1");


    //basefolder
    auto BaseFolder = cast(Entry)genBuilder.getObject("entry1");
    BaseFolder.setText(sysDirectory);
    BaseFolder.addOnActivate(delegate void(Entry)
    {
        dwrite("place holder BaseFolder ", BaseFolder.getText());
    });
    BaseFolder.addOnIconPress(delegate void(GtkEntryIconPosition pos, Event e, Entry me)
    {
        auto FolderSelected = SelectFolder(BaseFolder.getText());
        BaseFolder.setText(FolderSelected);
    });

    //start up folder
    auto StartUpFolder = cast(Entry)genBuilder.getObject("entry2");
    StartUpFolder.setText(Config.GetValue!string("config", "starting_folder"));
    StartUpFolder.addOnActivate(delegate void(Entry)
    {
        Config.SetValue("config", "starting_folder", StartUpFolder.getText());
    });
    StartUpFolder.addOnIconPress(delegate void(GtkEntryIconPosition pos, Event e, Entry me)
    {
        auto FolderSelected = SelectFolder(StartUpFolder.getText());
        StartUpFolder.setText(FolderSelected);
        Config.SetValue("config", "starting_folder", FolderSelected);
    });

    //log file size
    auto MaxLogFileSize = cast(SpinButton)genBuilder.getObject("spinbutton1");
    MaxLogFileSize.setValue(Config.GetValue!int("log", "max_file_size"));
    MaxLogFileSize.addOnValueChanged(delegate void(SpinButton sp)
    {
        Config.SetValue("log", "max_file_size", to!int(MaxLogFileSize.getValue()));
    });

    //elements enabled
    auto AllowElements = cast(Switch)genBuilder.getObject("switch1");
    AllowElements.setActive(!Config.GetValue!bool("elements", "disabled"));
    AllowElements.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue!bool("elements", "disabled", !AllowElements.getActive());
        "ActElementManager".GetAction().setSensitive(!Config.GetValue!bool("elements", "disabled"));
        if(!AllowElements.getActive())elements.Disengage();
    }, "active");

    //show element manager
    auto ManageElement = cast(Button)genBuilder.getObject("button1");
    ManageElement.setRelatedAction("ActElementManager".GetAction());

    //auto load library symbols
    auto AutoLoadSymbols = cast(Switch)genBuilder.getObject("switch2");
    AutoLoadSymbols.setActive(Config.GetValue!bool("symbols", "auto_load_packages"));
    AutoLoadSymbols.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue!bool("symbols", "auto_load_packages", AutoLoadSymbols.getActive());
    }, "active");
    auto libs_list = new UI_LIST("Library Symbols", ListType.FILES);
    libs_list.GetRootWidget().setVexpand(true);
    grid.attach(libs_list.GetRootWidget(), 0, 9, 3, 3);
    auto Package_Names = Config.GetKeys("symbol_libs");
    foreach(pkgName; Package_Names)libs_list.AddString(Config.GetValue!string("symbol_libs",pkgName));
    //UI_LIST signals need a class member delegate ... so we'll catch the destroy event
    libs_list.GetRootWidget().addOnDestroy(delegate void(Widget w)
    {
        Config.Remove("symbol_libs");
        foreach(libFile; libs_list.GetItems())
        {
            auto key = libFile.baseName(".dtags");
            Config.SetValue("symbol_libs", key, libFile);
        }
    });


    //configure toolbar
    auto ConfigToolbar = cast(Button)genBuilder.getObject("button2");
    ConfigToolbar.setRelatedAction("ActConfigureToolbar".GetAction());

    //project base folder
    auto ProjBaseFolder = cast(Entry)genBuilder.getObject("entry3");
    ProjBaseFolder.setText(Config.GetValue!string("project","project_root_path"));
    ProjBaseFolder.addOnActivate(delegate void(Entry)
    {
        Config.SetValue("project","project_root_path", ProjBaseFolder.getText());
    });
    ProjBaseFolder.addOnIconPress(delegate void(GtkEntryIconPosition pos, Event e, Entry me)
    {
        auto FolderSelected = SelectFolder(ProjBaseFolder.getText());
        ProjBaseFolder.setText(FolderSelected);
        Config.SetValue("project","project_root_path", FolderSelected);
    });

    //terminal command
    auto TerminalCommand = cast(Entry)genBuilder.getObject("entry4");
    string cmdstring = Config.GetArray("terminal_cmd", "run",["xterm","-e","-hold"]).join(" ");
    TerminalCommand.setText(cmdstring);
    TerminalCommand.addOnActivate(delegate void(Entry)
    {
        string[] cmdarray = TerminalCommand.getText().split();
        Config.SetArray("terminal_cmd", "run", cmdarray);
    });


    return root;
}


Widget BuildDocPrefPage()
{
    auto docBuilder = new Builder;
    docBuilder.addFromFile(SystemPath("glade/pref_documents.glade"));

    auto root = cast(Frame)docBuilder.getObject("frame1");

    //syntax highlite
    auto SyntaxHilite = cast(Switch)docBuilder.getObject("syntax_highlite");
    SyntaxHilite.setActive(Config.GetValue("document", "hilite_syntax", true));
    SyntaxHilite.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "hilite_syntax", SyntaxHilite.getActive());

    }, "active");

    //style
    auto SyntaxStyle = cast(ComboBoxText)docBuilder.getObject("syntax_style");

    foreach(string SchemeID ; SourceStyleSchemeManager.getDefault().getSchemeIds())
    {
        SyntaxStyle.appendText(SchemeID);
    }

    SyntaxStyle.setActiveText(Config.GetValue!string("document","style_scheme"));
    SyntaxStyle.addOnChanged(delegate void(ComboBoxText ss)
    {
        Config.SetValue("document", "style_scheme", SyntaxStyle.getActiveText());
    });

    //indent on tab
    auto IndentOnTab = cast(Switch)docBuilder.getObject("indent_on_tab");
    IndentOnTab.setActive(Config.GetValue("document", "indent_on_tab", true));
    IndentOnTab.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "indent_on_tab", IndentOnTab.getActive());

    }, "active");

    //spaces for tabs
    auto SpacesForTabs = cast(Switch)docBuilder.getObject("spaces_for_tabs");
    SpacesForTabs.setActive(Config.GetValue("document", "spaces_for_tabs", true));
    SpacesForTabs.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "spaces_for_tabs", SpacesForTabs.getActive());

    }, "active");

    //smart home/end
    auto SmartHomeEnd = cast(Switch)docBuilder.getObject("smart_home_end");
    SmartHomeEnd.setActive(Config.GetValue("document", "smart_home_end", true));
    SmartHomeEnd.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "smart_home_end", SmartHomeEnd.getActive());

    }, "active");

    //hilite current line
    auto LineHiLite = cast(Switch)docBuilder.getObject("line_highlite");
    LineHiLite.setActive(Config.GetValue("document", "hilite_current_line", true));
    LineHiLite.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "hilite_current_line", LineHiLite.getActive());

    }, "active");

    //line numbers
    auto LineNumbers = cast(Switch)docBuilder.getObject("line_numbers");
    LineNumbers.setActive(Config.GetValue("document", "show_line_numbers", true));
    LineNumbers.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "show_line_numbers", LineNumbers.getActive());

    }, "active");

    //show right margin
    auto RightMargin = cast(Switch)docBuilder.getObject("right_margin_show");
    RightMargin.setActive(Config.GetValue("document", "show_right_margin", true));
    RightMargin.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "show_right_margin", RightMargin.getActive());

    }, "active");

    //right margin position
    auto RightMarginPos = cast(SpinButton)docBuilder.getObject("right_margin_pos");
    RightMarginPos.setValue(Config.GetValue!int("document", "right_margin"));
    RightMarginPos.addOnValueChanged(delegate void(SpinButton sp)
    {
        Config.SetValue("document", "right_margin", to!int(RightMarginPos.getValue()));
    });

    //Auto indent
    auto AutoIndent = cast(Switch)docBuilder.getObject("auto_indent");
    AutoIndent.setActive(Config.GetValue("document", "auto_indent", true));
    AutoIndent.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "auto_indent", AutoIndent.getActive());

    }, "active");

    //match braces
    auto MatchBraces = cast(Switch)docBuilder.getObject("braces_highlite");
    MatchBraces.setActive(Config.GetValue("document", "match_brackets", true));
    MatchBraces.addOnNotify(delegate void(ParamSpec spec, ObjectG  sw)
    {
        Config.SetValue("document", "match_brackets", MatchBraces.getActive());

    }, "active");

    //indent width
    auto IndentWidth = cast(SpinButton)docBuilder.getObject("indent_width");
    IndentWidth.setValue(Config.GetValue!int("document", "indentation_width"));
    IndentWidth.addOnValueChanged(delegate void(SpinButton sp)
    {
        Config.SetValue("document", "indentation_width", to!int(IndentWidth.getValue()));
    });

    //tab width
    auto TabWidth = cast(SpinButton)docBuilder.getObject("tab_width");
    TabWidth.setValue(Config.GetValue!int("document", "tab_width"));
    TabWidth.addOnValueChanged(delegate void(SpinButton sp)
    {
        Config.SetValue("document", "tab_width", to!int(TabWidth.getValue()));
    });

    //Bottom border size
    auto BorderSize = cast(SpinButton)docBuilder.getObject("border_size");
    BorderSize.setValue(Config.GetValue!int("document", "bottom_border_size"));
    BorderSize.addOnValueChanged(delegate void(SpinButton sp)
    {
        Config.SetValue("document", "bottom_border_size", to!int(BorderSize.getValue()));
    });

    //pixels under line
    auto Pixels = cast(SpinButton)docBuilder.getObject("pixels_below_line");
    Pixels.setValue(Config.GetValue!int("document", "pixels_below_line"));
    Pixels.addOnValueChanged(delegate void(SpinButton sp)
    {
        Config.SetValue("document", "pixels_below_line", to!int(Pixels.getValue()));
    });

    //font
    auto Fonts = cast(FontButton)docBuilder.getObject("fontbutton");
    Fonts.setFontName(Config.GetValue!string("document", "font"));
    Fonts.addOnFontSet(delegate void(FontButton fb)
    {
        Config.SetValue("document", "font", Fonts.getFontName());
    });

    return root;
}



string SelectFolder(string preFolder = null)
{
    auto FolderDialog = new FileChooserDialog("Select Folder", MainWindow, FileChooserAction.SELECT_FOLDER);
    if(preFolder)FolderDialog.setCurrentFolder(preFolder);
    FolderDialog.run();
    FolderDialog.hide();
    return FolderDialog.getCurrentFolder();
}
