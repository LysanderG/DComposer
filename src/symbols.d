module symbols;

import dcore;

import json;

import std.string;
import std.datetime;
import std.file;
import std.string;
import std.algorithm;
import std.uni;
import std.array;
import std.path;
import std.signals;
import std.encoding;


enum SYMBOL_KIND
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
    string          Name;           ///Symbols name
    string          Path;           ///Full scope/path of symbol id (std.stdio.File.open, std.file.readText, etc)
    string[]        Scope;          ///path as an array of strings (["std", "stdio", "File", "open"] ; [ "std", "file", "readText"])

    SYMBOL_KIND     Kind;           ///what kind of symbol
    //string        FullType;       ///fully QUALIFIED type of the symbol
    string          Type;           ///the UNQUALIFIED type of the symbol (drops trusted, safe, const, etc ... not sure about [] yet)
    string          Signature;      ///actual signature as at declaration
    string          Protection;     ///private package protected public export

    string          Comment;        ///actual comments from source (if ditto, will be the 'dittoed' comment)

    string          File;
    int             Line;

    string          Base;
    string[]        Interfaces;
    DSYMBOL[]       Children;
    string          Icon;
}

class SYMBOLS
{
    private :

    DSYMBOL[string] mModules;

    bool            mAutoLoadPackages;
    bool            mAutoLoadProject;

    SysTime         mLastLoadTime;

    void AutoLoadPackages()
    {
        mLastLoadTime  = Clock.currTime();
        auto PackageKeys = Config.GetKeys("symbol_libs");

        foreach(jfile; PackageKeys)
        {
            scope(failure)
            {
                Log.Entry("Autoload " ~ jfile ~ " failed", "Error");
                continue;
            }
            auto dtagfile = SystemPath(Config.GetValue("symbol_libs", jfile, ""));
            LoadDTagsFile(dtagfile);
        }
    }


