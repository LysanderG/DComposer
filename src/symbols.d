//      symbols.d
//
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.

module symbols;


import dcore;


import std.conv;
import std.array;
import std.json;
import std.file;
import std.string;
import std.stdio;
import std.path;
import std.algorithm;
import std.signals;
import std.parallelism;

import glib.SimpleXML;



//big warning split scope with std.string.split(".") is too simple --- template constraints have . as a scope operator dumby
//must fix this you simple minded moron!  how could you over look this and then take over an hour to figure out why crap was crashing!


class DSYMBOL
{
    string		Name;               ///symbol name
    string      Path;               ///full path of this symbol
    string[]    Scope;              ///scope path to this symbol (path without Name)

	string		Base;               ///what the symbol inherits (enum's can inherit a type?)

    string		Type;               ///basically the signature (w/o the name) ie void(int, string) or uint or not always present
	string		Kind;               ///variable function constructor template struct class module union enum alias ...
    string      ReturnType;         ///if symbol is a function (or a Template?) what does it return? We can do somelib.getAnInterface(input).getData().x

    string		Comment;            ///ddoc comment associated with symbol (only if compiled with -D)

    string      Protection;         ///this is newly added ... going to screw me up!

    string		InFile;             ///the file where symbol is defined
	int			OnLine;             ///the line on which it is defined on



    bool		Scoped;             ///does this symbol have children
    DSYMBOL[]   Children;           ///All children
    string      Icon;


    string GetIcon()                ///WHY IS THIS A FUNCTION??? compute once and cache stupid!
    {
        string color;
        string rv;

        switch(Protection)
        {
            case "private"      : color = `<span foreground="red">`;break;
            case "public"       : color = `<span foreground="black">`;break;
            case "protected"    : color = `<span foreground="cyan">`;break;
            case "package"      : color = `<span foreground="green">`;break;
            default : color = `<span foreground="green">`;
        }

        switch(Kind)
        {
            case "module"       :rv = color ~ `Ⓜ</span>`;break;
            case "template"     :rv = color ~ `Ⓣ</span>`;break;
            case "function"     :rv = color ~ `⒡</span>`;break;
            case "struct"       :rv = color ~ `Ⓢ</span>`;break;
            case "class"        :rv = color ~ `Ⓒ</span>`;break;
            case "interface"    :rv = color ~ `😐</span>`;break;
            case "variable"     :rv = color ~ `⒱</span>`;break;
            case "alias"        :rv = color ~ `ⓐ</span>`;break;
            case "constructor"  :rv = color ~ `⒞</span>`;break;
            case "enum"         :rv = color ~ `Ⓔ</span>`;break;
            case "enum member"  :rv = color ~ `⒠</span>`;break;
            case "union"        :rv = color ~ `Ⓤ</span>`;break;

            default : rv = color ~ `P</span>`;
        }
        return rv;
    }
}

/**
 * Holds all the global symbols.  Symbols are obtained from any json files passed in.
 * The json files are created with the dmd -X option.
 * So for any package you want the symbols for just create a json file for it and do SYMBOLS.Load(pkg.json).
 * Project tag files will automatically be passed in.
 * */
class SYMBOLS
{
    private:

    /**
     * Associative array of symbols
     * ie mSymbols["std"] would be phobos std library symbols
     * mSymbols["gtk"] mSymbols["core"]
     * Project symbols will be autoloaded as mSymbols[Project.Name]
     * */

    DSYMBOL[string] mSymbols;
    string          mProjectKey; ///actually project name, used to remove project tags since Project.Name is cleared before Project.Event.emit("close");

    string mLastComment; 		///holds last comment before dittos



