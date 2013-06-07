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
import std.range;

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

	this()
	{
		Name = "-no name-";
		Path = "-no path-";
		Scope.length = 0;
		Kind = SymKind.ERROR;
		//FullType = "error";
		Type = "-no type-";
		Signature = "no signature";
		Protection = "-no protection-";
		Comment = "";
		File = "-no file-";
		Line = 0;
		Base = "-no base-";
		Children.length = 0;
		Icon = "!";
	}
}


class SYMBOLS
{
	private:

	bool			mAutoLoad;					//if symbols should be loaded at startup
	SysTime			mLastLoadTime;				//speed things up by not reloading unchanged files

	string			mProjectKey;				//key for project mSymbols

	DSYMBOL[string] mSymbols;

	ulong 			mSymCount;					//i was curious about how many symbols were loaded; (just short of 25000)


	//called at startup if mautoload is true
	void AutoLoadPackages()
	{
		mLastLoadTime  = Clock.currTime();
		auto PackageKeys = Config.getKeys("SYMBOL_LIBS");

		foreach(pckgkey; PackageKeys)
		{
			auto tagfile = Config.getString("SYMBOL_LIBS", pckgkey, "");
			auto NewSymbols = LoadPackage(pckgkey, tagfile);
			if(NewSymbols !is null) mSymbols[pckgkey] = NewSymbols;
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

		scope(exit)
		{
			mSymCount++;
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
				xtra = cast(int)SymData.object["type"].str.lastIndexOf('(');
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
					CurrSym.Signature = "alias ";
					if("storageClass" in SymData.object)
					{
						foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= strclass.str ~ " ";
					}
					CurrSym.Signature ~= CurrSym.Type ~ " " ~ CurrSym.Name;
					break;
				}

				case SymKind.CONSTRUCTOR:
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
							if("deco" in param.object)CurrSym.Signature ~= GetTypeFromDeco(param.object["deco"].str, unneeded);
							if("type" in param.object)CurrSym.Signature ~= param.object["type"].str; //template member funtion
							if("name" in param.object)CurrSym.Signature ~= " " ~ param.object["name"].str;
							if("defaultValue" in param.object) CurrSym.Signature ~=  "=" ~ param.object["defaultValue"].str;
							if("defaultAlias" in param.object) CurrSym.Signature ~=  "=" ~ param.object["defaultAlias"].str;
							if("default" in param.object) CurrSym.Signature ~=  "=" ~ param.object["default"].str;
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

			auto nametuple = SymData.object["name"].str.findSplit(".");

			if(nametuple[1].length == 0)
			{
				CurrSym.Name = nametuple[0];
				CurrSym.Scope ~= nametuple[0];
			}
			else
			{
				CurrSym.Name = nametuple[2];
				CurrSym.Scope ~= [nametuple[0] ,nametuple[2]];
			}

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

			if("members" in SymData.object)
			{
				foreach(obj; SymData.object["members"].array)
				{
					auto ChildSym = new DSYMBOL;
					ChildSym.Path = CurrSym.Path;
					ChildSym.File = CurrSym.File;
					ChildSym.Scope = CurrSym.Scope;
					BuildSymbol(ChildSym, obj);
					if(ChildSym.Name.startsWith("__unittest")) continue;
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
				membersym = new DSYMBOL;
				BuildSymbol(membersym, obj);
				if(membersym.Name.startsWith("__unittest"))continue;
				CurrSym.Children ~= membersym;
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
		//X.FullType	= "package";
		X.Type		= "package";
		X.Signature = "package";
		X.Comment	= "";

		X.File		= "";
		X.Line		= 0;

		X.Base		= "";
		X.Children.length = 0;
		X.Icon		= GetIcon(X);

		//BuildPackage(X, parseJSON(SymbolJson));
		BuildSymbol(X, parseJSON(SymbolJson));

		return X;
	}

	void WatchProject(ProEvent Event)
	{
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
													scope(failure){Log.Entry("Failed to load project symbols", "Error");return;}
													auto pckagekey = LoadPackage(mProjectKey, buildPath(Project.WorkingPath, mProjectKey ~".tags"));
													if (pckagekey !is null) mSymbols[mProjectKey] = pckagekey;
													emit();
													return;
												}
			case ProEvent.FailedTags			:
												{
													scope(failure){Log.Entry("Failed to load project symbols","Error");return;}
													if(Project.Name() in mSymbols) return; //keep the symbols we have if none try to load old symbols
													auto pkgkey = LoadPackage(mProjectKey, buildPath(Project.WorkingPath, mProjectKey ~".tags"));
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
													auto tmppkg = LoadPackage(mProjectKey, buildPath(Project.WorkingPath, mProjectKey ~".tags"));
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
		Log().Entry((mSymCount.to!string) ~ " symbols were in memory", "INFO");
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
	DSYMBOL[] GetCompletions(string Candidate)
	{
		string[] CandiScope = GetScopedCandidate(Candidate);
		string CandiName;
		writeln(CandiScope);

		ulong scopelen = CandiScope.length;
		if(scopelen == 1)
		{
			CandiName = CandiScope[0];
			CandiScope.length = 0;
		}
		else
		{
			CandiName = CandiScope[$-1];
			CandiScope = CandiScope[0 .. $-1];
		}

		DSYMBOL[] rvCompletions;

		void CheckSymbol(DSYMBOL xsym)
		{
			foreach(kid; xsym.Children)CheckSymbol(kid);

			if(xsym.Name.startsWith(CandiName)) rvCompletions ~= xsym;

		}
		if(scopelen > 1)
		{
			auto members = GetMembers(Candidate.chomp(CandiName));
			foreach (member; members)
			{
				if(member.Name.startsWith(CandiName)) rvCompletions ~= member;
			}
		}
		else
		{
			foreach(sym; mSymbols) CheckSymbol(sym);
		}

		foreach (rv; rvCompletions)writeln(rv.Name);
		return rvCompletions;
	}

	/**
	 * returns all possible symbols whose scope fall under candidate
	 * (hopefully)
	 * */


	DSYMBOL[] GetMembers(string Candidate)
	{
		string[] ScopedCandidate = GetScopedCandidate(Candidate);
		ulong	ScopeElements = ScopedCandidate.length;

		DSYMBOL[] rvSymbols;
		if(ScopeElements < 1) return rvSymbols;


		void CheckSymbol(DSYMBOL chksym)
		{

			foreach(kid; chksym.Children) CheckSymbol(kid);

			if((chksym.Scope[$-1] == ScopedCandidate[$-1]) ||(chksym.Scope.endsWith(ScopedCandidate)))
			{
				if(chksym.Base.length > 0)
				{
					rvSymbols ~= GetMembers(chksym.Base);
				}
				if(chksym.Kind == SymKind.FUNCTION) rvSymbols ~= GetMembers(chksym.Type);
				if(chksym.Kind == SymKind.VARIABLE) rvSymbols ~= GetMembers(chksym.Type);
				rvSymbols ~= chksym.Children;
			}

		}

		foreach(symbol; mSymbols) CheckSymbol(symbol);

		return rvSymbols;
	}
	/**
	 * returns all functions (and hopefully aliased functions) that match candidate
	 * */
	DSYMBOL[] GetCallTips(string Candidate)
	{

		DSYMBOL[] rvTips;
		string[] CandiPath = GetScopedCandidate(Candidate);


		void CheckSymbol(DSYMBOL xsym)
		{
			foreach(kid; xsym.Children) CheckSymbol(kid);

			////wierd template check kind of skips template symbol and looks at 'eponymous' member
			//if(xsym.Kind == SymKind.TEMPLATE)
			//{
//
			//	string[] tmp;
//
			//	if(CandiPath.length == 1) tmp = [xsym.Name , "." , CandiPath[0]];
			//	else
			//	{
			//		tmp = CandiPath[0 .. $-1];
			//		tmp ~= xsym.Name;
			//		tmp ~= CandiPath[$-1];
			//	}
			//	string subtmp;
			//	subtmp = tmp[0];
			//	if(tmp.length > 1)foreach (t; tmp[1..$])subtmp ~= "." ~ t;
			//	rvTips ~= GetCallTips(subtmp);
			//	return ;
			//}
			//if(xsym.Kind == SymKind.ALIAS) rvTips ~= GetCallTips(xsym.Type);
			if(xsym.Kind != SymKind.FUNCTION) return;
			if(CandiPath[$-1] != xsym.Name) return;

			rvTips ~= xsym;
		}

		foreach(sym; mSymbols) CheckSymbol(sym);

		return rvTips;
	}

	/**
	 * Generic method to get symbol information given a complete Name and possible scope
	 *
	 * */
	DSYMBOL[] GetMatches(string Candidate)
	{

		auto CandiScope = GetScopedCandidate(Candidate);

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
		case SymKind.IMPORT			:rv = color ~ `I</span>`;break;

		default : rv = color ~ `P</span>`;
	}
	return rv;
}



//---------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------


void SkipFunction(string deco, ref int index)
{
     while(!"XYZ".canFind(deco[index]))index++;
     index++;
}

string ReadQualifiedName(string Name)
{
     uint index;
     string local = Name.idup;
     string rv;

     int value;

     scope(exit) index = index + cast(uint)(Name.length - local.length);
     do
     {

          scope(failure) break;
          value = parse!int(local);

          if(!local.startsWith("__T"))
          {
               if(rv.length > 0) rv ~= ".";
               rv ~= local[0..value];
          }
          local = local[value..$];
     }while(true);
     return rv;
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
               while("0123456789".canFind(deco[index]))
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
