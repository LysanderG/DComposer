module assistant;

import dcore;
import elements;
import ui;

import std.traits;
import std.algorithm;
import std.array;
import std.stdio;
import std.regex;
import std.conv;
import std.string;



import gtk.Builder;
import gtk.Paned;
import gtk.Label;
import gtk.TreeView;
import gtk.ListStore;
import gtk.TreePath;
import gtk.TreeViewColumn;

import glib.SimpleXML;


export extern (C) string GetClassName()
{
	return fullyQualifiedName!ASSISTANT;
}

class ASSISTANT :ELEMENT
{
	private:

	Paned	mRoot;
	Label 	mTitle;
	Label	mSignature;
	Label	mDocumentation;
	TreeView mChildView;
	ListStore mChildStore;

	TreeView mMatchesView;
	ListStore mMatchesStore;

	DSYMBOL[] CollectedSymbols;



	void CatchSymbols(DSYMBOL[] EmittedSymbols)
	{

		if(EmittedSymbols.length < 1) return;

		CollectedSymbols = EmittedSymbols.dup;
		mMatchesStore.clear();

		auto ti = new TreeIter;
		foreach(uint i, sym; CollectedSymbols)
		{
			mMatchesStore.append(ti);
			mMatchesStore.setValue(ti, 0, sym.Icon);
			mMatchesStore.setValue(ti, 1, sym.Path);
			mMatchesStore.setValue(ti, 2, sym.Name);
			mMatchesStore.setValue(ti, 3, i);
		}
		mMatchesView.setCursor(new TreePath(true), null, false);
		UpdateGUI(CollectedSymbols[0]);
	}


	void CollectSymbols(DSYMBOL[] EmittedSymbols)
	{

		if(EmittedSymbols.length < 1) return;

		mChildStore.clear();

		//CollectedSymbols = EmittedSymbols.dup;

		mMatchesView.getSelection.unselectAll();
		mMatchesStore.clear();
		auto ti = new TreeIter;
		foreach(uint i, sym; CollectedSymbols)
		{
			mMatchesStore.append(ti);
			mMatchesStore.setValue(ti, 0, sym.Icon);
			mMatchesStore.setValue(ti, 1, sym.Path);
			mMatchesStore.setValue(ti, 2, sym.Name);
			mMatchesStore.setValue(ti, 3, i);
		}
		//AssistSymbol(CollectedSymbols[0]);
		mMatchesView.setCursor(new TreePath(true), null, false);
	}


	void UpdateGUI(DSYMBOL SymVal)
	{
		mTitle.setText(SymVal.Path);
		mSignature.setText(SymVal.Signature);

		dstring comments = replace(to!dstring(SymVal.Comment),"&"d, "&amp;"d);
		comments = replace(comments, "<"d, "&lt;"d);
		mDocumentation.setMarkup(to!string(comments.PlainText()));

		auto ti = new TreeIter;
		mChildStore.clear();
		mChildStore.append(ti);
		mChildStore.setValue(ti, 0, "-");
		mChildStore.setValue(ti, 1, "..");
		mChildStore.setValue(ti, 2, "parent");
		mChildStore.setValue(ti, 3, -1);

		foreach(uint indx, kid; SymVal.Children)
		{
			mChildStore.append(ti);
			mChildStore.setValue(ti, 0, kid.Icon);
			mChildStore.setValue(ti, 1, kid.Name);
			mChildStore.setValue(ti, 2, kid.Path);
			mChildStore.setValue(ti, 3, indx);
		}

	}

	void ActionAssist()
	{
		if(DocMan.Current is null)return;
		auto symCandidate = DocMan.Current.FullSymbol();

		if(symCandidate.length < 1) return;

		auto dsyms = Symbols.GetCompletions(symCandidate.split('.'));
		if(dsyms.length < 1) return;

		Symbols.emit(dsyms);
	}

	void AssistSymbol(DSYMBOL SymVal)
	{
		mTitle.setText(SymVal.Path);
		mSignature.setText(SymVal.Signature);

		dstring comments = replace(to!dstring(SymVal.Comment),"&"d, "&amp;"d);
		comments = replace(comments, "<"d, "&lt;"d);
		mDocumentation.setMarkup(to!string(comments.PlainText()));


		auto ti = new TreeIter;
		mChildStore.clear();
		mChildStore.append(ti);
		mChildStore.setValue(ti, 0, "-");
		mChildStore.setValue(ti, 1, "..");
		mChildStore.setValue(ti, 2, "parent");
		mChildStore.setValue(ti, 3, -1);

		foreach(uint indx, kid; SymVal.Children)
		{
			mChildStore.append(ti);
			mChildStore.setValue(ti, 0, kid.Icon);
			mChildStore.setValue(ti, 1, kid.Name);
			mChildStore.setValue(ti, 2, kid.Path);
			mChildStore.setValue(ti, 3, indx);
		}
	}


