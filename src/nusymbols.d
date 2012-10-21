module symbols;

import std.algorithm;
import std.datetime;
import std.file;
import std.json;
import std.signals;
import std.string;
import std.path;

import dcore;

enum SymKind
{
	ALIAS,
	CLASS,
	CONSTRUCTOR,
	ENUM,
	ENUM_MEMBER,
	FUNCTION,
	INTERFACE,
	MODULE,
	PACKAGE,
	STRUCT,
	TEMPLATE,
	UNION,
	VARIABLE
}




class DSYMBOL
{
	string			Name;			///Symbols name
	string			Path;			///Full scope/path of symbol id (std.stdio.File.open, std.file.readText, etc)
	string[]		Scope;			///path as an array of strings (["std", "stdio", "File", "open"] ; [ "std", "file", "readText"])

	SymKind			Kind;			///what kind of symbol
	string			FullType;		///fully QUALIFIED type of the symbol
	string			Type;			///the UNQUALIFIED type of the symbol (drops trusted, safe, const, etc ... not sure about [] yet)
	string			Signature;		///actual signature as at declaration
	string			Protection;		///private package protected public export

	string			Comment;		///actual comments from source (if ditto, will be the 'dittoed' comment)

	string			File;
	int				Line;

	string			Base;
	DSYMBOL[]		Children;
	string			Icon;
}


class SYMBOLS
{
	private:

	bool			mAutoLoad;					//if symbols should be loaded at startup
	SysTime			mLastLoadTime;				//speed things up by not reloading unchanged files

	string			mProjectKey;				//key for project mSymbols

	DSYMBOL[string] mSymbols;


	//called at startup if mautoload is true
	void AutoLoadPackages()
	{
		mLastLoadTime  = Clock.currTime();
		auto PackageKeys = Config.getKeys("SYMBOL_LIBS");

		foreach(pckgkey; PackageKeys)
		{
			auto tagfile = Config.getString("SYMBOLS_LIBS", pckgkey, "");
			auto NewSymbols = LoadPackage(pckgkey, tagfile);
			if(NewSymbols) mSymbols[pckgkey] = NewSymbols;
		}
	}

	//actual work done to load symbols here!
	void BuildPackage(DSYMBOL CurrSym, JSONValue SymData)
	{
		static string LastComment = "";
		static string CurrFile = "";

		void SetSymbolKind(string KindAsString)
		{
			switch (KindAsString)
			{
				case "alias"		:CurrSym.Kind= SymKind.ALIAS		;break;
				case "class"		:CurrSym.Kind= SymKind.CLASS		;break;
				case "constructor"	:CurrSym.Kind= SymKind.CONSTRUCTOR	;break;
				case "enum"			:CurrSym.Kind= SymKind.ENUM			;break;
				case "enum member"	:CurrSym.Kind= SymKind.ENUM_MEMBER	;break;
				case "function"		:CurrSym.Kind= SymKind.FUNCTION		;break;
				case "interface"	:CurrSym.Kind= SymKind.INTERFACE	;break;
				case "module"		:CurrSym.Kind= SymKind.MODULE		;break;
				case "package"		:CurrSym.Kind= SymKind.PACKAGE		;break;
				case "struct"		:CurrSym.Kind= SymKind.STRUCT		;break;
				case "template"		:CurrSym.Kind= SymKind.TEMPLATE		;break;
				case "union"		:CurrSym.Kind= SymKind.UNION		;break;
				case "variable"		:CurrSym.Kind= SymKind.VARIABLE		;break;
				default : Log.Entry("Unrecognized symbol kind " ~ KindAsString, "Error");
			}
		}


		void SetSymbolType(string FullType)
		{
			CurrSym.FullType = FullType;
			if(CurrSym.Kind == SymKind.FUNCTION)
			{
				auto splits = FullType.findSplit("(");
				if (splits[0].length < 1) splits[0] = "auto ";
				CurrSym.Signature = splits[0] ~ CurrSym.Name ~ splits[1] ~ splits[2];
				splits[0] = splits[0].removechars("[]");
				splits[0] = splits[0].removechars("shared");
				splits[0] = splits[0].removechars("immutable");
				splits[0] = splits[0].removechars("const");
				splits[0] = splits[0].removechars("inout");
				splits[0] = splits[0].removechars("nothrow");
				splits[0] = splits[0].removechars("pure");
				splits[0] = splits[0].removechars("@");
				splits[0] = splits[0].removechars("property");
				splits[0] = splits[0].removechars("safe");
				splits[0] = splits[0].removechars("trusted");
				CurrSym.Type = splits[0];
			}
			else
			{
				CurrSym.Signature = FullType;
				CurrSym.Type = FullType;
			}
		}

		//set the comments ... complicated because of the ddoc ditto statement
		//hopefully this will always be in the corrent order
		void SetSymbolComment(string comment)
		{
			if(comment == "ditto")
			{
				CurrSym.Comment = LastComment;
				return;
			}
			LastComment = comment;
			CurrSym.Comment = comment;
		}


		switch (SymData.type)
		{
			case JSON_TYPE.ARRAY :
			{
				DSYMBOL SubSym;
				foreach(jval; SymData.array)
				{
					SubSym = new DSYMBOL;
					SubSym.Path = CurrSym.Path;		//these two lines are important!
					SubSym.Scope = CurrSym.Scope;
					BuildPackage(SubSym, jval);
					CurrSym.Children ~= SubSym;
				}
				break;
			}
			case JSON_TYPE.OBJECT:
			{
				foreach(key, obj; SymData.object)
				{
					switch (key)
					{
						case "name" 		: CurrSym.Name = obj.str; break;
						case "kind" 		: SetSymbolKind(obj.str); break;
						case "type" 		: SetSymbolType(obj.str); break;
						case "protection"	: CurrSym.Protection = obj.str; break;
						case "comment"		: SetSymbolComment(obj.str); break;
						case "file"			: CurrFile = obj.str; break;
						case "line"			: CurrSym.Line = cast(int)obj.integer; break;
						case "base"			: CurrSym.Base = obj.str; break;
						default : Log.Entry("Unrecognized object " ~ key, "Error");break;
					}
				}

				//fix ups
				//name
				if(CurrSym.Name is null) CurrSym.Name = baseName(CurrFile.chomp(".d")); //for files without the module statement
				if(CurrSym.Kind == SymKind.MODULE) //get rid of std. or gtk. etc
				{
					auto indx = CurrSym.Name.countUntil(".");
					if(indx > -1) CurrSym.Name = CurrSym.Name[indx+1 .. $];
				}
				//path
				CurrSym.Path ~= "." ~ CurrSym.Name;

				//scope
				CurrSym.Scope ~= CurrSym.Name;

				//File
				CurrSym.File = CurrFile;

				//icon
				CurrSym.Icon = GetIcon(CurrSym);

				//children
				if("members" in SymData.object) BuildPackage(CurrSym, SymData.object["members"]);

				break;
			}
			default :
			{
				Log.Entry("Unexpected json value", "Error");
			}
		}
	}

