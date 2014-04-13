module document2;

import ui;
import dcore;
import document;

import std.datetime;
import std.file;
import std.path;
import std.algorithm;

import gtk.TextIter;
import gtk.Widget;
import gtk.Box;
import gtk.Label;
import gtk.ScrolledWindow;
import gtk.Button;
import gtk.TextBuffer;
import gtk.MessageDialog;
import gtk.Adjustment;

import gdk.Event;

import gobject.ObjectG;
import gobject.ParamSpec;

import gsv.SourceView;
import gsv.SourceBuffer;
import gsv.SourceLanguage;
import gsv.SourceLanguageManager;
import gsv.SourceStyleSchemeManager;



class DOCUMENT2 : DOCUMENT //SourceView, DOC_IF
{
	private:
	string	mFullName;


	bool	mVirgin;

	Widget 	mPageWidget;
	Box		mTabWidget;
	Label   mTabLabel;

	bool 	mIsOpeningScroll;


	SysTime mFileTimeStamp;


	void UpdateTabWidget()
	{
		if(Modified)
		{
			mTabLabel.setMarkup(`<span foreground="red" >[* `~TabLabel()~` *]</span>`);
		}
		else mTabLabel.setText(TabLabel());
		mTabWidget.setTooltipText(Name);
	}


	public:


	this()
	{

		ScrolledWindow ScrollWin = new ScrolledWindow(null, null);
		//ScrolledWindow.setSizeRequest(-1,-1);

		ScrollWin.add(this);

		ScrollWin.setPolicy(GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);
		ScrollWin.showAll();

		auto tabXButton = new Button(StockID.NO, true);
		tabXButton.setBorderWidth(1);
		tabXButton.setRelief(ReliefStyle.NONE);
		//tabXButton.setSizeRequest(8, 8);
		tabXButton.addOnClicked(delegate void (Button x){DocMan.Close(this);});

		mTabWidget = new Box(Orientation.HORIZONTAL, 0);
		//mTabWidget.setSizeRequest(12, 12);
		mTabLabel = new Label(TabLabel);
		mTabWidget.add(mTabLabel);
		mTabWidget.add(tabXButton);
		mTabWidget.showAll();

		mPageWidget = ScrollWin;



		getBuffer().addOnModifiedChanged(delegate void (TextBuffer Buf){UpdateTabWidget();});
		getBuffer().addOnNotify(delegate void(ParamSpec ps, ObjectG objg){DocMan.NotifySelection();},"has-selection");
		addOnFocus(delegate bool(GtkDirectionType direction, Widget w) {DocMan.NotifySelection(); return false;});
		addOnFocusIn(delegate bool(Event event, Widget w) {CheckExternalModification();return false;});

		getBuffer().createTag("HiLiteAllSearchBack", "background", Config.GetValue("document2", "hiliteallsearchback", "white"));
		getBuffer().createTag("HiLiteAllSearchFore", "foreground", Config.GetValue("document2", "hiliteallsearchfore", "black"));

		getBuffer().createTag("HiLiteSearchBack", "background", Config.GetValue("document2", "hilitesearchback", "darkgreen"));
		getBuffer().createTag("HiLiteSearchFore", "foreground", Config.GetValue("document2", "hilitesearchfore", "yellow"));

	}

	override void Configure()
	{

		auto Lang = SourceLanguageManager.getDefault().guessLanguage(Name, null);
		getBuffer.setLanguage(Lang);

		string StyleID = Config.GetValue("document2", "style_scheme", "classic");
		getBuffer().setStyleScheme(SourceStyleSchemeManager.getDefault().getScheme(StyleID));


		setAutoIndent(Config.GetValue("document2", "auto_indent", true));
		setIndentOnTab(Config.GetValue("document2", "indent_on_tab", true));
		setInsertSpacesInsteadOfTabs(Config.GetValue("document2", "spaces_for_tabs", true));

		bool SmartHomeEnd = Config.GetValue("document2", "smart_home_end", true);
		setSmartHomeEnd(SmartHomeEnd ? SourceSmartHomeEndType.BEFORE : SourceSmartHomeEndType.DISABLED);

		setHighlightCurrentLine(Config.GetValue("document2", "hilite_current_line", false));
        setShowLineNumbers(Config.GetValue("document2", "show_line_numbers",true));
        setShowRightMargin(Config.GetValue("document2", "show_right_margin", true));
        getBuffer.setHighlightSyntax(Config.GetValue("document2", "hilite_syntax", true));
        getBuffer.setHighlightMatchingBrackets(Config.GetValue("document2", "match_brackets", true));
        setRightMarginPosition(Config.GetValue("document2", "right_margin", 120));
        setIndentWidth(Config.GetValue("document2", "indention_width", 8));
        setTabWidth(Config.GetValue("document2", "tab_width", 4));
        setBorderWindowSize(GtkTextWindowType.BOTTOM, 5);
		setPixelsBelowLines(1);
        modifyFont(pango.PgFontDescription.PgFontDescription.fromString(Config.GetValue("document2", "font", "Inconsolata Bold 12")));
	}



}