	public:

	string Name(){
		return "Assistant";
	}
	string Info(){
		return "View symbol documentation with limited browsing";
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
		LoadMacros();

		auto builder = new Builder;
		builder.addFromFile(Config.GetValue("assistant", "glade_file", ConfigPath("elements/resources/assistant.glade")));

		mRoot = cast(Paned)builder.getObject("root");
		mTitle = cast(Label)builder.getObject("labelpath");
		mSignature = cast(Label)builder.getObject("labelsignature");
		mDocumentation = cast(Label)builder.getObject("labeldoc");
		mChildView = cast(TreeView)builder.getObject("treeview");
		mChildStore = cast(ListStore)builder.getObject("childstore");

		mMatchesView = cast(TreeView)builder.getObject("treeview2");
		mMatchesStore = cast(ListStore)builder.getObject("overloadstore");


		ui.AddExtraPage(mRoot, Name);

		mMatchesView.addOnCursorChanged( delegate void(TreeView)
		{
			auto ti = mMatchesView.getSelectedIter();
			if (ti is null) return;
			auto index = ti.getTreePath(). getIndices()[0];
			UpdateGUI(CollectedSymbols[index]);
		});

		mChildView.setActivateOnSingleClick(1);
		mChildView.addOnRowActivated(delegate void(TreePath tp, TreeViewColumn tvc , TreeView tv)
		{
			auto ti0 = mMatchesView.getSelectedIter();
			if(ti0 is null) return;
			auto ti = new TreeIter;
			if(!mChildStore.getIter(ti, tp)) return;

			auto symIndex = ti0.getValueInt(3);
			auto childIndex = ti.getValueInt(3);

			if(childIndex < 0) //.. parent selected
			{
				//lets get parent path
				auto ParentPathIndex = lastIndexOf(CollectedSymbols[symIndex].Path, '.');
				if(ParentPathIndex < 1)
				{
					return;
				}
				auto ParentPath = CollectedSymbols[symIndex].Path[0..ParentPathIndex];
				auto Parent = Symbols.FindExact(ParentPath);
				CatchSymbols(Parent);
				return;
			}
			CatchSymbols([CollectedSymbols[symIndex].Children[childIndex]]);
		});

		AddIcon("dcmp-symbol-assist", Config.GetValue("icons", "symbol-assist", ConfigPath("elements/resources/question-frame.png")));
		auto ActSymbolAssit = "ActSymbolAssist".AddAction("Symbol Assist", "See documentation for symbol", "dcmp-symbol-assist", "F1",delegate void (Action){ActionAssist();});
		AddToMenuBar("ActSymbolAssist", "E_lements");
		uiContextMenu.AddAction("ActSymbolAssist");

		Symbols.connect(&CatchSymbols);

		Log.Entry("Engaged");
	}

	void Disengage()
	{
		RemoveExtraPage(mRoot);
		mRoot.destroy();
		Log.Entry("Disengaged");
	}

	void Configure()
	{
		//gonna have to remove this from ELEMENT interface
	}
}


//======================================================================================================================
// stuff to expand macros  PlainText should be called MarkUpText


dstring PlainText(dstring Input)
{
	dstring rvText;
	dstring macroText;


	//expand all macros
	while(true)
	{
		auto macroSplit = Input.findSplit("$(");

		if(macroSplit[1].empty)
		{
			rvText ~= macroSplit[0];
			break;
		}
		macroText = macroSplit[2].toRightParen();


		rvText ~= macroSplit[0];

		auto tmpText = MacroReplace(macroText);
		rvText ~= PlainText(tmpText);
		Input = macroSplit[2].fromRightParen();
	}

	//

	return rvText;
}


dstring toRightParen(dstring Text)
{
	dstring rvStr;
	int Pctr;

	foreach(ch; Text)
	{
		if(ch == '(') Pctr++;
		if(ch == ')') Pctr--;
		if(Pctr < 0) return rvStr;
		rvStr ~= ch;
	}
	//error here unbalanced parens
	return " unbalanced parens ";
}

