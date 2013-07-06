module symbols;

import std.algorithm;
import std.datetime;
import std.file;
import std.json;
import std.signals;
import std.string;
import std.path;
import std.stdio;
import std.conv;
import std.format;
import std.range;
import std.uni;
import std.parallelism;
import std.concurrency;

import core.demangle;

import dcore;


//just found interfaces, interfaces are not in members as I assumed.  And interfaces is not interface.
enum SymKind
{
	ERROR,
	ALIAS,
	CLASS,
	CONSTRUCTOR,
	DESTRUCTOR,
	ENUM,
	ENUM_MEMBER,
	FUNCTION,
	IMPORT,
	INTERFACE,
	MIXIN,
	MODULE,
	PACKAGE,
	STATIC_IMPORT,
	STRUCT,
	TEMPLATE,
	THIS,
	TUPLE,
	TYPE,
	UNION,
	VALUE,
	VARIABLE
}


class DSYMBOL
{
	string			Name;			///Symbols name
	string			Path;			///Full scope/path of symbol id (std.stdio.File.open, std.file.readText, etc)
	string[]		Scope;			///path as an array of strings (["std", "stdio", "File", "open"] ; [ "std", "file", "readText"])

	SymKind			Kind;			///what kind of symbol
	//string			FullType;		///fully QUALIFIED type of the symbol
	string			Type;			///the UNQUALIFIED type of the symbol (drops trusted, safe, const, etc ... not sure about [] yet)
	string			Signature;		///actual signature as at declaration
	string			Protection;		///private package protected public export

	string			Comment;		///actual comments from source (if ditto, will be the 'dittoed' comment)

	string			File;
	int				Line;

	string			Base;
	DSYMBOL[]		Children;
	string			Icon;

	//this()
	//{
	//	Name = "";
	//	Path = "";
	//	Scope.length = 0;
	//	Kind = SymKind.ERROR;
	//	//FullType = "error";
	//	Type = "";
	//	Signature = "";
	//	Protection = "";
	//	Comment = "";
	//	File = "";
	//	Line = 0;
	//	Base = "";
	//	Children.length = 0;
	//	Icon = "!";
	//}
}


class SYMBOLS
{
	private:

	bool			mAutoLoad;					//if symbols should be loaded at startup
	SysTime			mLastLoadTime;				//speed things up by not reloading unchanged files

	string			mProjectKey;				//key for project mSymbols

	DSYMBOL[string] mSymbols;


	//called at startup if mautoload is true
	//also called on configure
	void AutoLoadPackages()
	{
		mLastLoadTime  = Clock.currTime();
		auto PackageKeys = Config.getKeys("SYMBOL_LIBS");
		string jsontext;

		foreach(jfile; PackageKeys)
		{
			jsontext = readText(Config.getString("SYMBOL_LIBS", jfile, ""));
			auto NewSymbols = LoadPackage(jfile, jsontext);
			if(NewSymbols !is null) mSymbols[jfile] = NewSymbols;
		}

	}