    ///given jval from a json file fills up the symbols in this object
    void BuildSymbols(JSONValue jval, ref DSYMBOL sym , string Module = "")
    {
        switch (jval.type)
        {
            case JSON_TYPE.ARRAY :
            {
                DSYMBOL tsym;
                sym.Children.length = jval.array.length;

                foreach (indx, jv; jval.array)
                {
                    tsym = new DSYMBOL;
                    tsym.Path = sym.Path;
                    BuildSymbols(jv, tsym, Module);

                    sym.Children[indx] = tsym;

                }
            }
            break;

            case JSON_TYPE.OBJECT :
            {
                foreach(key, obj; jval.object)
                {
                    switch (key)
                    {
                        case "name"         : sym.Name          = obj.str;break;
                        case "type"         : sym.Type          = obj.str;break;
                        case "kind"         : sym.Kind          = obj.str;break;
                        case "base"         : sym.Base          = obj.str;break;
                        case "comment"      :
                        {
                            sym.Comment       = obj.str;
                            if(canFind(toLower(sym.Comment), "ditto")) sym.Comment = "~" ~ mLastComment;
                            mLastComment = sym.Comment;
                            break;
                        }
                        case "protection"   : sym.Protection    = obj.str;break;
                        case "file"         : Module            = obj.str;break;
                        case "line"         : sym.OnLine        = cast(int)obj.integer;break;
                        default         : break;
                    }
                }
                if(sym.Kind != "module")
                {
                    sym.Name = sym.Name.replace(".","﹒"); //this is a terrible hack!! gonna screw someone up one day
                }
                else
                {
                    auto ndx = std.string.indexOf(sym.Name,".");
                    sym.Name = sym.Name[ndx+1..$];
                }
                if(sym.Kind == "function")
                {
                    //DONT FORGET stuff like immutable (ident)[] (int paramone, ...) Seriously todo
                    auto indx = std.string.indexOf(sym.Type, "(");
                    if (indx > 0)sym.ReturnType = sym.Type[0..indx];
                    else sym.ReturnType.length = 0;
                }
                sym.Icon = sym.GetIcon();

                sym.InFile = Module;
                if(sym.Name is null)sym.Name = baseName(Module.chomp(".d"));
                if(!sym.Path.empty)sym.Path ~= "." ~ sym.Name;
                else sym.Path = sym.Name;
                sym.Scope = split(sym.Path, ".");
                if("members" in jval.object)
                {
                    sym.Scoped = true;
                    BuildSymbols(jval.object["members"], sym, Module);
                }
                else
                {
                    sym.Scoped = false;
                }

                auto lastIndex = sym.Name.lastIndexOf(".");
                if ((lastIndex > -1) && (sym.Kind == "module"))
                {
                    sym.Name = sym.Name[lastIndex+1..$];
                }

            }
            break;
            default : writeln("default"); break;
        }

    }