dstring fromRightParen(dstring Text)
{
	dstring rvStr;
	int Pctr;

	foreach(indx, ch; Text)
	{
		rvStr = Text[indx .. $];
		if(ch == '(') Pctr++;
		if(ch == ')')Pctr--;
		if(Pctr < 0)
		{
			if(rvStr.length > 0) rvStr=rvStr[1..$];
			return rvStr;
		}

	}
	return " unbalanced Parens ";
}


dstring MacroReplace(dstring Text)
{
	dstring macName;
	dstring Arguments;
	dstring[] Arg;
	dstring ArgPlus;
	dstring rvText;

	//get macro name
	foreach(indx, ch; Text)
	{
		if(ch.isSymbolCharacter) macName ~= ch;
		else break;
	}
	if (macName == Text) //no arguments like $(TITLE)
	{

		return GetMacro(macName);
	}
	Text = Text[macName.length+1.. $]; //$(D someSymbolName)
	//get arguments ... arg zero
	Arguments = Text;

	Arg ~= Arguments;

	//1--9
	auto splits = Arguments.splitter(",");
	foreach (indx, substr; split(Arguments, ','))
	{
		Arg ~= substr; // goes past nine but ... it shouldn't crash
	}

	ArgPlus = Text.findSplitAfter(",")[1];


	dstring macText = GetMacro(macName);

	dstring rpltxt(Captures!(dstring) match)
	{
		switch(match.hit)
		{
			case "$0" : return Arguments;
			case "$1" : return Arg[1];
			case "$2" : return Arg[2];
			case "$3" : return Arg[3];
			case "$4" : return Arg[4];
			default : return "";
		}
	}


	rvText = replaceAll!(rpltxt)(macText, regex(`\$\d`d));

	return rvText;

}

bool isSymbolCharacter(dchar Char)
{
	return "_0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".canFind(Char);
}


dstring[dstring] Macro;

void LoadMacros()
{
	Macro["TITLE"] = __MODULE__;
	Macro["D"] = "$(BLUE $0)";
	Macro["X"] = "<<$(D $0)>> $(TITLE)";
	Macro["HIS_NAME"] = "Mr. $3, Mr. $2 and Mr. $1";
	Macro["HER_NAME"] = "Ms. $1, Ms. $2 and Ms. $3\n---\n$(D $0)\n---\n";

	Macro["B"] = "<b>$0</b>";
	Macro["I"] = "<i>$0</i>";
	Macro["U"] = "<u>$0</u>";
	Macro["P"] = "$(BR)$0$(BR)";
	Macro["DL"] = "$0$(BR)";
	Macro["DT"] = "$0 :$(BR)";
	Macro["DD"] = "\t$(I $0)$(BR)";
	Macro["TABLE"] = "===============$(BR)$0$(BR)===============$(BR)";
	Macro["TR"] = "$0$(BR)";
	Macro["TH"] = "\t$(U $0)\t";
	Macro["TD"] = "$0\t\t\t";
	Macro["OL"] = "$0$(BR)";
	Macro["UL"] = "$0$(BR)";
	Macro["LI"] = "\t* $0$(BR)";
	Macro["BIG"]= "<big>$0</big>";
	Macro["SMALL"] = "<small>$0</small>";
	Macro["BR"] = "\n";
	Macro["LINK"] = "$(BLUE $0)";
	Macro["LINK2"] = "$(BLUE $1) $(GRAY [$2])";
	Macro["GRAY"] = `<span foreground="#777777">$0</span>`;
	Macro["BLUE"] = `<span foreground="blue">$0</span>`;
	Macro["RED"] = `<span foreground="red">$0</span>`;
	Macro["GREEN"] = `<span foreground="green">$0</span>`;
	Macro["BLACK"] = `<span foreground="black">$0</span>`;
	Macro["WHITE"] = `<span foreground="white">$0</span>`;
	Macro["D_CODE"] = `$(BR)----$(BR)<span background="#777777">$0</span>$(BR)----$(BR)`;
	Macro["DDOC"] = "$0";

	//just some stuff I'm randomly doing as I see ugly docs
	Macro["TDNW"] = "$(TD $(U $0))$(BR)";
	Macro["LESS"] = "&lt;";
	Macro["GREATER"] = "&gt;";

}

dstring GetMacro(dstring MacroName)
{
	auto m = (MacroName in Macro);

	if(m is null) return "$0";
	return Macro[MacroName];
}