    @system void BuildSymbol(DSYMBOL CurrSym, JSON SymData)
    {
        scope(failure)
        {
            //((MOD)) Log.Entry("Error loading symbol tag information " ~ CurrSym.Name);
            CurrSym.Icon = `<span foreground="red">!</span>`;
            return;
        }

        void SetType()
        {
            int xtra;
            CurrSym.Type = "";
            if("deco" in SymData.object)
            {
                CurrSym.Type = GetTypeFromDeco(cast(string)SymData.object["deco"], xtra);
                return;
            }
            if("baseDeco" in SymData.object)
            {
                CurrSym.Type = GetTypeFromDeco(cast(string)SymData.object["baseDeco"], xtra);
                return;
            }
            if("type" in SymData.object)
            {
                auto type = cast(string)SymData.object["type"];
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

                else
                {
                    string tmp1 = cast(string)SymData.object["type"];
                    CurrSym.Type = tmp1[0..xtra];
                }
                return;
            }

        }

        void SetKind()
        {
            switch (cast(string)SymData.object["kind"]) with(SYMBOL_KIND)
            {
                case "alias"        :CurrSym.Kind= ALIAS        ;break;
                case "class"        :CurrSym.Kind= CLASS        ;break;
                case "constructor"  :CurrSym.Kind= CONSTRUCTOR  ;break;
                case "destructor"   :CurrSym.Kind= DESTRUCTOR   ;break;
                case "enum"         :CurrSym.Kind= ENUM         ;break;
                case "enum member"  :CurrSym.Kind= ENUM_MEMBER  ;break;
                case "function"     :CurrSym.Kind= FUNCTION     ;break;
                case "import"       :CurrSym.Kind= IMPORT       ;break;
                case "interface"    :CurrSym.Kind= INTERFACE    ;break;
                case "module"       :CurrSym.Kind= MODULE       ;break;
                case "mixin"        :CurrSym.Kind= MIXIN        ;break;
                case "package"      :CurrSym.Kind= PACKAGE      ;break;
                case "static import":CurrSym.Kind= STATIC_IMPORT;break;
                case "struct"       :CurrSym.Kind= STRUCT       ;break;
                case "template"     :CurrSym.Kind= TEMPLATE     ;break;
                case "tuple"        :CurrSym.Kind= TUPLE        ;break;
                case "type"         :CurrSym.Kind= TYPE         ;break;
                case "union"        :CurrSym.Kind= UNION        ;break;
                case "value"        :CurrSym.Kind= VALUE        ;break;
                case "variable"     :CurrSym.Kind= VARIABLE     ;break;

                default :
                {   CurrSym.Kind = ERROR;
                     //((MOD))Log.Entry(`Unrecognized symbol kind "` ~ cast(string)SymData.object["kind"],`" Error`);
                }
            }
        }


        void SetSignature()
        {
            int unneeded;
            CurrSym.Signature = "";
            switch(CurrSym.Kind) with (SYMBOL_KIND)
            {
                case ALIAS :
                {
                    CurrSym.Signature ~= "alias ";
                    if("storageClass" in SymData.object)
                    {
                        foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= cast(string)strclass ~ " ";
                    }
                    CurrSym.Signature ~= CurrSym.Type ~ " " ~ CurrSym.Name;
                    break;
                }

                case CONSTRUCTOR:
                {
                    if("storageClass" in SymData.object)
                    {
                        foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= cast(string)strclass ~ " ";
                    }
                    CurrSym.Signature ~= CurrSym.Type ~ "(";
                    if("parameters" in SymData.object)
                    {
                        foreach(i, param; SymData.object["parameters"].array)
                        {
                            if(i > 0) CurrSym.Signature ~= ", ";
                            if("deco" in param.object)
                            {
                                CurrSym.Signature ~= GetTypeFromDeco(cast(string)param.object["deco"], unneeded);
                            }
                            else if("type" in param.object)
                            {
                                CurrSym.Signature ~= cast(string)param.object["type"]; //template member funtion
                            }
                            if("name" in param.object)
                            {
                                CurrSym.Signature ~= " " ~ cast(string)param.object["name"];
                            }
                            if("defaultValue" in param.object)
                            {
                                CurrSym.Signature ~=  "=" ~ cast(string)param.object["defaultValue"];
                                continue;
                            }
                            if("defaultAlias" in param.object)
                            {
                                CurrSym.Signature ~=  "=" ~ cast(string)param.object["defaultAlias"];
                                continue;
                            }
                            if("default" in param.object)CurrSym.Signature ~=  "=" ~ cast(string)param.object["default"];
                        }
                    }
                    CurrSym.Signature ~= ")";
                    break;
                }
                case FUNCTION :
                {
                    if("storageClass" in SymData.object)
                    {
                        foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= cast(string)strclass ~ " ";
                    }
                    CurrSym.Signature ~= CurrSym.Type ~ " " ~ CurrSym.Name ~ "(";
                    if("parameters" in SymData.object)
                    {
                        foreach(i, param; SymData.object["parameters"].array)
                        {
                            if(i > 0) CurrSym.Signature ~= ", ";
                            if("type" in param.object)CurrSym.Signature ~= cast(string)param.object["type"]; //template member funtion
                            else if("deco" in param.object)CurrSym.Signature ~= GetTypeFromDeco(cast(string)param.object["deco"], unneeded);
                            if("name" in param.object)CurrSym.Signature ~= " " ~ cast(string)param.object["name"];
                            if("default" in param.object)
                            {
                                CurrSym.Signature ~=  "=" ~ cast(string)param.object["default"];
                                continue;
                            }
                            if("defaultValue" in param.object)
                            {
                                CurrSym.Signature ~=  "=" ~ cast(string)param.object["defaultValue"];
                                continue;
                            }
                            if("defaultAlias" in param.object) CurrSym.Signature ~=  "=" ~ cast(string)param.object["defaultAlias"];
                        }
                    }
                    CurrSym.Signature ~= ")";

                    break;
                }
                case VARIABLE :
                {
                    if("storageClass" in SymData.object)
                    {
                        foreach(strclass; SymData.object["storageClass"].array) CurrSym.Signature ~= cast(string)strclass ~ " ";
                    }
                    CurrSym.Signature = CurrSym.Type ~ " " ~ CurrSym.Name;
                    break;
                }

                case ENUM :
                {
                    CurrSym.Signature = "enum " ~ CurrSym.Name;
                    if("baseDeco" in SymData.object) CurrSym.Signature ~= " : " ~ GetTypeFromDeco(cast(string)SymData.object["baseDeco"], unneeded);
                    break;
                }
                default: break;
            }
        }

        if(SymData.type == JSON_TYPE.OBJECT)
        {
            if("name" !in SymData.object)SymData.object["name"] = "unnamed";


            foreach(subname; (cast(string)SymData.object["name"]).splitter('.'))
            {
                CurrSym.Scope ~= subname;
            }
            CurrSym.Name = CurrSym.Scope[$-1];

            SetKind();
            SetType();
            SetSignature();
            if("protection" in SymData.object)CurrSym.Protection = cast(string)SymData.object["protection"];
            if("comment" in SymData.object)CurrSym.Comment = cast(string)SymData.object["comment"];
            if("file" in SymData.object)CurrSym.File = cast(string)SymData.object["file"];

            assert(CurrSym.File != null); // File should be set before entering BuildSymbol(this, ...)
            if("line" in SymData.object)CurrSym.Line = cast(int)SymData.object["line"];
            if("base" in SymData.object)CurrSym.Base = cast(string)SymData.object["base"];
            
            if("interfaces" in SymData.object)foreach(x; SymData.object["interfaces"])
            {
	            CurrSym.Interfaces ~= cast(string)x;
            }
			
            CurrSym.Path = CurrSym.Scope[0];
            foreach(s; CurrSym.Scope[1..$]) CurrSym.Path ~= '.' ~ s;
            CurrSym.Icon = GetIcon(CurrSym);

            if("members" in SymData.object)
            {

                //auto apparr = appender!(DSYMBOL[], DSYMBOL)();
                DSYMBOL[] tmpD;
                auto apparr = appender!(DSYMBOL[], DSYMBOL)(tmpD);
                apparr.reserve(SymData.object["members"].array.length);
                foreach(obj; SymData.object["members"].array)
                {
                    if("name" !in obj.object)obj.object["name"] = "unnamed";
                    if((cast(string)obj.object["name"]).startsWith("__unittest"))continue;
                    if((cast(string)obj.object["kind"]).startsWith("import"))continue;
                    auto ChildSym = new DSYMBOL;
                    ChildSym.Path = CurrSym.Path;
                    ChildSym.File = CurrSym.File;
                    ChildSym.Scope = CurrSym.Scope;

                    BuildSymbol(ChildSym, obj);
                    if(ChildSym.Kind == SYMBOL_KIND.IMPORT)continue;
                    //CurrSym.Children ~= ChildSym;
                    apparr.put(ChildSym);
                }
                CurrSym.Children = apparr.data();
            }

            return;
        }

        if(SymData.type == JSON_TYPE.ARRAY)
        {
            DSYMBOL membersym;

            DSYMBOL[] tmpD;
            auto apparr = appender!(DSYMBOL[], DSYMBOL)(tmpD);
            apparr.reserve(SymData.array.length);
            foreach(obj; SymData.array)
            {
                if("name" !in obj.object)obj.object["name"] = "unnamed";
                if((cast(string)obj.object["name"]).startsWith("__unittest"))continue;
                membersym = new DSYMBOL;
                BuildSymbol(membersym, obj);
                //CurrSym.Children ~= membersym;
                apparr.put(membersym);
            }
            CurrSym.Children = apparr.data();
        }
    }

