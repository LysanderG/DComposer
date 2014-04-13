module ui_search;

import std.array;
import std.xml;
import std.string;
import std.path;

import dcore;
import ui;
import ui_contextmenu;

import gtk.Action;
import gtk.Builder;
import gtk.Box;
import gtk.ComboBoxText;
import gtk.Button;
import gtk.CheckButton;
import gtk.RadioButton;
import gtk.TreeView;
import gtk.ListStore;
import gtk.TreeIter;
import gtk.ToggleButton;
import gtk.TreePath;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Entry;

import gdk.Event;
import gdk.Keysyms;

class UI_SEARCH
{
	private:

	Builder			mBuilder;
	Box				mRoot;
	ComboBoxText	mSearchBox;
	Button			mSearchButton;
	ToggleButton	mMarkAllButton;

	ComboBoxText 	mReplaceBox;
	Button			mReplaceButton;
	Button			mReplaceGoButton;
	Button			mReplaceAllButton;

	CheckButton		mCaseSensitive;
	CheckButton		mRegex;
	CheckButton		mStartsWord;
	CheckButton		mEndsWord;
	CheckButton		mRecursion;

	RadioButton		mCurrentDocument;
	RadioButton		mOpenDocuments;
	RadioButton		mProjectSourceOnly;
	RadioButton		mProjectAll;
	RadioButton		mFolder;

	TreeView		mTree;
	ListStore		mStore;

	SEARCH_OPTIONS	mOptions;
	SCOPE			mScope;

	ITEM[]			mSearchResults;

	bool			mUpdatingMStore; //so as not to react to cursor changes while adding search results

	void SetOptions()
	{
		mOptions.CaseSensitive = cast(bool) mCaseSensitive.getActive();
		mOptions.Regex = cast(bool) mRegex.getActive();
		mOptions.StartsWord = cast(bool) mStartsWord.getActive();
		mOptions.EndsWord = cast(bool) mEndsWord.getActive();
		mOptions.RecurseDirectory = cast(bool) mRecursion.getActive();
	}
	void SetScope()
	{
		if(mCurrentDocument.getActive())mScope = SCOPE.DOC_CURRENT;
		if(mOpenDocuments.getActive())mScope = SCOPE.DOC_OPEN;
		if(mProjectSourceOnly.getActive())mScope = SCOPE.PROJ_SOURCE;
		if(mProjectAll.getActive())mScope = SCOPE.PROJ_ALL;
		if(mFolder.getActive())mScope = SCOPE.FOLDER;
	}

	void UpdateResults()
	{
		scope(exit) mUpdatingMStore = false;
		mUpdatingMStore = true;
		TreeIter ti = new TreeIter;
		mStore.clear();

		foreach(item; mSearchResults)
		{
			auto ColoredMarkup = item.Text[0..item.OffsetStart].encode() ~ `<span foreground="red"><b><u>` ~ item.Text[item.OffsetStart..item.OffsetEnd].encode() ~ "</u></b></span>" ~item.Text[item.OffsetEnd..$].encode();

			mStore.append(ti);
			mStore.setValue(ti, 0, item.DocFile);
			mStore.setValue(ti, 1, cast(int)item.Line+1);
			mStore.setValue(ti, 2, ColoredMarkup);
		}
		//mTree.setCursor(new TreePath("0"), null, 0);
	}


	void Find(ToggleButton IgnoreThisParameter = null)
	{
		if(mSearchBox.getActiveText.length < 1) return;

		SetOptions();
		SetScope();

		mSearchResults = Search(mScope, mSearchBox.getActiveText(), mOptions);

		if(mMarkAllButton.getActive()) MarkAll();

		UpdateResults();

		string ScopeString;
		final switch(mScope)
		{
			case SCOPE.DOC_CURRENT : ScopeString = "current document";break;
			case SCOPE.DOC_OPEN : ScopeString = "open documents";break;
			case SCOPE.PROJ_SOURCE : ScopeString = "project source files";break;
			case SCOPE.PROJ_ALL : ScopeString = "project text files"; break;
			case SCOPE.FOLDER : ScopeString = "current directory path (" ~ getcwd() ~ ")";break;
		}
		string StatusText = format("Search for : \"%s\" in %s found %s results", mSearchBox.getActiveText, ScopeString, mSearchResults.length);
		AddStatus("searching", StatusText);
	}

