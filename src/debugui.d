module debugui;

import ui;
import dcore;
import config;
import elements;

import gtk.VBox;
import gtk.Builder;
import gtk.Label;


class DEBUG_UI : ELEMENT
{

private:
    string mName;
    string mInfo;
    bool mState;

    //gtkd stuff
    Builder mBuilder;
    VBox mSideRoot;
    VBox mExtraRoot;

protected:
	void Configure()
    {}

	void SetPagePosition(UI_EVENT uie)
	{
		switch (uie)
		{
			case UI_EVENT.RESTORE_GUI :
			{
				dui.GetExtraPane.reorderChild(mSideRoot, Config.getInteger("DEBUG_UI", "side_page_position"));
				dui.GetExtraPane.reorderChild(mExtraRoot, Config.getInteger("DEBUG_UI", "extra_page_position"));
				break;
			}
			case UI_EVENT.STORE_GUI :
			{
				Config.setInteger("DEBUG_UI", "side_page_position", dui.GetExtraPane.pageNum(mSideRoot));
				Config.setInteger("DEBUG_UI", "extra_page_position", dui.GetExtraPane.pageNum(mExtraRoot));
				break;
			}
			default :break;
		}
	}


public:
    this()
    {
	    mName = "DEBUG_UI";
	    mInfo = "Very primitive debugging tool using gdb as a backend. Probably very buggy itself :)";
    }

    @property string Name()
    {
	    return mName;
    }
    @property string Information()
    {
	    return mInfo;
    }
    @property bool   State()
    {
	    return mState;
    }
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        if(mState) Engage();
        else Disengage();
    }


    void Engage()
    {
	    mBuilder = new Builder;
	    mBuilder.addFromFile(Config.getString("DEBUG_UI", "glade_file",  "$(HOME_DIR)/glade/ntdb.glade"));

	    mExtraRoot = cast(VBox) mBuilder.getObject("vbox1");
	    mSideRoot = cast(VBox) mBuilder.getObject("vbox5");

	    dui.GetSidePane().appendPage(mSideRoot, "Debug");
	    dui.GetExtraPane().appendPage(mExtraRoot, "Debug");

	    dui.GetSidePane.setTabReorderable ( mSideRoot, true);
	    dui.GetExtraPane.setTabReorderable ( mExtraRoot, true);

	    dui.connect(&SetPagePosition);
	    Config.Reconfig.connect(&Configure);

	    mSideRoot.showAll();
	    mExtraRoot.showAll();

	    mState = true;
	    Log.Entry("Engaged "~Name()~"\t\telement.");
    }

    void Disengage()
    {
	    Config.setInteger("DEBUG_UI", "side_page_position", dui.GetSidePane.pageNum(mSideRoot));
	    Config.setInteger("DEBUG_UI", "extra_page_position", dui.GetExtraPane.pageNum(mExtraRoot));
	    mState = false;
	    Log.Entry("Disengaged "~mName~"\t\telement.");
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
	    return null;
    }

}