	string[] GetScopedCandidate(string Candidate)
	{
		Candidate = Candidate.chomp(".");
		auto range = Candidate.splitter(".");
		string[] rv;
		foreach(itm; range) rv ~= itm;
		return rv;
	}
	//given a package name and a json file loads the symbols and returns them
	DSYMBOL LoadPackage(string PackageName, string TagFile)
	{
		scope(failure)
		{
			Log.Entry("Unable to load Symbol file: " ~ TagFile, "Error");
			return null;
		}

		auto SymbolJson = readText(TagFile);

		DSYMBOL X = new DSYMBOL;

		X.Name 		= PackageName;
		X.Path 		= PackageName;
		X.Scope 	= [PackageName];

		X.Kind		= SymKind.PACKAGE;
		X.FullType	= "package";
		X.Type		= "package";
		X.Signature = "package";
		X.Comment	= "";

		X.File		= "";
		X.Line		= 0;

		X.Base		= "";
		X.Children.length = 0;
		X.Icon		= GetIcon(X);

		BuildPackage(X, parseJSON(SymbolJson));

		return X;
	}

	void WatchProject(ProEvent Event)
	{
		switch (Event)
		{
			case ProEvent.Closing  				:
												{
													mSymbols.remove(mProjectKey);
													emit();
													return;
												}
			case ProEvent.CreatedTags			:
												{
													scope(failure){Log.Entry("Failed to load project symbols", "Error");return;}
													mSymbols[mProjectKey] = LoadPackage(mProjectKey, buildPath(Project.WorkingPath, mProjectKey ~".tags"));
													return;
												}
			case ProEvent.FailedTags			:
												{
													scope(failure){Log.Entry("Failed to load project symbols","Error");return;}
													if(Project.Name() in mSymbols) return; //keep the symbols we have if none try to load old symbols
													mSymbols[mProjectKey] = LoadPackage(mProjectKey, buildPath(Project.WorkingPath, mProjectKey ~".tags"));
													return;
												}
			case ProEvent.NameChanged			:
												{
													mProjectKey = Project.Name;
													return;
												}
		    default :break;
		}

    }


	public:

	this()
	{
	}