	void BuildSymbol(DSYMBOL CurrSym, JSONValue SymData)
	{
		scope(failure)
		{
			Log.Entry("Error loading symbol tag information " ~ CurrSym.Name);
			CurrSym.Icon = `<span foreground="red">!</span>`;
			return;
		}

		void SetType()
		{
			int xtra;
			CurrSym.Type = "";
			if("deco" in SymData.object)
			{
				CurrSym.Type = GetTypeFromDeco(SymData.object["deco"].str, xtra);
				return;
			}
			if("baseDeco" in SymData.object)
			{
				CurrSym.Type = GetTypeFromDeco(SymData.object["baseDeco"].str, xtra);
				return;
			}
			if("type" in SymData.object)
			{
				auto type = SymData.object["type"].str;
				xtra = cast(int)type.length;
				int depth;
				do
				{
					xtra--;
					if(type[xtra] == ')') depth++;
					if(type[xtra] == '(') depth--;
				}while((depth > 0) && (xtra > 0));

				//xtra = cast(int)SymData.object["type"].str.lastIndexOf('(');
				if(xtra < 1)CurrSym.Type = "";
				else CurrSym.Type = SymData.object["type"].str[0..xtra];
				return;
			}

		}

		void SetKind()
		{
			switch (SymData.object["kind"].str)
			{
				case "alias"		:CurrSym.Kind= SymKind.ALIAS		;break;
				case "class"		:CurrSym.Kind= SymKind.CLASS		;break;
				case "constructor"	:CurrSym.Kind= SymKind.CONSTRUCTOR	;break;
				case "destructor"	:CurrSym.Kind= SymKind.DESTRUCTOR	;break;
				case "enum"			:CurrSym.Kind= SymKind.ENUM			;break;
				case "enum member"	:CurrSym.Kind= SymKind.ENUM_MEMBER	;break;
				case "function"		:CurrSym.Kind= SymKind.FUNCTION		;break;
				case "import" 	    :CurrSym.Kind= SymKind.IMPORT   	;break;
				case "interface"	:CurrSym.Kind= SymKind.INTERFACE	;break;
				case "module"		:CurrSym.Kind= SymKind.MODULE		;break;
				case "mixin"	    :CurrSym.Kind= SymKind.MIXIN    	;break;
				case "package"		:CurrSym.Kind= SymKind.PACKAGE		;break;
				case "static import":CurrSym.Kind= SymKind.STATIC_IMPORT;break;
				case "struct"		:CurrSym.Kind= SymKind.STRUCT		;break;
				case "template"		:CurrSym.Kind= SymKind.TEMPLATE		;break;
				case "tuple"    	:CurrSym.Kind= SymKind.TUPLE    	;break;
				case "type"     	:CurrSym.Kind= SymKind.TYPE     	;break;
				case "union"		:CurrSym.Kind= SymKind.UNION		;break;
				case "value"    	:CurrSym.Kind= SymKind.VALUE    	;break;
				case "variable"		:CurrSym.Kind= SymKind.VARIABLE		;break;

				default :
				{	CurrSym.Kind = SymKind.ERROR;
					Log.Entry(`Unrecognized symbol kind "` ~ SymData.object["kind"].str,`" Error`);
				}
			}
		}


		void SetSignature()
		{
			int unneeded;
			CurrSym.Signature = "";
			switch(CurrSym.Kind)
			{
				case SymKind.ALIAS :
				{
					CurrSym.Signature ~= "alias ";
					if("storageClass" in SymData.object)
					{
						foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= strclass.str ~ " ";
					}
					CurrSym.Signature ~= CurrSym.Type ~ " " ~ CurrSym.Name;
					break;
				}

				case SymKind.CONSTRUCTOR:
				{
					if("storageClass" in SymData.object)
					{
						foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= strclass.str ~ " ";
					}
					CurrSym.Signature ~= CurrSym.Type ~ "(";
					if("parameters" in SymData.object)
					{
						foreach(i, param; SymData.object["parameters"].array)
						{
							if(i > 0) CurrSym.Signature ~= ", ";
							if("deco" in param.object)
							{
								CurrSym.Signature ~= GetTypeFromDeco(param.object["deco"].str, unneeded);
							}
							else if("type" in param.object)
							{
								CurrSym.Signature ~= param.object["type"].str; //template member funtion
							}
							if("name" in param.object)
							{
								CurrSym.Signature ~= " " ~ param.object["name"].str;
							}
							if("defaultValue" in param.object)
							{
								CurrSym.Signature ~=  "=" ~ param.object["defaultValue"].str;
								continue;
							}
							if("defaultAlias" in param.object)
							{
								CurrSym.Signature ~=  "=" ~ param.object["defaultAlias"].str;
								continue;
							}
							if("default" in param.object)CurrSym.Signature ~=  "=" ~ param.object["default"].str;
						}
					}
					CurrSym.Signature ~= ")";
					break;
				}
				case SymKind.FUNCTION :
				{
					if("storageClass" in SymData.object)
					{
						foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= strclass.str ~ " ";
					}
					CurrSym.Signature ~= CurrSym.Type ~ " " ~ CurrSym.Name ~ "(";
					if("parameters" in SymData.object)
					{
						foreach(i, param; SymData.object["parameters"].array)
						{
							if(i > 0) CurrSym.Signature ~= ", ";
							if("type" in param.object)CurrSym.Signature ~= param.object["type"].str; //template member funtion
							else if("deco" in param.object)CurrSym.Signature ~= GetTypeFromDeco(param.object["deco"].str, unneeded);
							if("name" in param.object)CurrSym.Signature ~= " " ~ param.object["name"].str;
							if("default" in param.object)
							{
								CurrSym.Signature ~=  "=" ~ param.object["default"].str;
								continue;
							}
							if("defaultValue" in param.object)
							{
								CurrSym.Signature ~=  "=" ~ param.object["defaultValue"].str;
								continue;
							}
							if("defaultAlias" in param.object) CurrSym.Signature ~=  "=" ~ param.object["defaultAlias"].str;
						}
					}
					CurrSym.Signature ~= ")";

					break;
				}
				case SymKind.VARIABLE :
				{
					if("storageClass" in SymData.object)
					{
						foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= strclass.str ~ " ";
					}
					CurrSym.Signature = CurrSym.Type ~ " " ~ CurrSym.Name;
					break;
				}

				case SymKind.ENUM :
				{
					CurrSym.Signature = "enum " ~ CurrSym.Name;
					if("baseDeco" in SymData.object) CurrSym.Signature ~= " : " ~ GetTypeFromDeco(SymData.object["baseDeco"].str, unneeded);
					break;
				}
				default: break;
			}
		}

		if(SymData.type == JSON_TYPE.OBJECT)
		{

			foreach(subname; SymData.object["name"].str.splitter('.'))
			{
				CurrSym.Scope ~= subname;
			}
			CurrSym.Name = CurrSym.Scope[$-1];

			SetKind();
			SetType();
			SetSignature();
			if("protection" in SymData.object)CurrSym.Protection = SymData.object["protection"].str;
			if("comment" in SymData.object)CurrSym.Comment = SymData.object["comment"].str;
			if("file" in SymData.object)CurrSym.File = SymData.object["file"].str;

			assert(CurrSym.File != null); // File should be set before entering BuildSymbol(this, ...)
			if("line" in SymData.object)CurrSym.Line = cast(int)SymData.object["line"].integer;
			if("base" in SymData.object)CurrSym.Base = SymData.object["base"].str;


			CurrSym.Path = CurrSym.Scope[0];
			foreach(s; CurrSym.Scope[1..$]) CurrSym.Path ~= '.' ~ s;
			CurrSym.Icon = GetIcon(CurrSym);

			if("members" in SymData.object)
			{
				foreach(obj; SymData.object["members"].array)
				{
					if(obj.object["name"].str.startsWith("__unittest"))continue;
					if(obj.object["kind"].str.startsWith("import"))continue;
					auto ChildSym = new DSYMBOL;
					ChildSym.Path = CurrSym.Path;
					ChildSym.File = CurrSym.File;
					ChildSym.Scope = CurrSym.Scope;

					BuildSymbol(ChildSym, obj);
					if(ChildSym.Kind == SymKind.IMPORT)continue;
					CurrSym.Children ~= ChildSym;
				}
			}
			return;
		}

		if(SymData.type == JSON_TYPE.ARRAY)
		{
			DSYMBOL membersym;
			foreach(obj; SymData.array)
			{
				if(obj.object["name"].str.startsWith("__unittest"))continue;
				membersym = new DSYMBOL;
				BuildSymbol(membersym, obj);
				CurrSym.Children ~= membersym;
			}
		}
	}



