module filter_elem;

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

	//Idle mUpdateOnIdle;
	SAVED_FILTER[] mSavedFilters;
	//bool mFiltersModified; //what the hell is the point of this?


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
		if(mSavedFilters.length    )GetAction("ActUserOne"  ).setLabel(mSavedFilters[0].Command);
		if(mSavedFilters.length > 1)GetAction("ActUserTwo"  ).setLabel(mSavedFilters[1].Command);				
		if(mSavedFilters.length > 2)GetAction("ActUserThree").setLabel(mSavedFilters[2].Command);
		if(mSavedFilters.length > 3)GetAction("ActUserFour" ).setLabel(mSavedFilters[3].Command);
		if(mSavedFilters.length > 4)GetAction("ActUserFive" ).setLabel(mSavedFilters[4].Command);
		if(mSavedFilters.length > 5)GetAction("ActUserSix"  ).setLabel(mSavedFilters[5].Command);				
		if(mSavedFilters.length > 6)GetAction("ActUserSeven").setLabel(mSavedFilters[6].Command);
		if(mSavedFilters.length > 7)GetAction("ActUserEight").setLabel(mSavedFilters[7].Command);
	}

	void UpdateSaveFilters()
	{
		//mFiltersModified = true;
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
        //UpdateSaveFilters();
        UpdateSavedView();
		//mFiltersModified = true;
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
		builder.addFromFile(SystemPath(Config.GetValue("filter_elem","glade_file", "elements/resources/filter_elem.glade")));

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
		foreach(i, obj; Config.GetArray!JSON("filter_elem", "saved"))
		{
			mSavedFilters.length = mSavedFilters.length + 1;

			mSavedFilters[i].In = cast(FILTER_INPUT)obj["input"];
			mSavedFilters[i].Out = cast(FILTER_OUTPUT)obj["output"];
			mSavedFilters[i].Command = cast(string)obj["command"];
			//mSavedFilters ~= xfilter;
		}

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
                    UpdateSavedView();
					return true;
				}
			}
			return false;
		});
		
        mSavedView.addOnRowActivated(delegate void(TreePath tp, TreeViewColumn tvc, TreeView tv)
        {
            auto ti = mSavedView.getSelectedIter();
            if(ti is null) return;
            int[] index = ti.getTreePath().getIndices();
            int indx = index[0];
            with (mSavedFilters[indx])ExecuteFilter(In, Command, Out);
        });
            


		//actions
		AddIcon("dcmp-doc-filter-user-1",  SystemPath(Config.GetValue("filter_elem", "filter-act-1","resources/notification-counter.png")));
		auto ActUserOne = "ActUserOne".AddAction("User 1", "Saved user text filter", "dcmp-doc-filter-user-1", "<Control><Shift>exclam",delegate void(Action a){UserAction(1);});
		AddToMenuBar("ActUserOne", "E_lements");
		uiContextMenu.AddAction("ActUserOne");

		AddIcon("dcmp-doc-filter-user-2",  SystemPath(Config.GetValue("filter_elem", "filter-act-2", "resources/notification-counter-02.png")));
		auto ActUserTwo = "ActUserTwo".AddAction("User 2", "Saved user text filter", "dcmp-doc-filter-user-2", "<Shift><Control>at",delegate void(Action a){UserAction(2);});
		AddToMenuBar("ActUserTwo", "E_lements");
		uiContextMenu.AddAction("ActUserTwo");

		AddIcon("dcmp-doc-filter-user-3",  SystemPath(Config.GetValue("filter_elem", "filter-act-3", "resources/notification-counter-03.png")));
		auto ActUserThree = "ActUserThree".AddAction("User 3", "Saved user text filter", "dcmp-doc-filter-user-3", "<Shift><Control>numbersign",delegate void(Action a){UserAction(3);});
		AddToMenuBar("ActUserThree", "E_lements");
		uiContextMenu.AddAction("ActUserThree");

		AddIcon("dcmp-doc-filter-user-4",  SystemPath(Config.GetValue("filter_elem", "filter-act-4", "resources/notification-counter-04.png")));
		auto ActUserFour = "ActUserFour".AddAction("User 4", "Saved user text filter", "dcmp-doc-filter-user-4", "<Shift><Control>dollar",delegate void(Action a){UserAction(4);});
		AddToMenuBar("ActUserFour", "E_lements");
		//uiContextMenu.AddAction("ActUserFour");

		AddIcon("dcmp-doc-filter-user-5",  SystemPath(Config.GetValue("filter_elem", "filter-act-5", "resources/notification-counter-05.png")));
		auto ActUserFive = "ActUserFive".AddAction("User 5", "Saved user text filter", "dcmp-doc-filter-user-5", "<Shift><Control>percent",delegate void(Action a){UserAction(5);});
		AddToMenuBar("ActUserFive", "E_lements");
		//uiContextMenu.AddAction("ActUserFive");

		AddIcon("dcmp-doc-filter-user-6",  SystemPath(Config.GetValue("filter_elem", "filter-act-6", "resources/notification-counter-06.png")));
		auto ActUserSix = "ActUserSix".AddAction("User 6", "Saved user text filter", "dcmp-doc-filter-user-6", "<Shift><Control>asciicircum",delegate void(Action a){UserAction(6);});
		AddToMenuBar("ActUserSix", "E_lements");
		//uiContextMenu.AddAction("ActUserSix");

		AddIcon("dcmp-doc-filter-user-7",  SystemPath(Config.GetValue("filter_elem", "filter-act-7", "resources/notification-counter-07.png")));
		auto ActUserSeven = "ActUserSeven".AddAction("User 7", "Saved user text filter", "dcmp-doc-filter-user-7", "<Shift><Control>ampersand",delegate void(Action a){UserAction(7);});
		AddToMenuBar("ActUserSeven", "E_lements");
		//uiContextMenu.AddAction("ActUserSeven");

		AddIcon("dcmp-doc-filter-user-8",  SystemPath(Config.GetValue("filter_elem", "filter-act-8", "resources/notification-counter-08.png")));
		auto ActUserEight = "ActUserEight".AddAction("User 8", "Saved user text filter", "dcmp-doc-filter-user-8", "<Shift><Control>asterisk",delegate void(Action a){UserAction(8);});
		AddToMenuBar("ActUserEight", "E_lements");
		//uiContextMenu.AddAction("ActUserEight");

		AddIcon("dcmp-doc-filter-user-9",  SystemPath(Config.GetValue("filter_elem", "filter-act-9", "resources/notification-counter-09.png")));
		auto ActUserNine = "ActUserNine".AddAction("User 9", "Saved user text filter", "dcmp-doc-filter-user-9", "<Shift><Control>parenleft",delegate void(Action a){UserAction(9);});
		AddToMenuBar("ActUserNine", "E_lements");
		//uiContextMenu.AddAction("ActUserNine");

		AddIcon("dcmp-doc-filter-user-0",  SystemPath(Config.GetValue("filter_elem", "filter-act-0", "resources/notification-counter-10.png")));
		auto ActUserTen = "ActUserTen".AddAction("User 10", "Saved user text filter", "dcmp-doc-filter-user-0", "<Shift><Control>parenright",delegate void(Action a){UserAction(10);});
		AddToMenuBar("ActUserTen", "E_lements");
		//uiContextMenu.AddAction("ActUserTen");

        UpdateSavedView();
		Log.Entry("Engaged");
	}

	void Disengage()
	{
        import std.typecons;
		alias Tuple!(int, string, int ,string, string, string) savedtuple;
		Config.Remove("filter_elem", "saved");
		foreach(filter;mSavedFilters)
		{
			auto jobject = jsonObject();
			jobject["input"] = cast(int)filter.In;
			jobject["command"] = JSON(filter.Command);
			jobject["output"] = cast(int)filter.Out;
			Config.AppendObject("filter_elem","saved", jobject);
		}
        
        RemoveAction("ActUserTen");
        RemoveAction("ActUserNine");
        RemoveAction("ActUserEight");
        RemoveAction("ActUserSeven");
        RemoveAction("ActUserSix");
        RemoveAction("ActUserFive");
        RemoveAction("ActUserFour");
        RemoveAction("ActUserThree");
        RemoveAction("ActUserTwo");
        RemoveAction("ActUserOne");        

		RemoveExtraPage(mRoot);
        mRoot.destroy();
 
		Log.Entry("Disengaged");
	}

	void Configure()
	{
	}
}