    DSYMBOL LoadPackage(const string PackageName, const string SymbolJson)
    {
        scope(failure)
        {
            Log.Entry("LoadPackage : Unable to load Symbol file: " ~ PackageName, "Error");
            return null;
        }

        DSYMBOL X = new DSYMBOL;

        X.Name      = PackageName;
        X.Path      = PackageName;
        X.Scope     = [PackageName];

        X.Kind      = SYMBOL_KIND.PACKAGE;
        X.Type      = "package";
        X.Signature = "package";
        X.Comment   = "";

        X.File      = "";
        X.Line      = 0;

        X.Base      = "";
        X.Children.length = 0;
        X.Icon      = GetIcon(X);

        BuildSymbol(X, parseJSON(SymbolJson));

        return X;
    }


    public :

    void Engage()
    {
        mAutoLoadPackages = Config.GetValue("symbols", "auto_load_packages", true);
        mAutoLoadProject  = Config.GetValue("symbols", "auto_load_project", true);

        if(mAutoLoadPackages)AutoLoadPackages();

        string loadedstuff = " [";
        foreach(index, symkey; mModules.keys)
        {
            if(index != 0) loadedstuff ~= ",";
            loadedstuff ~= `"` ~ symkey ~ `"`;
        }
        loadedstuff ~= "]";

        Log.Entry("Engaged " ~ loadedstuff);
    }
    void PostEngage()
    {
        Log.Entry("PostEngaged");
    }
    void Disengage()
    {

        Log.Entry("Disengaged");
    }