	enum Advance = true;
	void ReplaceText(bool advance = false)
	{
		if(mSearchResults.length == 0) return;
		if(mReplaceBox.getActiveText().length < 1) return;
		TreePath tp = new TreePath;
		TreeIter ti = new TreeIter;
		TreeViewColumn tvc = new TreeViewColumn;

		mTree.getCursor(tp, tvc);

		if(tp is null) return;

		mStore.getIter(ti, tp);

		string file = ti.getValueString(0);
		int line = ti.getValueInt(1);
		DocMan.GoTo(file, line);
		int itemIndex = tp.getIndices()[0];

		string ReplText = mReplaceBox.getActiveText();

		auto sigResult = mSearchResults[itemIndex];

		DocMan.GetDoc(sigResult.DocFile).ReplaceText(ReplText, sigResult.Line, sigResult.OffsetStart, sigResult.OffsetEnd);

		string NewResultText = sigResult.Text[0..sigResult.OffsetStart] ~ ReplText ~ sigResult.Text[sigResult.OffsetEnd..$];
		mSearchResults[itemIndex].Text = NewResultText;
		mSearchResults[itemIndex].OffsetEnd = sigResult.OffsetStart + cast(int)ReplText.length;
		//also have to adjust other search results on the same line after this one
		foreach(ref result; mSearchResults[itemIndex+1..$])
		{
			if(mSearchResults[itemIndex].DocFile != result.DocFile) break;
			if(mSearchResults[itemIndex].Line != result.Line)break;

			result.OffsetEnd += ReplText.length - mSearchBox.getActiveText().length;
			result.OffsetStart += ReplText.length - mSearchBox.getActiveText().length;
		}



		UpdateResults();
		if(advance) tp.next();
		mTree.setCursor(tp, null, false);
	}

	void ReplaceAll()
	{
		if(DocMan.Empty()) return;
		if(mReplaceBox.getActiveText().length < 1) return;

		string repText = mReplaceBox.getActiveText();
		string oriText = mSearchBox.getActiveText();


		foreach(indx, ref result; mSearchResults)
		{
			if(result.DocFile != DocMan.Current.Name)continue;
			DocMan.Current.ReplaceText(repText, result.Line, result.OffsetStart, result.OffsetEnd);
			result.Text = result.Text[0..result.OffsetStart] ~ repText ~ result.Text[result.OffsetEnd..$];
			result.OffsetEnd = result.OffsetStart + cast (int)repText.length;
			foreach(ref res2; mSearchResults[indx+1..$])
			{
				if(res2.DocFile != result.DocFile) break;
				if(res2.Line != result.Line) break;
				res2.Text = result.Text;
				res2.OffsetEnd += repText.length - oriText.length;
				res2.OffsetStart += repText.length - oriText.length;
			}
		}

		UpdateResults();
	}


	void MarkAll()
	{
		foreach(od; DocMan.GetOpenDocs())od.ClearHiliteAllSearchResults();

		if(!mMarkAllButton.getActive()) return;

		foreach(item; mSearchResults)
		{
			auto tmpDoc = DocMan.GetDoc(item.DocFile.absolutePath());
			if(tmpDoc is null) continue;
			tmpDoc.HiliteAllSearchResults(item.Line, item.OffsetStart, item.OffsetEnd);
		}
	}


	public:

	void Engage()
	{
		mBuilder = new Builder;

		mBuilder.addFromFile(Config.GetValue("ui_search", "glade_file", SystemPath("glade/ui_search.glade")));

		mRoot = cast(Box) mBuilder.getObject("box1");

		mSearchBox = cast(ComboBoxText)mBuilder.getObject("comboboxtext1");
		mSearchButton = cast(Button)mBuilder.getObject("button1");
		mMarkAllButton = cast(ToggleButton)mBuilder.getObject("togglebutton1");

		mReplaceBox = cast (ComboBoxText)mBuilder.getObject("comboboxtext2");
		mReplaceButton = cast(Button) mBuilder.getObject("button4");
		mReplaceGoButton = cast (Button)mBuilder.getObject("button5");
		mReplaceAllButton = cast(Button)mBuilder.getObject("button6");

		mCaseSensitive = cast (CheckButton) mBuilder.getObject("checkbutton1");
		mRegex = cast (CheckButton) mBuilder.getObject("checkbutton2");
		mStartsWord = cast (CheckButton) mBuilder.getObject("checkbutton3");
		mEndsWord = cast (CheckButton) mBuilder.getObject("checkbutton4");
		mRecursion = cast (CheckButton) mBuilder.getObject("checkbutton5");

		mCurrentDocument = cast (RadioButton) mBuilder.getObject("radiobutton1");
		mOpenDocuments = cast (RadioButton) mBuilder.getObject("radiobutton2");
		mProjectSourceOnly = cast (RadioButton) mBuilder.getObject("radiobutton3");
		mProjectAll = cast (RadioButton) mBuilder.getObject("radiobutton4");
		mFolder = cast (RadioButton) mBuilder.getObject("radiobutton5");

		mTree = cast (TreeView) mBuilder.getObject("treeview1");
		mStore = cast (ListStore) mBuilder.getObject("liststore1");

		mTree.setRulesHint(1);

		mSearchBox.addOnChanged(delegate void(ComboBoxText cbt){Find();});
		mSearchBox.addOnKeyRelease(delegate bool(Event ev, Widget wi)
		{
			if(ev.key().keyval == GdkKeysyms.GDK_Return) mSearchBox.editingDone();
			return false;
		});

		mSearchBox.addOnEditingDone(delegate void (CellEditableIF)
		{
			auto x = mSearchBox.getIndex(mSearchBox.getActiveText());
			mTree.grabFocus();
			if(x >= 0) return;
			mSearchBox.prependText(mSearchBox.getActiveText());
			return;
		});

		mSearchButton.addOnClicked(delegate void(Button){Find();mSearchBox.editingDone();});

		mReplaceBox.addOnKeyRelease(delegate bool(Event ev, Widget wi)
		{
			if(ev.key().keyval == GdkKeysyms.GDK_Return) mReplaceBox.editingDone();
			return true;
		});

		mReplaceBox.addOnEditingDone(delegate void (CellEditableIF)
		{
			auto x = mReplaceBox.getIndex(mReplaceBox.getActiveText());
			if(x >= 0) return;
			mReplaceBox.prependText(mReplaceBox.getActiveText());
			return;
		});

		mReplaceButton.addOnClicked(delegate void(Button){ReplaceText();});
		mReplaceGoButton.addOnClicked(delegate void (Button){ReplaceText(Advance);});
		mReplaceAllButton.addOnClicked(delegate void (Button){ReplaceAll();});

		mTree.addOnCursorChanged (delegate void (TreeView)
		{
			if(mUpdatingMStore) return;
			if(mSearchResults.length == 0) return;
			TreePath tp = new TreePath;
			TreeIter ti = new TreeIter;
			TreeViewColumn tvc = new TreeViewColumn;

			mTree.getCursor(tp, tvc);

			if(tp is null) return;

			mStore.getIter(ti, tp);

			string file = ti.getValueString(0);
			int line = ti.getValueInt(1);
			if(DocMan.GoTo(file.absolutePath(), line) == false) return;

			int itemIndex = tp.getIndices()[0];

			auto tmpdoc = DocMan.GetDoc(mSearchResults[itemIndex].DocFile);
			if(tmpdoc is null) return;
			tmpdoc.HiliteSearchResult(mSearchResults[itemIndex].Line, mSearchResults[itemIndex].OffsetStart, mSearchResults[itemIndex].OffsetEnd);
		});

		mCaseSensitive.addOnToggled(&Find);
		mRegex.addOnToggled(&Find);
		mStartsWord.addOnToggled(&Find);
		mEndsWord.addOnToggled(&Find);
		mRecursion.addOnToggled(&Find);
		mFolder.addOnToggled(&Find);
		mCurrentDocument.addOnToggled(&Find);
		mOpenDocuments.addOnToggled(&Find);
		mProjectSourceOnly.addOnToggled(&Find);
		mProjectAll.addOnToggled(&Find);

		mMarkAllButton.addOnToggled(delegate void(ToggleButton){MarkAll();});

		AddIcon("dcmp-search", SystemPath("resources/spectacle.png"));
		AddAction("ActSearch", "Search", "Seek out that which is hidden", "dcmp-search", "<Control>F", delegate void(Action a)
		{
			if(DocMan.Current)
			{
				auto word = DocMan.Current.Word();
				if(word.length > 0)
				{
					mSearchBox.prependText(word);
					mSearchBox.setActiveText(word);
				}
			}
			mExtraPane.setCurrentPage(mRoot);
			mSearchBox.grabFocus();
		});
		AddToMenuBar("ActSearch", mRootMenuNames[0]);
		//AddToToolBar("ActSearch");

		AddExtraPage(mRoot, "Search");

		mExtraPane.setTabReorderable(mRoot, 1);

		Log.Entry("Engaged");

	}

	void PostEngage()
	{
		//load combox strings

		string[] PastSearches = Config.GetArray("ui_search","search_strings", ["one", "two", "three"]);
		mSearchBox.removeAll();
		foreach(oldsearch; PastSearches)mSearchBox.appendText(oldsearch);

		string[] PastReplaces = Config.GetArray("ui_search", "replace_strings", ["one", "two", "three"]);
		mReplaceBox.removeAll();
		foreach(oldreplace; PastReplaces)mReplaceBox.appendText(oldreplace);

		//mExtraPane.reorderChild(mRoot, Config.GetValue("ui_search", "page_position", 0));

		uiContextMenu.AddAction("ActSearch");
		Log.Entry("PostEngaged");
	}

	void Disengage()
	{

		//store last 20 search and replace strings
		auto ti = new TreeIter;
		auto model = mSearchBox.getModel();
		auto number = model.iterNChildren(null);
		if(number > 20) number = 20;
		Config.SetArray("ui_search","search_strings");
		foreach(ndx; 0..number)
		{
			model.iterNthChild(ti, null, ndx);
			Config.AppendValue("ui_search","search_strings", model.getValueString(ti,0));
		}
		model = mReplaceBox.getModel();
		number = model.iterNChildren(null);
		if(number > 20) number = 20;
		Config.SetArray("ui_search", "replace_strings");
		foreach(ndx; 0..number)
		{
			model.iterNthChild(ti, null, ndx);
			Config.AppendValue("ui_search", "replace_strings", model.getValueString(ti, 0));
		}

		Config.SetValue("ui_search", "page_position", mExtraPane.pageNum(mRoot));


		Log.Entry("Disengaged");
	}
}
