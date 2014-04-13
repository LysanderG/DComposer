module moduleview;


import gtk.Builder;
import gtk.Box;
import gtk.Label;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.Widget;
import gtk.TreeIter;
import gtk.Bin;

import gobject.Value;

import dcore;
import ui;
import elements;
import document;

import std.traits;
import std.path;
import std.file;


export extern (C) string GetClassName()
{
	return fullyQualifiedName!MODULE_VIEW;
}


class MODULE_VIEW : ELEMENT
{
private:

	Box mRoot;
	Label mTitle;
	TreeView mTree;
	TreeStore mModel;
	Label mDisclaimer;
	string[string] mSavedPaths;


	void WatchDocMan(string Event, DOC_IF Doc)
	{
		if((Event == "Open") || (Event == "Create"))
		{
			mSavedPaths[Doc.Name] = "0";//new TreePath;
		}

		if(Event == "Close")
		{
			mSavedPaths.remove(Doc.Name);
		}
	}


	void FillModel(DSYMBOL symbol)
	{
		string tooltip;

		mTitle.setText(symbol.Path);

		void FillKid(DSYMBOL xsym, TreeIter ParentTI = null)
		{
			auto ti = new TreeIter;

			if(xsym.Signature.length == 0) tooltip = xsym.Path;
			else tooltip = xsym.Signature;

			mModel.append(ti, ParentTI);
			mModel.setValue(ti, 0, xsym.Icon);
			mModel.setValue(ti, 1, xsym.Name);
			mModel.setValue(ti, 2, xsym.Path);
			mModel.setValue(ti, 3, xsym.File);
			mModel.setValue(ti, 4, tooltip);
			mModel.setValue(ti, 5, xsym.Line);

			foreach(kid; xsym.Children)
			{
				FillKid(kid, ti);
			}
		}
		FillKid(symbol);
	}


	void WatchPageSwitch(Bin wydjit)
	{
		//get old pages tp
		auto tp = new TreePath;
		auto tvc = new TreeViewColumn;
		mTree.getCursor(tp, tvc);
		if(tp is null) tp = new TreePath(true);
		if(DocMan.Current !is null)	mSavedPaths[DocMan.Current.Name] = tp.toString();
		//set tp hopefully
		string newDocsName;
		scope(success)
		{
			if(newDocsName in mSavedPaths)
			{
				mTree.expandToPath(new TreePath(mSavedPaths[newDocsName]));
				mTree.scrollToCell(new TreePath(mSavedPaths[newDocsName]), cast(TreeViewColumn)null, 1, 0.5, 0.0);
				//mTree.setCursor(new TreePath(mSavedPaths[newDocsName]), cast(TreeViewColumn)null, false);
			}
		}


		mModel.clear();
		DSYMBOL modSyms;

		//step 1 make sure there is a document
		auto xDoc = cast(DOCUMENT)wydjit.getChild();
		if(xDoc is null) return;

		mTitle.setText(xDoc.Name.baseName);
		newDocsName = xDoc.Name;

		//step 2 only d src files
		if(!( (xDoc.Name.extension() == ".d") || (xDoc.Name.extension() == ".di"))) return;

		//step 3 is it in a autoloaded package
		modSyms = Symbols.GetModuleFromFileName(xDoc.Name);
		if(modSyms)
		{
			FillModel(modSyms);
			return;
		}

		//step 4 do we already have a tagfile
		string tagFileName = ConfigPath(buildNormalizedPath("tags/", "moduleview/", xDoc.Name.baseName));
		tagFileName ~= ".json";

		if(tagFileName.exists())
		{
			if(tagFileName.timeLastModified() > xDoc.Name.timeLastModified())
			{
				modSyms = Symbols.LoadFile(tagFileName);
				Symbols.AddModule(modSyms.Name, modSyms);
				FillModel(modSyms);
				return;
			}
		}

		//step 5 create a tag file
		if(DocMan.Compile(xDoc, ["-J.","-I.", "-Ideps/dson", "-Isrc","-Ielements/src", "-D", "-X", "-Xf" ~ tagFileName]))
		{
			modSyms = Symbols.LoadFile(tagFileName);
			Symbols.AddModule(modSyms.Name, modSyms);
			FillModel(modSyms);
		}


		//step 6 give up and go home
	}

	void RowActivated(TreePath tp, TreeViewColumn tvc, TreeView me)
	{
		auto ti = new TreeIter;

		mModel.getIter(ti, tp);
		auto jumpFile = mModel.getValueString(ti, 3);
		auto jumpLine = mModel.getValueInt(ti, 5);

		DocMan.Open(jumpFile, jumpLine);
	}



public:

	string Name(){
		return "Module view";
	}
	string Info(){
		return "Browsable list of symbols in current module";
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
		builder.addFromFile(Config.GetValue("module_view", "glade_file", ConfigPath("elements/resources/moduleview.glade")));
		mRoot = cast(Box) builder.getObject("box1");
		mTitle = cast(Label) builder.getObject("title");
		mTree = cast(TreeView) builder.getObject("treeview1");
		mModel = cast(TreeStore) builder.getObject("treestore1");
		mDisclaimer = cast(Label) builder.getObject("label2");

		mDisclaimer.setText("Holy crap this thing doesn't update dynamically!!  When it can update it only updates when the module can compile.");
		ui.AddSidePage(mRoot, Name);

		DocBook.addOnSwitchPage (delegate void (Widget wydjit, guint, Notebook){WatchPageSwitch(cast(Bin)wydjit); });
		mTree.addOnRowActivated(&RowActivated);
		mTree.addOnCursorChanged(delegate void (TreeView)
		{

			auto ti = new TreeIter;
			ti = mTree.getSelectedIter();
			if(ti is null) return;
			string path = ti.getValueString(2);
			if(path.length < 1) return;
			auto sym = Symbols.FindExact(path);
			if(sym.length < 1) return;
			Symbols.emit(sym);
		});

		DocMan.Event.connect(&WatchDocMan);


		Log.Entry("Engaged");

	}
	void Disengage()
	{
		RemoveSidePage(mRoot);
		mRoot.destroy;
		Log.Entry("Disengaged");
	}

	void Configure()
	{
	}
}