    mixin Signal!(DSYMBOL[]);
//=====================================================================================================================
//=====================================================================================================================
    auto Modules()
    {
        return mModules.byValue();
    }

    void AddModule(string ModName, DSYMBOL nuSymbol)
    {
        if(ModName in mModules) return;
        mModules[ModName] = nuSymbol;

        Log.Entry(ModName ~ " added to symbol tables.");
    }
    deprecated DSYMBOL LoadFile(string FileName)
    {
        auto jstring = readText(FileName);

        return LoadPackage(FileName.baseName.stripExtension, jstring);
    }
    DSYMBOL LoadFile(string pkg, string FileName)
	{
		auto jstring = readText(FileName);
		mModules[pkg] = LoadPackage(pkg, jstring);

		return mModules[pkg];
	}

    DSYMBOL LoadDTagsFile(string FileName)
    {
        string jtext = readText(FileName);

        auto jval = jtext.parseJSON();


        DSYMBOL LoadKids(JSON child)
        {


            DSYMBOL rv = new DSYMBOL;
            rv.Path = cast(string)child.object["path"];

            rv.Scope = rv.Path.split(".");

            rv.Name = rv.Scope[$-1];

            rv.Kind = cast(SYMBOL_KIND)child["kind"];
            rv.Type = cast(string)child["type"];
            rv.Signature = cast(string)child["signature"];
            rv.Protection = cast(string)child["protection"];

            rv.Comment = cast(string)child["comment"];
            rv.File = cast(string)child["file"];
            rv.Line = cast(int)child["line"];

            rv.Base = cast(string)child["base"];
            rv.Interfaces = cast(string[])child["interfaces"].array;
            rv.Icon = GetIcon(rv);

            foreach(kid; child["children"].array)rv.Children ~= LoadKids(kid);
            return rv;
        }


        DSYMBOL pkg;

        foreach(mod; jval.array)
        {
                auto sym = LoadKids(mod);
                mModules[sym.Name] = sym;
                emit([mModules[sym.Name]]);
        }

        return pkg;
    }



//=====================================================================================================================
//=====================================================================================================================

    DSYMBOL[] FindAncestors(string CandidatePath)
    {
        DSYMBOL[] rv;

        bool CheckKid(DSYMBOL thisun)
        {
            if(thisun.Path == CandidatePath)
            {
                rv ~= thisun;
                rv ~= FindAncestors(thisun.Base);
                return true;
            }
            foreach(kid; thisun.Children)if(CheckKid(kid))return true;
            return false;
        }

        foreach(mod; mModules)
        {
            if(mod.Path == CandidatePath)
            {
                rv ~= mod;
                rv ~= FindAncestors(mod.Base);
                return rv;
            }

            foreach(kid; mod.Children) if(CheckKid(kid))break;
        }
        return rv;
    }

