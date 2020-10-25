module document;

import std.path;
import std.format;
import std.file;

import ui;
import qore;
import docman;

import gdk.Event;
import gio.FileIF;
import gsv.SourceFile;
import gsv.SourceFileLoader;
import gsv.SourceFileSaver;
import gsv.SourceLanguage;
import gsv.SourceLanguageManager;
import gsv.SourceStyleSchemeManager;
import gsv.SourceView;
import gtk.Box;
import gtk.Button;
import gtk.EventBox;
import gtk.Image;
import gtk.Label;
import gtk.Notebook;
import gtk.TextBuffer;
import gtk.Widget;
import pango.PgFontDescription;


class DOCUMENT : SourceView, DOC_IF
{
private:
    string      mFullPathName;
    bool        mVirgin;
    Box         mTabWidget;
    Label       mTabLabel;
    SourceFile  mFile;
    
public:

    string FullName(){return mFullPathName;}
    string Name(){return baseName(mFullPathName);}
    void   Name(string nuFileName)
    {
        mFullPathName = nuFileName;
        UpdateTabWidget();
    }
    
    bool Virgin(){return mFile is null;}
    
    bool Modified(){return getBuffer.getModified();}
    
    
    void Reconfigure()
    {
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
    
    void Init(string nuFileName = null)
    {
        mTabWidget = new Box(Orientation.HORIZONTAL,0);
        mTabLabel = new Label(mFullPathName, false);        
                
        //use an Image because buttons are too damn large. Who wants a giant sized tab row.
        auto tabXButton = new Image(Config.GetValue("document","close_button_icon", "resources/cross-circle-frame.png"));
        
        tabXButton.setSizeRequest(8, 8);
        tabXButton.addEvents(EventMask.BUTTON_RELEASE_MASK);
        auto stupidEventBox = new EventBox();
        stupidEventBox.add(tabXButton);
        stupidEventBox.setAboveChild(false);
        stupidEventBox.setVisibleWindow(false);
        stupidEventBox.setEvents(EventMask.BUTTON_RELEASE_MASK);
        stupidEventBox.addOnButtonRelease(delegate bool(Event ev, Widget w)
        {
            if(ev.button.button != GDK_BUTTON_PRIMARY) return false;
            mDocBook.Close(this);
            return true;
        });
        
        mTabWidget.packStart(mTabLabel,false,false,0);
        mTabWidget.packStart(stupidEventBox,false,false,2);
        mTabWidget.showAll();
        getBuffer().addOnModifiedChanged(delegate void (TextBuffer Buf){UpdateTabWidget();});
        
        if(nuFileName is null)Name = NameMaker();
        else Name = nuFileName;
        
        Reconfigure();
        docman.AddDoc(this);
    }
    void Load(string fileName)
    {
        Init(fileName);
        mFile = new SourceFile();
        mFile.setLocation(FileIF.parseName(fileName));
        auto dfileloader = new SourceFileLoader(getBuffer, mFile);
        dfileloader.loadAsync(G_PRIORITY_DEFAULT, null, null, null, null, &FileLoaded, cast(void*)dfileloader);
        Name =  fileName;
    }
    void Save()
    {
	    if(mFile is null) 
	    {
    	    //what about DRY
    	    mFile = new SourceFile;
    	    mFile.setLocation(FileIF.parseName(mFullPathName));
    	    dwrite(mFile);
	    }
	    auto mFileSave = new SourceFileSaver(getBuffer, mFile);
	    dwrite(mFileSave);
	    mFileSave.saveAsync(G_PRIORITY_DEFAULT, null, null, null, null, &FileSaved, cast(void*)mFileSave);
    }
    void SaveAs(string newFileName)
    {
        if(mFile is null) mFile = new SourceFile();
        mFile.setLocation(FileIF.parseName(newFileName));
        dwrite("saveas ... ");
        Save();
    }
    void Close()
    {
    }
    void SaveCopy(string copyFileName)
    {
    }

    void* TabWidget(){return cast(void*)mTabWidget;}
    void UpdateTabWidget()
    {
        if(mTabLabel is null) return;
        if(getBuffer.getModified())
        {
            mTabLabel.setMarkup(`<span foreground="red" >[* `~ Name ~` *]</span>`);
        }
        else mTabLabel.setText(Name);
        mTabWidget.setTooltipText(FullName);
    }
    
    string GetStatusLine()
    {
        string rv;
        //rv = format("%s:%i/%i (col:%i) %s
        return mFullPathName;
    }
}

string NameMaker()
{
    static int suffixNumber = 0;
    scope(exit)suffixNumber++;
    
    string baseName = getcwd() ~ "/dcomposer%0s.d";
    return format(baseName, suffixNumber);
}


extern (C)
{
    import gio.AsyncResultIF;
    import gio.Task;
    void FileLoaded(GObject *source_object, GAsyncResult *res, void * user_data)
    {
        try
        {
            auto dfile = cast(SourceFileLoader)user_data;
            auto theTask = new Task(cast(GTask*)res);  
            if(!dfile.loadFinish(theTask))
            {
                Log.Entry("File load error");
            }
        }
        catch(Exception oops)
        {
            Log.Entry(oops.msg, "Error");
        }
    }   
    void FileSaved(GObject *source_object, GAsyncResult *res, void * user_data)
	{   
    	dwrite("finished");
    	try
        {
    		auto dfile = cast(SourceFileSaver)user_data;
    		
    		auto theTask = new Task(cast(GTask*)res);
            if(!dfile.saveFinish(theTask))
            {
                Log.Entry("File save error");
            }
            
        }
        catch(Exception oops)
        {
            Log.Entry(oops.msg);
        }
    }
}