	/**
	 * Watches for project events
	 * (symbols == tags)
	 * may
	 * 	remove project tags
	 * 	add project tags
	 * 	refresh tags
	 *  or change to projectkey
	 * */
    void ProjectWatch(ProEvent EventType)
    {
		switch (EventType)
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
													Load(Project.Name(), Project.Name() ~ ".tags");
													return;
												}
			case ProEvent.FailedTags			:
												{
													scope(failure){Log.Entry("Failed to load project symbols","Error");return;}
													if(Project.Name() in mSymbols) return; //keep the symbols we have if none try to load old symbols
													Load(Project.Name(), Project.Name() ~ ".tags");
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

    /*
     * Given a 'Scope' returns all the child symbols of that 'Scope'
     * The more specific the 'Scope' the more accurate the results.
     * */
    DSYMBOL[] GetInScopeSymbols(string[] Scope)
    {

        DSYMBOL[] ReturnSyms;

		//following line is necessary to avoid seg faults processing templates
        if(Scope.length < 1) return ReturnSyms;

        void _Process(DSYMBOL Sym)
        {

            foreach(kid; Sym.Children) _Process(kid);

            if(endsWith(Sym.Scope[0..$-1]   , Scope))
            {
                ReturnSyms ~= Sym;
            }

            if(endsWith(Sym.Scope, Scope[$-1]))
            {

                if(Sym.Base.length > 0) ReturnSyms ~= GetInScopeSymbols([Sym.Base]);

                if(Sym.Kind == "variable") ReturnSyms ~= GetInScopeSymbols(split(Sym.Type, "."));

                if(Sym.Kind == "function") ReturnSyms ~= GetInScopeSymbols(split(Sym.ReturnType,"."));

            }
        }
        foreach(sym; mSymbols) _Process(sym);

        return ReturnSyms;
    }

    DSYMBOL[] GetCompletionSymbols(string Candidate,  DSYMBOL[] Symbols, bool ParseKids = false)
    {
        DSYMBOL[] ReturnSyms;

        void _Process(DSYMBOL Sym)
        {
            if(startsWith(Sym.Name, Candidate))
            {
                ReturnSyms ~= Sym;
            }
            if(ParseKids)foreach(kid; Sym.Children) _Process(kid);
        }

        foreach(sym; Symbols) _Process(sym);
        return ReturnSyms;
    }

    /**
     * Reloads all symbol files in configuration file.
     * And reloads project tags if any.
     *
     * Bugs: should remove all symbols first.
      */
    void Reconfigure()
    {
        foreach(name; mSymbols.keys)
        {
            if(name != Project.Name()) mSymbols.remove(name);
        }
        string[] keys = Config().getKeys("SYMBOL_LIBS");

		foreach(key; keys)
		{
			auto tmp = Config().getString("SYMBOL_LIBS", key, "huh");
			Load(key, tmp);
		}

		//string[string] tmp;
		//foreach (key; keys) tmp[key] = Config.getString("SYMBOL_LIBS", key, "huh");
		//foreach (key; parallel(keys))
		//{
		//	mSymbols[key] = LoadConcurrent(key, tmp[key]);
		//}
    }


    public :

	/**
	 * Engage $(TITLE)
	 * (ie get it ready to run)
	 * */
    void Engage()
    {

        string[] keys = Config().getKeys("SYMBOL_LIBS");

		//at least should load the stdlib tags
        if(keys.length < 1)
        {
			keys = ["std"];
			Config.setString("SYMBOL_LIBS", keys[0], Config.ExpandPath("$(HOME_DIR)/tags/stdlib.json"));
		}


		if(Config.getBoolean("SYMBOLS", "auto_load_symbols", true))
		{

			foreach(key; keys)
			{
				auto tmp = Config().getString("SYMBOL_LIBS", key, "huh");
				Load(key, tmp);
			}
		}

        if(Config.getBoolean("SYMBOLS", "auto_load_project_symbols", true))
        {
            Project.Event.connect(&ProjectWatch);
        }

        Config.Reconfig.connect(&Reconfigure);
        //Reconfigure();  //don't need this run now. doubles app load time too.

        string x = "Engaged SYMBOLS [";
        foreach(ii, key; keys){if(ii != 0)x ~= `,`; x ~= `"` ~ key ~`"`;}
        x ~= "]";
        Log().Entry(x);
    }

	/**
	 * Disengage $(TITLE)
	 * (ie clean up / save or whatever )
	 * */
    void Disengage()
    {
        if(Config.getBoolean("SYMBOLS", "auto_load_project_symbols", true))
        {
            Project.Event.disconnect(&ProjectWatch);
        }
        Log().Entry("Disengaged SYMBOLS");
    }


    /**
     * Adds a 'TagFile' (dmd -X json file) to the configurtion file.

     * If user opts for auto symbol loading this file of symbols will
     * be automatically loaded at start up.

     * Does not actually load anything.  Have to run Load or Reconfigure
     * or wait for a restart.  Nor does it check that TagFile exists or key
     * is already in use.
     *
     * params:
     *  key = name of package, used as associative key.
     *  TagFile = json file with symbols.
     *
     *
     **/
    void AddCommonTagFile(string key, string TagFile)
    {
        Config().setString("SYMBOLS", key, TagFile);
    }



	/**
	 * Loads a 'TagFile'
	 * PARAMS:
	 * key = the name of the package of symbols also used as associative array key
	 * symfile = actual json file to be loaded
	 * */
    void Load(string key, string symfile)
    {
		scope(failure)
		{
			Log.Entry("Failed to Load Tag File " ~ symfile, "Error");
			return;
		}

        auto JRoot = parseJSON(readText(symfile));

        DSYMBOL X = new DSYMBOL;
        X.Name = key;
        X.Path = key;
        X.Scope = [key];
        X.Kind = "package";

        BuildSymbols(JRoot, X);

        mSymbols[key] = X;
        emit();

    }

	/**
	 * Load modified to return a DSYMBOL so it can be used
	 * in a parallel foreach (see std.parallel)
	 * Actually slowed symbol loading down significantly.
	 * */
    DSYMBOL LoadConcurrent(string key, string symfile)
        {

        auto JRoot = parseJSON(readText(symfile));

        DSYMBOL X = new DSYMBOL;
        X.Name = key;
        X.Path = key;
        X.Scope = [key];
        X.Kind = "package";

        BuildSymbols(JRoot, X);


        emit();
		return X;
    }

     /**
      * Dont think this function is even used
      * +1 for code coverage
      * */
    DSYMBOL[] PossibleMatches(string Candidate)
    {
        DSYMBOL[] RetSyms;
        auto CandiPath = GetCandidatePath(Candidate);
        auto CandiName = GetCandidateName(Candidate);

        //if (CandiName.length == 0) return RetSyms;

        void _Process(DSYMBOL x)
        {
            if( startsWith(x.Name, CandiName))
            {

                if(CandiPath.length > 0)
                {

                    if( endsWith(x.Scope, CandiPath) )
                    {
                        RetSyms ~= x;

                    }

                }
                else
                {
                    RetSyms ~= x;
                }

            }
            if((x.Base.length > 0) && (CandiPath.length > 1) && (x.Scope.length > 1) && endsWith(x.Scope[$-1], CandiPath[$-1]) )
            {
                auto memsyms = GetMembers(x.Base);
                foreach (member;memsyms) if( startsWith(member.Name, CandiName)) RetSyms ~= member;
            }

            foreach(kid; x.Children) _Process(kid);
        }

        foreach(symbol; mSymbols) _Process(symbol);

        return RetSyms;
    }


    /**
     * ditto
     * */
    DSYMBOL[] GetMembers(string Base, DSYMBOL[] HayStack = null)
    {
        if(HayStack is null) HayStack = mSymbols.values;
        DSYMBOL[] RetSyms;

        void _Process(DSYMBOL Sym)
        {
            if(Sym.Name == Base)
            {
                foreach(kid; Sym.Children) RetSyms ~= kid;
                if(Sym.Base.length > 0)RetSyms ~= GetMembers(Sym.Base );
            }
            foreach(kid; Sym.Children) _Process(kid);
        }
        foreach(sym; HayStack) _Process(sym);


        return RetSyms;
    }

	/**
	 * Given a Candidate (aaa.bbb.llll())
	 * return all matching function symbols
	 * */
    DSYMBOL[] MatchCallTips( string Candidate)
    {
        DSYMBOL[] ReturnSyms;

        ReturnSyms = Match(Candidate);

        if(ReturnSyms.length > 1) return ReturnSyms;

        auto CandiName = GetCandidateName(Candidate);
        if(CandiName.length > 0) ReturnSyms = Match("."~CandiName );

        return ReturnSyms;
    }

	/**
	 * Returns possibles completions of Candidate (ie matches)
	 * params:
	 * Candidate = partial symbol to match, can be a symbol path (std.algorithm.sort)
	 * */
    DSYMBOL[] Match(string Candidate)
    {
        DSYMBOL[] ReturnSyms;
        DSYMBOL[] InScopeSyms;

        bool NoScopeResults;

        auto CandiPath = GetCandidatePath(Candidate);
        auto CandiName = GetCandidateName(Candidate);

        if(CandiPath.length > 0)
        {
            InScopeSyms = GetInScopeSymbols(CandiPath);

            NoScopeResults = (InScopeSyms.length < 1);
            if(NoScopeResults) InScopeSyms = mSymbols.values;

        }
        else
        {
            InScopeSyms = mSymbols.values;
            NoScopeResults = true;
        }


        if(CandiName.length > 0) ReturnSyms = GetCompletionSymbols(CandiName, InScopeSyms, NoScopeResults);
        else if(!NoScopeResults) ReturnSyms = InScopeSyms;

        return ReturnSyms;

    }

	/**
	 * Returns any symbol that is an "exact" match for candidate name.
	 * Multible symbol returns are possible if different packages or objects
	 * have members with identical names.
	 * params:
	 * Candidate = full symbol to match, can be a symbol path (std.algorithm.sort)
	 * */
    DSYMBOL[] ExactMatches(string Candidate)
    {
        DSYMBOL[] RetSyms;
        auto CandiPath = GetCandidatePath(Candidate);
        auto CandiName = GetCandidateName(Candidate);


        auto tmpSyms = Match(Candidate);

        foreach(ts; tmpSyms) if (ts.Scope[$-1] == CandiName) RetSyms ~=  ts;

        return RetSyms;
    }


    DSYMBOL[string] Symbols(){return  mSymbols.dup;}

    mixin Signal!();
    mixin Signal!(DSYMBOL[]) Forward;

	/**
	 * Gets the 'path' of Candidate removing any whitespace around the "." seperator which
	 * maybe introduced for fomatting ...
	 * Examples:
	 * ----
	 * string c = "myAClassObject	.Buffer		.flush();";
	 * string d = "yourAClassObject	.Buffer		.flush();";
	 *
	 * string e = StringPath(c);
	 * string f = StringPath(d);
	 *
	 * assert(e == "myAClassObject.Buffer");
	 * assert(f == "yourAClassObject.Buffer");
	 * ----
	 * params:
	 * Candidate = symbol name possibly including scope/path(aa.bb.name)
	 * returns: The scope/path part of candidate sans whitespace possibly ""
	 * */
    string StringPath(string Candidate)
    {
        string rv;
        rv = Candidate.removechars(std.ascii.whitespace);
        auto indx = rv.lastIndexOf(".");
        if(indx > 0) rv = rv[0..indx];
        else rv.length = 0;
        return rv;
    }

    /**
     *Similiar to StringPath but
     *params: Candidate = optional/partial scope/path plus name of symbol.
     *returns:an array of strings for the scope/path of candidate
     */
    string[] GetCandidatePath(string Candidate)
    {

        string[] rv = split(StringPath(Candidate), ".");

        return rv;
    }

	/**
	 * Filters out the scope/path of Candidate.
	 * returns: The name of Candidate (or partial name)
	 * */
    string GetCandidateName(string Candidate)
    {
        string rv;
        auto indx = std.string.lastIndexOf(Candidate,".");
        if(indx < 0)
        {
            rv = Candidate;
            return rv;
        }

        if(indx >= Candidate.length-1)
        {
            rv.length = 0;
            return rv;
        }
        if( indx < Candidate.length-1)
        {
            rv = Candidate[indx+1..$];
            return rv;
        }
        return rv;
    }

    /**
    * Allows an outside source (ie element) to cause a forward
    * signal to be emitted
    */
    void TriggerSignal(DSYMBOL[] SymbolsToPass)
    {
        Forward.emit(SymbolsToPass);
    }



}