    DSYMBOL[] FindDescendants(string CandidatePath)
    {
        DSYMBOL[] rv;
        void CheckKid(DSYMBOL thisun)
        {
            if(thisun.Base == CandidatePath)rv ~= thisun;
            foreach(kid; thisun.Children)CheckKid(kid);
        }

        foreach(mod; mModules)
        {
            if(mod.Base == CandidatePath) rv ~= mod;
            foreach(kid; mod.Children)CheckKid(kid);
        }
        return rv;
    }


    DSYMBOL[] FindExact(string Candidate)
    {
        DSYMBOL[] RV;
        void CheckKids(DSYMBOL membersym)
        {

            if(membersym.Path == Candidate)
            {
                RV ~= membersym;
                //return;
            }

            foreach(runt; membersym.Children)
            {
                if(runt.Path == Candidate)
                {
                    RV ~= runt;
                    //return;
                }

                CheckKids(runt);
            }
        }


        foreach(mod; mModules)
        {
            if(mod.Path == Candidate) RV ~= mod;
            foreach(kid; mod.Children)
            {
                //if(kid.Path == Candidate)RV ~= kid;
                CheckKids(kid);

            }
        }
        return RV;
    }


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
        if(pool.length < 1)pool = mModules.values;

        foreach(sym; pool)CheckSymbol(sym);
        return rval;
    }

    DSYMBOL[] GetMembers(string[] Candidate)
    {

        DSYMBOL[] rval;

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
                if(xsym.Kind == SYMBOL_KIND.FUNCTION) rval ~= GetMembers(ScopeSymbol(xsym.Type));
                if(xsym.Kind == SYMBOL_KIND.VARIABLE) rval ~= GetMembers(ScopeSymbol(xsym.Type));
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

        foreach(sym; mModules)
        {
            CheckSymbol(sym);
        }
        return rval;
    }

    DSYMBOL GetModuleFromFileName(string FileName)
    {

        foreach(key, pkg; mModules)
        {
            foreach(mod; pkg.Children) if(mod.File == FileName) return mod;
        }
        return null;
    }

    void SaveSymFile(string SaveToFile)
    {

        auto jdata = jsonArray();

        JSON SaveKid(DSYMBOL dsym)
        {
                auto kidjson = jsonObject();

                //kidjson["name"] = dsym.Name;
                kidjson["path"] = dsym.Path;
                //kidjson["scope"] = jsonArray();
                //foreach(scp; dsym.Scope) kidjson["scope"] ~= JSON(scp);
                kidjson["kind"] = convertJSON(dsym.Kind);//cast(int) dsym.Kind;
                kidjson["type"] = dsym.Type;
                kidjson["signature"] = dsym.Signature;
                kidjson["protection"] = dsym.Protection;
                kidjson["comment"] = dsym.Comment;
                kidjson["file"] = dsym.File;
                kidjson["line"] = convertJSON(dsym.Line);
                kidjson["base"] = dsym.Base;
                kidjson["interfaces"] = jsonArray();
                foreach(IF; dsym.Interfaces) kidjson["interfaces"] ~= JSON(IF);
                //kidjson["icon"] = dsym.Icon;

                kidjson["children"] = jsonArray();
                foreach(kid; dsym.Children) kidjson["children"] ~= SaveKid(kid);
                return kidjson;
        }

        foreach(mod; mModules)
        {
                auto symjson = jsonObject();

                //symjson["name"] = mod.Name;
                symjson["path"] = mod.Path;
                //symjson["scope"] = jsonArray();
                //foreach(scp; mod.Scope) symjson["scope"] ~= JSON(scp);
                symjson["kind"] =convertJSON(mod.Kind);//cast(int) mod.Kind;
                symjson["type"] = mod.Type;
                symjson["signature"] = mod.Signature;
                symjson["protection"] = mod.Protection;
                symjson["comment"] = mod.Comment;
                symjson["file"] = mod.File;
                symjson["line"] = convertJSON(mod.Line);
                symjson["base"] = mod.Base;
                symjson["interfaces"] = jsonArray();
                foreach(IF; mod.Interfaces) symjson["interaces"] ~= JSON(IF);
                //symjson["icon"] = mod.Icon;

                symjson["children"] = jsonArray();
                foreach(kid; mod.Children) symjson["children"] ~= SaveKid(kid);
                jdata ~= symjson;
        }

        string x = jdata.toJSON!2();
        auto e = EncodingScheme.create("utf-8");
        x = cast(string)e.sanitize(cast(immutable(ubyte)[])x);
        std.file.write(SaveToFile, x);

    }


}

//xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

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
string[] ScopeSymbol(string preText)
{
    import std.string;
    import std.algorithm;
    string[] rval;

    preText = preText.chomp(".");

    long index;
    foreach(unit; preText.splitter('.'))
    {
        index = unit.countUntil('!');
        if(index >= 0)unit = unit[0..index];
        index = unit.countUntil('(');
        if(index >= 0) unit = unit[0..index];
        index = unit.countUntil('[');
        if(index >=0)unit = unit[0..index];
        rval ~= unit;
    }
    return rval;
}
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

    switch(X.Kind) with (SYMBOL_KIND)
    {
        case MODULE         :rv = color ~ `Ⓜ</span>`;break;
        case TEMPLATE       :rv = color ~ `Ⓣ</span>`;break;
        case FUNCTION       :rv = color ~ `⒡</span>`;break;
        case STRUCT         :rv = color ~ `Ⓢ</span>`;break;
        case CLASS          :rv = color ~ `Ⓒ</span>`;break;
        case INTERFACE      :rv = color ~ `Ⓘ</span>`;break;
        case VARIABLE       :rv = color ~ `v</span>`;break;
        case ALIAS          :rv = color ~ `a</span>`;break;
        case CONSTRUCTOR    :rv = color ~ `⒞</span>`;break;
        case ENUM           :rv = color ~ `Ⓔ</span>`;break;
        case ENUM_MEMBER    :rv = color ~ `e</span>`;break;
        case UNION          :rv = color ~ `Ⓤ</span>`;break;
        case IMPORT         :rv = color ~ `i</span>`;break;
        case MIXIN          :rv = color ~ `m</span>`;break;


        default : rv = color ~ `P</span>`;
    }
    return rv;
}


int BuildTagFile(string PkgPath, string PkgName, string[] Ipaths, string[] Jpaths)
{
    scope(failure)return 1;
    string docfile = PkgName.setExtension(".html");
    string jsonfile = PkgName.setExtension(".json");
    
    string[] CmdLine = [ "dmd", "-c", "-o-", "-D", "-X", "-release", "-v"];
    CmdLine ~= Ipaths ~ Jpaths;
    CmdLine ~= ["-Df" ~ docfile];
    CmdLine ~= ["-Xf" ~ jsonfile];
    
    dwrite (CmdLine);
    dwrite (PkgPath);
    
    foreach(string srcFile; dirEntries(PkgPath, SpanMode.depth))
    {
        dwrite(srcFile);
        if((srcFile.extension == ".d") || (srcFile.extension == ".di"))
        {
            CmdLine ~= srcFile;
        }
    }
    
    auto res = execute(CmdLine);
    if(docfile.exists())docfile.remove();
    
    auto MainPackage = new SYMBOLS;
    MainPackage.LoadFile(PkgName, jsonfile);
    MainPackage.SaveSymFile(buildPath(SystemPath("tags"),setExtension(PkgName,".dtags")));
    return 0;
}
