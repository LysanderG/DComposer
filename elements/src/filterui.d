module filterui;

import dcore;
import ui;
import elements;

import std.traits;
import std.algorithm;
import std.string;

import json;



export extern (C) string GetClassName()
{
	return fullyQualifiedName!FILTER;
}

enum FILTER_INPUT
{
	NONE,
	WORD,
	LINE,
	SELECTION,
	DOCUMENT
}

enum FILTER_OUTPUT
{
	INSERT,
	REPLACE,
	NEW_DOCUMENT,
	PAD
}
string[] sin = ["NONE", "WORD", "LINE", "SELECTION", "DOCUMENT"];
string[] sout= ["INSERT", "REPLACE", "NEW DOCUMENT", "FILTER PAD"];

struct SAVED_FILTER
{
	FILTER_INPUT In;
	FILTER_OUTPUT Out;
	string Command;

	string[] toStrings()
	{


		return [sin[In], Command, sout[Out]];
	}
}



class FILTER : ELEMENT
{
	private:

	Box mRoot;
	ComboBox mInputBox;
	ComboBoxText mCommandBox;
	Entry mCommandEntry;
	ComboBox mOutputBox;
	Button mExecuteButton;
	Button mSaveButton;
	TreeView mSavedView;
	ListStore mSavedStore;
	TextView mErrorText;
	TextView mPadText;

	Idle mUpdateOnIdle;
	SAVED_FILTER[] mSavedFilters;
	bool mFiltersModified;


	void UpdateSavedView()
	{
		mSavedStore.clear();

		auto ti = new TreeIter;
		foreach(i, filter; mSavedFilters)
		{
			auto fstrings = filter.toStrings();
			mSavedStore.append(ti);
			mSavedStore.setValue(ti, 0, fstrings[0]);
			mSavedStore.setValue(ti, 1, fstrings[1]);
			mSavedStore.setValue(ti, 2, fstrings[2]);

			if(i < 10) mSavedStore.setValue(ti, 3, format("<CTRL><SHIFT>%s", (i+1)%10 ));
			else mSavedStore.setValue(ti, 3, "  --  ");
		}
	}

	void UpdateSaveFilters()
	{
		mFiltersModified = true;
		auto ti = new TreeIter;

		mSavedFilters.length = 0;
		auto r = mSavedStore.getIterFirst(ti);
		if(r == 0) return;
		do
		{
			SAVED_FILTER sf;
			foreach(i, str; sin)if(str == mSavedStore.getValueString(ti,0)) sf.In = cast(FILTER_INPUT) i;
			sf.Command = mSavedStore.getValueString(ti, 1);
			foreach(i, str; sout)if(str == mSavedStore.getValueString(ti,2)) sf.Out = cast(FILTER_OUTPUT) i;
			mSavedFilters ~= sf;
		}while(mSavedStore.iterNext(ti));
	}



	void UserAction(int index)
	{
		auto indx = index -1;
		if (indx >= mSavedFilters.length) return;
		with (mSavedFilters[indx])ExecuteFilter(In, Command, Out);
	}

	void SaveFilter()
	{
		SAVED_FILTER NewFilter;

		NewFilter.In = cast(FILTER_INPUT)mInputBox.getActive();
		NewFilter.Command = mCommandEntry.getText();
		NewFilter.Out = cast(FILTER_OUTPUT)mOutputBox.getActive();

		mSavedFilters ~= NewFilter;
		mFiltersModified = true;
	}

	void ExecuteFilter	(FILTER_INPUT In, string CommandText ,FILTER_OUTPUT Out)
	{
		scope(exit)SetBusyCursor(false);
		SetBusyCursor(true);
		mErrorText.getBuffer.setText("\0"); //argh still get gtk assert crap
		mPadText.getBuffer.setText("\0");

		//get the input
		string inputText;
		final switch(In) with (FILTER_INPUT)
		{
			case NONE : //NONE
			{
				break;
			}
			case WORD : //word
			{
				if(DocMan.Current() is null) break;
				inputText = DocMan.Current().Word();
				break;
			}
			case LINE : //line
			{
				if(DocMan.Current() is null) break;
				inputText = DocMan.Current().LineText();
				break;
			}
			case SELECTION : //selection
			{
				if(DocMan.Current() is null) break;
				inputText = DocMan.Current().Selection();
				break;
			}
			case DOCUMENT : //document
			{
				if(DocMan.Current() is null) break;
				inputText = DocMan.Current().GetText();
				break;
			}
			//default : break;
		}


		//get the output
		auto result = Filter(inputText, CommandText);

		if(result.startsWith("!DCOMPOSER_SHELLFILTER_ERROR!\n"))
		{
			mErrorText.getBuffer().setText(result);
			return;
		}

		//now where to put it
		final switch(Out) with (FILTER_OUTPUT)
		{
			case INSERT://insert
			{
				if(DocMan.Current is null)break;
				DocMan.Current.InsertText(result);
				break;
			}
			case REPLACE://replace
			{
				switch(In) with(FILTER_INPUT)
				{
					case NONE :// none
					{
						mPadText.getBuffer().setText(result);
						break;
					}
					case WORD ://word
					{
						if(DocMan.Current is null)break;
						DocMan.Current.ReplaceWord(result);
						break;
					}
					case LINE : //line
					{
						if(DocMan.Current is null)break;
						DocMan.Current.ReplaceLine(result);
						break;
					}

					case SELECTION : //selection
					{
						if(DocMan.Current is null)break;
						DocMan.Current.ReplaceSelection(result);
						break;
					}
					case DOCUMENT : //document
					{
						if(DocMan.Current is null)break;
						DocMan.Current.SetText(result);
						break;
					}
					default : break;
				}
				break;
			}

			case NEW_DOCUMENT://document
			{
				DocMan.Create();
				DocMan.Current.SetText(result);
				break;
			}
			case PAD://pad
			{
				mPadText.getBuffer().setText(result);
				break;
			}
		}
	}



