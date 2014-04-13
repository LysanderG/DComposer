module symbolview;


import dcore;
import ui;
import elements;


import std.traits;

export extern (C) string GetClassName()
{
	return fullyQualifiedName!SYMBOL_VIEW;
}

class SYMBOL_VIEW :ELEMENT
{
	public:

	string Name(){
		return "Symbol View";
	}
	string Info(){
		return "Way to browse library and project symbols.";
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

		builder.addFromFile(Config.GetValue("symbolview", "glade_file", ConfigPath("elements/resources/symbolview.glade")));

		mRoot = cast(Box)builder.getObject("box1");
		mTree = cast(TreeView)builder.getObject("treeview1");
		mStore = cast(TreeStore)builder.getObject("treestore1");
		mRefresh = cast(Button)builder.getObject("button1");

		foreach(sym; Symbols.Modules())FillModel(sym);

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

		AddSidePage(mRoot, Name);


	}

	void Disengage()
	{
		RemoveSidePage(mRoot);
		mRoot.destroy();
		mRoot = null;

		Log.Entry("Disengaged");
	}

	void Configure()
	{
		//gonna have to remove this from ELEMENT interface
	}

	private:

	Box       mRoot;
	TreeView  mTree;
	TreeStore mStore;
	Button    mRefresh;

	void FillModel(DSYMBOL symbol)
	{
		string tooltip;

		void FillKid(DSYMBOL xsym, TreeIter ParentTI = null)
		{
			auto ti = new TreeIter;

			if(xsym.Signature.length == 0) tooltip = xsym.Path;
			else tooltip = xsym.Signature;

			mStore.append(ti, ParentTI);
			mStore.setValue(ti, 0, xsym.Icon);
			mStore.setValue(ti, 1, xsym.Name);
			mStore.setValue(ti, 2, xsym.Path);
			mStore.setValue(ti, 3, xsym.File);
			mStore.setValue(ti, 4, tooltip);
			mStore.setValue(ti, 5, xsym.Line);

			foreach(kid; xsym.Children)
			{
				FillKid(kid, ti);
			}
		}
		FillKid(symbol);
	}


	void RowActivated(TreePath tp, TreeViewColumn tvc, TreeView me)
	{
		auto ti = new TreeIter;

		mStore.getIter(ti, tp);
		auto jumpFile = mStore.getValueString(ti, 3);
		auto jumpLine = mStore.getValueInt(ti, 5);

		DocMan.Open(jumpFile, jumpLine);
	}
}


