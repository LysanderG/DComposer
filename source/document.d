module document;

import std.path;

import ui;
import qore;
import docman;

import gtk.Label;
import gtk.Widget;
import gsv.SourceLanguage;
import gsv.SourceLanguageManager;
import gsv.SourceView;
import gsv.SourceFile;
import gsv.SourceFileLoader;
import gsv.SourceFileSaver;
import gsv.SourceStyleSchemeManager;
import pango.PgFontDescription;
import gio.FileIF;

class DOCUMENT : SourceView, DOC_IF
{
private:
    string      mFullPathName;
    bool        mVirgin;
    Widget      mTabWidget;

public:

    string FullName(){return mFullPathName;}
    string Name(){return baseName(mFullPathName);}
    void   Name(string nuFileName)
    {
        mFullPathName = nuFileName;
    }
    
    bool Virgin(){return mVirgin;}
    void Virgin(bool nuVirgin){mVirgin = false;}
    void Reconfigure()
    {
        dwrite(Name);
        auto Lang = SourceLanguageManager.getDefault().guessLanguage(Name, null);
        getBuffer.setLanguage(Lang);
        string StyleID = Config.GetValue("document", "style_scheme", "mnml");
        getBuffer().setStyleScheme(SourceStyleSchemeManager.getDefault().getScheme(StyleID));

        setAutoIndent(Config.GetValue("document", "auto_indent", true));
        setIndentOnTab(Config.GetValue("document", "indent_on_tab", true));
        setInsertSpacesInsteadOfTabs(Config.GetValue("document", "spaces_for_tabs", true));

        bool SmartHomeEnd = Config.GetValue("document", "smart_home_end", true);
        setSmartHomeEnd(SmartHomeEnd ? SmartHomeEndType.BEFORE : SmartHomeEndType.DISABLED);

        setHighlightCurrentLine(Config.GetValue("document", "hilite_current_line", false));
        setShowLineNumbers(Config.GetValue("document", "show_line_numbers",true));
        setShowLineMarks(Config.GetValue("document", "show_line_marks", true));
        setShowRightMargin(Config.GetValue("document", "show_right_margin", true));
        getBuffer.setHighlightSyntax(Config.GetValue("document", "hilite_syntax", true));
        getBuffer.setHighlightMatchingBrackets(Config.GetValue("document", "match_brackets", true));
        setRightMarginPosition(Config.GetValue("document", "right_margin", 120));
        setIndentWidth(Config.GetValue("document", "indentation_width", 4));
        setTabWidth(Config.GetValue("document", "tab_width", 4));
        setBorderWindowSize(GtkTextWindowType.BOTTOM, Config.GetValue("document", "bottom_border_size", 5));
        setPixelsBelowLines(Config.GetValue("document", "pixels_below_line", 1));
        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.GetValue("document", "font", "Monospace 13")));
        setMonospace(true);   
    }
    void Load(string fileName)
    {
        auto label = new Label(fileName.baseName);
        label.setUseUnderline(false);
        label.setTooltipText(fileName);
        mTabWidget = label;
        auto dfile = new SourceFile();
        dfile.setLocation(FileIF.parseName(fileName));
        auto dfileloader = new SourceFileLoader(getBuffer, dfile);
        dfileloader.loadAsync(G_PRIORITY_DEFAULT, null, null, null, null, &FileLoaded, cast(void*)dfileloader);
        
    }
    void Save()
    {
    }
    void SaveAs(string newFileName)
    {
    }
    void Close()
    {
    }
    void SaveCopy(string copyFileName)
    {
    }
    string StatusText()
    {
        return "status text";
    }  
    void *      TabWidget(){return cast(void*)mTabWidget;}
}

extern (C)
{
    void FileLoaded(GObject *source_object, GAsyncResult *res, void * user_data)
    {
        auto dfile = cast(SourceFileLoader)user_data;
        
        dwrite("encoding ",dfile.getEncoding(), "  ",source_object);
        
        
    }   
}