	//given a package name and a json file loads the symbols and returns them
	DSYMBOL LoadPackage(const string PackageName, const string SymbolJson)
	{
		scope(failure)
		{
			Log.Entry("Unable to load Symbol file: " ~ PackageName, "Error");
			return null;
		}

		DSYMBOL X = new DSYMBOL;

		X.Name 		= PackageName;
		X.Path 		= PackageName;
		X.Scope 	= [PackageName];

		X.Kind		= SymKind.PACKAGE;
		X.Type		= "package";
		X.Signature = "package";
		X.Comment	= "";

		X.File		= "";
		X.Line		= 0;

		X.Base		= "";
		X.Children.length = 0;
		X.Icon		= GetIcon(X);

		BuildSymbol(X, parseJSON(SymbolJson));

		return X;
	}

	void WatchProject(ProEvent Event)
	{
		scope(failure)
		{
			Log.Entry("Failed to load project symbols", "Error");
			return;
		}

		switch (Event)
		{
			case ProEvent.Closing  				:
												{
													if(mProjectKey in mSymbols)
													{
														mSymbols.remove(mProjectKey);
														emit();
													}
													return;
												}
			case ProEvent.CreatedTags			:
												{
													auto pckagekey = LoadPackage(mProjectKey, readText(buildPath(Project.WorkingPath, mProjectKey ~".json")));
													if (pckagekey !is null) mSymbols[mProjectKey] = pckagekey;
													emit();
													return;
												}
			case ProEvent.FailedTags			:
												{
													if(Project.Name() in mSymbols) return; //keep the symbols we have if none try to load old symbols
													auto pkgkey = LoadPackage(mProjectKey, readText(buildPath(Project.WorkingPath, mProjectKey ~".json")));
													if(pkgkey !is null) mSymbols[mProjectKey] = pkgkey;
													return;
												}
			case ProEvent.NameChanged			:
												{
													if(mProjectKey in mSymbols)
													{
														auto tmpsym = mSymbols[mProjectKey];
														mSymbols.remove(mProjectKey);
													}
													mProjectKey = Project.Name;
													auto tmppkg = LoadPackage(mProjectKey, readText(buildPath(Project.WorkingPath, mProjectKey ~".json")));
													if(tmppkg !is null) mSymbols[mProjectKey] = tmppkg;
													emit();
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
			mSymbols[key] = LoadPackage(key, jsonfile.readText);
		}
		string[] KeysToRemove;
		foreach(assockey, symbol; mSymbols)
		{
			if(!keys.canFind(assockey))
			{
				if(assockey == Project.Name)continue;
				KeysToRemove ~= assockey;
			}
		}
		foreach(keytoremove; KeysToRemove) mSymbols.remove(keytoremove);

		emit();

	}

	void SelectSymbol(string FullPathName)
	{
	}

	DSYMBOL GetSelectedSymbol()
	{
		return new DSYMBOL;
	}


	/**
	 * actually I should have just done foreach(sym; mSymbols) sym.Path.canFind(Candidate)
	 */
	DSYMBOL[] GetCompletions(string[] Candidate)
	{
		string[] ScopedCandi;
		if(Candidate.length > 1)ScopedCandi = Candidate[0..$-1];
		string CandiName = Candidate[$-1];


		DSYMBOL[] rval;
		DSYMBOL[] pool;

		void CheckSymbol(DSYMBOL xsym)
		{
			foreach(kid; xsym.Children) CheckSymbol(kid);

			if(xsym.Name.startsWith(CandiName)) rval ~= xsym;
		}

		if(ScopedCandi.length > 0)pool = GetMembers(ScopedCandi);
		if(pool.length < 1)pool = mSymbols.values;

		foreach(sym; pool)CheckSymbol(sym);
		return rval;
	}

	/**
	 * returns all possible symbols whose scope fall under candidate
	 * (hopefully)
	 * */
	DSYMBOL[] GetMembers(string[] Candidate)
	{
		DSYMBOL[] rval;
		//static long depth = 0;
		//scope(exit)
		//{
		//	depth--;
		//	writeln(depth);
		//}
		//depth++;
		//if(depth > 2) return rval;


		if(Candidate.length < 1)return rval;
		void CheckSymbol(DSYMBOL xsym)
		{
			//making classname = to module name should be an error!
			foreach(kid; xsym.Children) CheckSymbol(kid);

			if(xsym.Scope.endsWith(Candidate))
			{

				foreach(kid; xsym.Children)
				{
					if(kid.Name != Candidate[$-1]) rval ~= kid;
				}
				if(xsym.Base.length > 0)rval ~= GetMembers(ScopeSymbol(xsym.Base));
				if(xsym.Kind == SymKind.FUNCTION) rval ~= GetMembers(ScopeSymbol(xsym.Type));
				return;
			}
			if(Candidate[$-1] == xsym.Scope[$-1])
			{
				foreach(kid; xsym.Children)
				{
					if(kid.Name != Candidate[$-1]) rval ~= kid;
				}
				if(xsym.Base.length > 0)rval ~= GetMembers(ScopeSymbol(xsym.Base));
				rval ~= GetMembers(ScopeSymbol(xsym.Type));
				return;
			}


		}

		foreach(sym; mSymbols)
		{
			CheckSymbol(sym);
		}

		return rval;

	}


	/**
	 * returns all functions (and hopefully aliased functions) that match candidate
	 * */
	DSYMBOL[] GetCallTips(string[] Candidate)
	{
		string[] CandiPath;
		string CandiName;

		if(Candidate.length > 1) CandiPath = Candidate[0..$-1];
		CandiName = Candidate[$-1];

		DSYMBOL[] rval;
		DSYMBOL[] pool;

		void CheckSymbol(DSYMBOL xsym)
		{
			foreach(kid; xsym.Children) CheckSymbol(kid);

			if(xsym.Name == CandiName)
			{
				if(xsym.Kind == SymKind.FUNCTION) rval ~= xsym;
				if(xsym.Kind == SymKind.CLASS || xsym.Kind == SymKind.STRUCT)
				{
					foreach(kid; xsym.Children) if(kid.Kind == SymKind.CONSTRUCTOR) rval ~= kid;
				}
			}

		}


		if(CandiPath.length >0)pool = GetMembers(CandiPath);
		if(pool.length < 1) pool = mSymbols.values;

		foreach(sym; pool) CheckSymbol(sym);

		return rval;
	}

	/**
	 * Generic method to get symbol information given a complete Name and possible scope
	 *
	 * */
	DSYMBOL[] GetMatches(string Candidate)
	{

		auto CandiScope = ScopeSymbol(Candidate);

		DSYMBOL[] rvMatches;

		void CheckSymbol(DSYMBOL xsym)
		{
			foreach(kid; xsym.Children) CheckSymbol(kid);
			if(xsym.Scope.endsWith(CandiScope))rvMatches ~= xsym;
		}

		foreach(sym; mSymbols) CheckSymbol(sym);
		return rvMatches;
	}

	DSYMBOL[string] Symbols(){return  mSymbols.dup;}

	mixin Signal!();
	mixin Signal!(DSYMBOL[]) Forward;

	void ForwardSignal(DSYMBOL[] syms)
	{
		Forward.emit(syms);
	}
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
		default : color = `<span foreground="black">`;
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
		case SymKind.IMPORT			:rv = color ~ `I</span>`;break;
		case SymKind.MIXIN			:rv = color ~ `m</span>`;break;


		default : rv = color ~ `P</span>`;
	}
	return rv;
}