	public:
	string Name(){
		return "Text Filter";
	}
	string Info(){
		return "Transform text through shell commands";
	}
	string Version(){
		return "00.01";
	}
	string CopyRight() {
		return "Anthony Goins © 2014";
	}
	string License() {
		return "New BSD license";
	}
	string[] Authors() {
		return ["Anthony Goins <neontotem@gmail.com>"];
	}
	PREFERENCE_PAGE PreferencePage(){
		return null;
	}

	void Engage()
	{
		auto builder = new Builder;
		builder.addFromFile(Config.GetValue("filterui","glade_file", ConfigPath("elements/resources/filterui.glade")));

		mRoot          = cast(Box)           builder.getObject("root");
		mInputBox      = cast(ComboBox)      builder.getObject("comboboxinput");
		mCommandBox    = cast(ComboBoxText)  builder.getObject("comboboxtextcommand");
		mCommandEntry  = cast(Entry)         builder.getObject("entrycommand");
		mOutputBox     = cast(ComboBox)      builder.getObject("comboboxoutput");
		mExecuteButton = cast(Button)        builder.getObject("buttonexecute");
		mSaveButton    = cast(Button)        builder.getObject("buttonsave");
		mSavedStore    = cast(ListStore)     builder.getObject("savedstore");
		mSavedView     = cast(TreeView)      builder.getObject("filterview");
		mErrorText     = cast(TextView)      builder.getObject("textviewerror");
		mPadText       = cast(TextView)      builder.getObject("textviewpad");
		AddExtraPage(mRoot, Name);


		//LOAD SAVED FILTERS
		foreach(obj; Config.GetArray!JSON("shellfilter", "saved"))
		{;
			SAVED_FILTER xfilter;

			xfilter.In = cast(FILTER_INPUT)obj["input"];
			xfilter.Out = cast(FILTER_OUTPUT)obj["output"];
			xfilter.Command = cast(string)obj["command"];
			mSavedFilters ~= xfilter;
		}
		UpdateSavedView();


		//connect the signals

		mExecuteButton.addOnClicked(delegate void(Button b)
									{
										ExecuteFilter(cast(FILTER_INPUT)mInputBox.getActive(), mCommandEntry.getText(),cast(FILTER_OUTPUT) mOutputBox.getActive());
									});
		mSaveButton.addOnClicked(delegate void(Button b){SaveFilter();});
		//mSavedStore.addOnRowsReordered(delegate void(TreePath, TreeIter, void *, TreeModelIF){UpdateSaveFilters();});
		//mSavedStore.addOnRowInserted(delegate void(TreePath, TreeIter, TreeModelIF){UpdateSaveFilters();});
		//mSavedStore.addOnRowDeleted(delegate void(TreePath, TreeModelIF){UpdateSaveFilters();});
		mSavedView.addOnKeyRelease(delegate bool(Event e, Widget w)
		{
			uint KeyVal;
			if(e.getKeyval(KeyVal))
			{
				if(KeyVal == GdkKeysyms.GDK_Delete)
				{
					auto ti = mSavedView.getSelectedIter();
					if(ti is null) return false;
					mSavedStore.remove(ti);
					UpdateSaveFilters();
					return true;
				}
			}
			return false;
		});
		mUpdateOnIdle = new Idle(delegate bool()
		{
			if(mFiltersModified)UpdateSavedView();
			mFiltersModified = false;
			return true;
		});


		//actions
		AddIcon("dcmp-doc-filter-user-1", Config.GetValue("icons", "filter-act-1", SystemPath("resources/notification-counter.png")));
		auto ActUserOne = "ActUserOne".AddAction("User 1", "Saved user text filter", "dcmp-doc-filter-user-1", "<Control><Shift>1",delegate void(Action a){UserAction(1);});
		AddToMenuBar("ActUserOne", "E_lements");
		uiContextMenu.AddAction("ActUserOne");

		AddIcon("dcmp-doc-filter-user-2", Config.GetValue("icons", "filter-act-2", SystemPath("resources/notification-counter-02.png")));
		auto ActUserTwo = "ActUserTwo".AddAction("User 2", "Saved user text filter", "dcmp-doc-filter-user-2", "<Shift><Control>2",delegate void(Action a){UserAction(2);});
		AddToMenuBar("ActUserTwo", "E_lements");
		uiContextMenu.AddAction("ActUserTwo");

		AddIcon("dcmp-doc-filter-user-3", Config.GetValue("icons", "filter-act-3", SystemPath("resources/notification-counter-03.png")));
		auto ActUserThree = "ActUserThree".AddAction("User 3", "Saved user text filter", "dcmp-doc-filter-user-3", "<Shift><Control>3",delegate void(Action a){UserAction(3);});
		AddToMenuBar("ActUserThree", "E_lements");
		uiContextMenu.AddAction("ActUserThree");

		AddIcon("dcmp-doc-filter-user-4", Config.GetValue("icons", "filter-act-4", SystemPath("resources/notification-counter-04.png")));
		auto ActUserFour = "ActUserFour".AddAction("User 4", "Saved user text filter", "dcmp-doc-filter-user-4", "<Shift><Control>4",delegate void(Action a){UserAction(4);});
		AddToMenuBar("ActUserFour", "E_lements");
		//uiContextMenu.AddAction("ActUserFour");

		AddIcon("dcmp-doc-filter-user-5", Config.GetValue("icons", "filter-act-5", SystemPath("resources/notification-counter-05.png")));
		auto ActUserFive = "ActUserFive".AddAction("User 5", "Saved user text filter", "dcmp-doc-filter-user-5", "<Shift><Control>5",delegate void(Action a){UserAction(5);});
		AddToMenuBar("ActUserFive", "E_lements");
		//uiContextMenu.AddAction("ActUserFive");

		AddIcon("dcmp-doc-filter-user-6", Config.GetValue("icons", "filter-act-6", SystemPath("resources/notification-counter-06.png")));
		auto ActUserSix = "ActUserSix".AddAction("User 6", "Saved user text filter", "dcmp-doc-filter-user-6", "<Shift><Control>6",delegate void(Action a){UserAction(6);});
		AddToMenuBar("ActUserSix", "E_lements");
		//uiContextMenu.AddAction("ActUserSix");

		AddIcon("dcmp-doc-filter-user-7", Config.GetValue("icons", "filter-act-7", SystemPath("resources/notification-counter-07.png")));
		auto ActUserSeven = "ActUserSeven".AddAction("User 7", "Saved user text filter", "dcmp-doc-filter-user-7", "<Shift><Control>7",delegate void(Action a){UserAction(7);});
		AddToMenuBar("ActUserSeven", "E_lements");
		//uiContextMenu.AddAction("ActUserSeven");

		AddIcon("dcmp-doc-filter-user-8", Config.GetValue("icons", "filter-act-8", SystemPath("resources/notification-counter-08.png")));
		auto ActUserEight = "ActUserEight".AddAction("User 8", "Saved user text filter", "dcmp-doc-filter-user-8", "<Shift><Control>8",delegate void(Action a){UserAction(8);});
		AddToMenuBar("ActUserEight", "E_lements");
		//uiContextMenu.AddAction("ActUserEight");

		AddIcon("dcmp-doc-filter-user-9", Config.GetValue("icons", "filter-act-9", SystemPath("resources/notification-counter-09.png")));
		auto ActUserNine = "ActUserNine".AddAction("User 9", "Saved user text filter", "dcmp-doc-filter-user-9", "<Shift><Control>9",delegate void(Action a){UserAction(9);});
		AddToMenuBar("ActUserNine", "E_lements");
		//uiContextMenu.AddAction("ActUserNine");

		AddIcon("dcmp-doc-filter-user-0", Config.GetValue("icons", "filter-act-0", SystemPath("resources/notification-counter-10.png")));
		auto ActUserTen = "ActUserTen".AddAction("User 10", "Saved user text filter", "dcmp-doc-filter-user-0", "<Shift><Control>0",delegate void(Action a){UserAction(10);});
		AddToMenuBar("ActUserTen", "E_lements");
		//uiContextMenu.AddAction("ActUserTen");

		Log.Entry("Engaged");
	}

	void Disengage()
	{
		alias Tuple!(int, string, int ,string, string, string) savedtuple;
		Config.Remove("shellfilter", "saved");
		foreach(filter;mSavedFilters)
		{
			auto jobject = jsonObject();
			jobject["input"] = cast(int)filter.In;
			jobject["command"] = JSON(filter.Command);
			jobject["output"] = cast(int)filter.Out;
			Config.AppendObject("shellfilter","saved", jobject);
		}


		RemoveExtraPage(mRoot);
		Log.Entry("Disengaged");
	}

	void Configure()
	{
	}
}