	void Engage()
	{
		mAutoLoad = Config.getBoolean("SYMBOLS", "auto_load_symbols", true);

		if(mAutoLoad) AutoLoadPackages();

		Project.Event.connect(&WatchProject);
		Config.Reconfig.connect(&Configure);

		string x = "Engaged SYMBOLS [";
        foreach(ii, key; mSymbols.keys){if(ii != 0)x ~= `,`; x ~= `"` ~ key ~`"`;}
        x ~= "]";
        Log().Entry(x);
	}

	void Disengage()
	{
		Log().Entry("Disengaged SYMBOLS");
	}

	void Configure()
	{
		mAutoLoad = Config.getBoolean("SYMBOLS", "auto_load_symbols", true);

		string[] keys = Config().getKeys("SYMBOL_LIBS");

		foreach(key; keys)
		{
			scope(failure)continue;

			string jsonfile = Config.getString("SYMBOL_LIBS", key);
			if( (key in mSymbols) && (jsonfile.timeLastModified() <= mLastLoadTime)) continue;
			mSymbols[key] = LoadPackage(key, jsonfile);
		}

	}

	void SelectSymbol(string FullPathName)
	{
	}

	DSYMBOL GetSelectedSymbol()
	{
		return new DSYMBOL;
	}

	DSYMBOL[] GetCompletions(string Candidate)
	{

		return null;
	}

	DSYMBOL[] GetMembers(string Candidate)
	{
		string[] ScopedCandidate = GetScopedCandidate(Candidate);
		ulong	ScopeElements = ScopedCandidate.length;

		DSYMBOL[] rvSymbols;

		void CheckSymbol(DSYMBOL chksym)
		{
			foreach(kid; chksym.Children) CheckSymbol(kid);

			//wierd template check kind of skips template symbol and looks at 'eponymous' member
			if(chksym.Kind == SymKind.TEMPLATE)
			{
				string[] tmp = ScopedCandidate;
				tmp[$-1] = chksym.Name;
				tmp ~= ScopedCandidate[$-1];
				string subtmp;
				foreach(s; tmp.joiner("."))subtmp ~= s;
				rvSymbols ~= GetMembers(subtmp);
			}


			//cant be this one
			if(chksym.Scope.length < ScopeElements) return;

			//or this one
			if(chksym.Scope[0..$-ScopeElements] != ScopedCandidate) return;

			rvSymbols ~= chksym.Children;

			if(chksym.Base.length > 0) rvSymbols ~= GetMembers(chksym.Base);
			if(chksym.Kind == SymKind.FUNCTION) rvSymbols ~= GetMembers(chksym.Type);
			if(chksym.Kind == SymKind.VARIABLE) rvSymbols ~= GetMembers(chksym.Type);
			if(chksym.Kind == SymKind.ALIAS)	rvSymbols ~= GetMembers(chksym.Type);
		}

		foreach(symbol; mSymbols) CheckSymbol(symbol);

		return rvSymbols;
	}

	DSYMBOL[] GetCallTips(string Candidate)
	{
		return null;
	}


	mixin Signal!();
}





string GetIcon(DSYMBOL X)
{
	string color;
	string rv;

	switch(X.Protection)
	{
		case "private"      : color = `<span foreground="red">`;break;
		case "public"       : color = `<span foreground="black">`;break;
		case "protected"    : color = `<span foreground="cyan">`;break;
		case "package"      : color = `<span foreground="green">`;break;
		default : color = `<span foreground="green">`;
	}

	switch(X.Kind)
	{
		case SymKind.MODULE			:rv = color ~ `Ⓜ</span>`;break;
		case SymKind.TEMPLATE       :rv = color ~ `Ⓣ</span>`;break;
		case SymKind.FUNCTION       :rv = color ~ `⒡</span>`;break;
		case SymKind.STRUCT         :rv = color ~ `Ⓢ</span>`;break;
		case SymKind.CLASS          :rv = color ~ `Ⓒ</span>`;break;
		case SymKind.INTERFACE      :rv = color ~ `😐</span>`;break;
		case SymKind.VARIABLE       :rv = color ~ `⒱</span>`;break;
		case SymKind.ALIAS          :rv = color ~ `ⓐ</span>`;break;
		case SymKind.CONSTRUCTOR    :rv = color ~ `⒞</span>`;break;
		case SymKind.ENUM           :rv = color ~ `Ⓔ</span>`;break;
		case SymKind.ENUM_MEMBER    :rv = color ~ `⒠</span>`;break;
		case SymKind.UNION          :rv = color ~ `Ⓤ</span>`;break;

		default : rv = color ~ `P</span>`;
	}
	return rv;
}

