module ui_preferences;

import dcore;
import ui;

import gtk.Label;
import gtk.Dialog;
import gtk.Widget;
import gtk.Frame;
import gtk.Container;

abstract class PREFERENCE_PAGE
{
	package:
	string mPageTitle;			//what the caller can display on its tab or titlebar or whatever
	Widget mRootWidget;			//where all the config ui stuff goes ... and call backs and what nots
	Widget mSplashWidget;		//what ever the element designer wants to show (logos, credits, liscensing ...)


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

bool ShowAppPreferences()
{
	//build gui from all components
	//load values
	//return true to configure everything
	return false;
}