//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------


void SkipFunction(string deco, ref int index)
{
     //while(!"XYZ".canFind(deco[index]))index++;
     //index++;
     do
     {
		switch(deco[0])
		{
			case 'X' :
			case 'Y' :
			case 'Z' : index++;return;
			default : deco = deco[1..$];
		}
		index++;
	 }while(true);
}

string ReadQualifiedName_old(string Name)
{
    uint index;
    string local = Name.idup;
    string rv;

    int value;

    scope(exit) index = index + cast(uint)(Name.length - local.length);
    do
	{
		value = 0;
        scope(failure) break;
        char[] strnum;
        while(local[0].isNumber)
        {
			strnum ~= local[0];
			local = local[1..$];
		}
		//value = to!int(strnum);
		long place = strnum.length -1;
		long total = strnum.length;
		long ix;
		do
		{
			value += (cast(ubyte)(local[ix]) - 48) * cast(long)(10.0 ^^ place);
			place--;
			ix++;
		}while (ix < total);

        local = local[value..$];

	}while(true);
	return rv;
}

string ReadQualifiedName(string Name)
{
	string rval;

	do
	{
		scope(failure)break;
		//if(!Name[0].isNumber)break;
		if( (Name[0] < '0') || (Name[0] > '9'))break;
		string NumberString;

		//get string telling name part length
		while(Name[0].isNumber)
		{
			NumberString ~= Name[0];
			Name = Name[1..$];

		}
		//convert it to a number
		auto place = NumberString.length - 1;
		long value = 0;
		foreach(ch; NumberString)
		{
			value += cast(long)(ch-48) * cast(long)(10^^place);
			place--;
		}



		//add name part to output
		if(rval.length > 0) rval ~= ".";
		rval ~= Name[0..value];

		//adjust input string again
		Name = Name[value..$];
	}while(true);


	return rval;
}


