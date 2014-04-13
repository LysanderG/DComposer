module gotosymbol;



import dcore;
import ui;
import elements;


import std.traits;
import std.array;

export extern (C) string GetClassName()
{
	return fullyQualifiedName!GOTO_SYMBOL;
}

class GOTO_SYMBOL :ELEMENT
{

	public:

	string Name(){
		return "Goto symbol";
	}
	string Info(){
		return "Find a symbol declaration and show its source.";
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
		AddIcon("dcmp-goto-symbol",Config.GetValue("gotosymbol","icon_file", SystemPath("resources/road-sign.png")));
		auto ActGotoSymbol = "ActGotoSymbol".AddAction("Goto Symbol", "Find symbol declaration source", "dcmp-goto-symbol", "<Control>F2",delegate void(Action a){Jump();});
		AddToMenuBar("ActGotoSymbol", "E_lements");
		uiContextMenu.AddAction("ActGotoSymbol");
		Log.Entry("Engaged");
	}

	void Disengage()
	{

		Log.Entry("Disengaged");
	}

	void Configure()
	{
		//gonna have to remove this from ELEMENT interface
	}


	private:

	void Jump()
	{
		dwrite("we are in Jump!");
		dwrite(DocMan.Current);
		if(DocMan.Current is null) return;
		dwrite("wtf");
		string jumpSym = DocMan.Current.FullSymbol;
		dwrite("the symbol = ", jumpSym);
		auto result = Symbols.GetCompletions(jumpSym.split("."));
		dwrite("found matching symbols = ",result);
		if(result.length < 1) return;
		DocMan.GoTo(result[0].File, result[0].Line);
		dwrite("hmmm");
	}
}