string GetTypeFromDeco(string deco, ref int mangledlen)
{
     int index;
     int sublen;
     bool isPointer;
     bool isStaticArray;
     string elements;
     bool isDynamicArray;
     bool isAssocArray;
     string AssocType;

     string rv;

     switch(deco[index])
     {
          case 'O' :
          case 'x' :
          case 'y' :
          {
               index++;
               rv = GetTypeFromDeco(deco[index..$], sublen);
               break;
          }

          case 'N' :
          {
               index += 2;
               rv =  GetTypeFromDeco(deco[index..$], sublen);
               break;
          }

          case 'A' :
          {
               isDynamicArray = true;
               index++;
               rv = GetTypeFromDeco(deco[index..$], sublen);
               break;

          }
          case 'G' :
          {
               isStaticArray = true;
               index++;
               //while("0123456789".canFind(deco[index]))
               while( (deco[index] >= '0') && (deco[index] <= '9') )
               {
                    elements ~= deco[index];
                    index++;
               }
               rv = GetTypeFromDeco(deco[index..$], sublen);
               break;

          }
          case 'H' :
          {
               isAssocArray = true;
               index++;

               AssocType = GetTypeFromDeco(deco[index..$], sublen);
               index += sublen+1;
               rv = GetTypeFromDeco(deco[index..$], sublen);
               break;
          }
          case 'P' :
          {
               isPointer = true;
               index++;
               rv = GetTypeFromDeco(deco[index..$], sublen);
               break;
          }

          case 'F' :
          case 'U' :
          case 'W' :
          case 'V' :
          case 'R' :
          {
               SkipFunction(deco, index);
               rv = GetTypeFromDeco(deco[index..$], sublen);
               break;
          }

          case 'I' :
          case 'C' :
          case 'S' :
          case 'E' :
          {
               index++;
               rv = ReadQualifiedName(deco[index..$]);

               break;
          }

          case 'D' :
          {
               index++;
               rv = GetTypeFromDeco(deco[index..$], sublen);
               break;
          }

          case 'v' : rv = "void"; break;
          case 'g' : rv =  "byte"; break;
          case 'h' : rv =  "ubyte"; break;
          case 's' : rv =  "short"; break;
          case 't' : rv =  "ushort"; break;
          case 'i' : rv =  "int"; break;
          case 'k' : rv =  "uint"; break;
          case 'l' : rv =  "long"; break;
          case 'm' : rv =  "ulong"; break;
          case 'f' : rv =  "float"; break;
          case 'd' : rv =  "double"; break;
          case 'e' : rv =  "real"; break;
          case 'o' : rv =  "ifloat"; break;
          case 'p' : rv =  "idouble"; break;
          case 'j' : rv =  "ireal"; break;
          case 'q' : rv =  "cfloat"; break;
          case 'r' : rv =  "cdouble"; break;
          case 'c' : rv =  "creal"; break;
          case 'b' : rv =  "bool"; break;
          case 'a' : rv =  "char"; break;
          case 'u' : rv =  "wchar"; break;
          case 'w' : rv =  "dchar"; break;
          case 'n' : rv =  "null"; break;
          case 'B' : rv =  "tuple";  break;//temporary

          default : return "error";
     }

     if(isPointer) rv ~= '*';
     if(isStaticArray) rv ~= "[" ~ elements ~ "]";
     if(isDynamicArray) rv ~= "[]";
     if(isAssocArray) rv ~= "[" ~ AssocType ~ "]";
     if(mangledlen != -1) mangledlen = index;
     return rv;

}


//another concurrent read attempt
string rval[Tid];
void SpawnRead(Tid tid)
{
	string FileToRead;
	//get the file name
	receive(
		(string fname){ writeln(fname);FileToRead = fname;}
	);

	rval[tid] = readText(FileToRead);

	send(tid, rval[tid]);
}

