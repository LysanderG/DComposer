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

import glib.SimpleXML;



//big warning split scope with std.string.split(".") is too simple --- template constraints have . as a scope operator dumby
//must fix this you simple minded moron!  how could you over look this and then take over an hour to figure out why crap was crashing!


class DSYMBOL
{
    string		Name;               //symbol name
    string      Path;               //full path of this symbol
    string[]    Scope;              //scope path to this symbol (path without Name)

	string		Base;               //what the symbol inherits (enum's can inherit a type?)    

    string		Type;               //basically the signature (w/o the name) ie void(int, string) or uint or not always present
	string		Kind;               //variable function constructor template struct class module union enum alias ...
    string      ReturnType;         //if symbol is a function (or a Template?) what does it return? We can do somelib.getAnInterface(input).getData().x

    string		Comment;            //ddoc comment associated with symbol (only if compiled with -D)

    string      Protection;         //this is newly added ... going to screw me up!
        
    string		InFile;             //the file where symbol is defined 
	int			OnLine;             //the line on which it is defined on


    
    bool		Scoped;             //does this symbol have children
    DSYMBOL[]   Children;           //All children
    string      Icon;


    string GetIcon()                //WHY IS THIS A FUNCTION??? compute once and cache stupid!
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

            default : rv = color ~ `X</span>`;
        }
        return rv;
    }
}


class SYMBOLS
{
    private:
    
    //ok symbols will be like mSymbols["std"] or mSymbols["gtk"] mSymbols[Project().Name]
    //or if project type is null foreach opendoc mSymbol["docname"].load ...
    DSYMBOL[string] mSymbols;

    string LastComment; //holds last comment before dittos

       

    //given jval from a json file fills up the symbols in this object
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
                            if(canFind(toLower(sym.Comment), "ditto")) sym.Comment = "~" ~ LastComment;
                            LastComment = sym.Comment;
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

        //with(sym)
        //{
        //    
        //    XX.writeln(Name,"\n\tPath=", Path,"\n\tScope=", Scope,"\n\tBase=", Base,"\n\tType=", Type,"\n\tKind=", Kind, "\n\tReturnType=",ReturnType,"\n\tIcon=",Icon);
        //}
        
    }

    void ProjectWatch(string EventType)
    {

        if(EventType == "Close")
        {
            mSymbols.remove(Project.Name());
            emit();
            return;
        }

        if(EventType == "CreateTags")
        {
            scope(failure){Log.Entry("Failed to load project symbols","Error");return;}
            Load(Project.Name(), Project.Name() ~ ".tags");
            return;
        }
    }
    
    public :

    void Engage()
    {
        ulong waste;
                
        string[] keys = Config().getKeys("SYMBOL_LIBS", waste);

        foreach(key; keys)
        {
            auto tmp = Config().getString("SYMBOL_LIBS", key, "huh");
            
            Load(key, tmp);
        }

        if(Config.getBoolean("SYMBOLS", "auto_load_project_symbols", true))
        {
            Project.Event.connect(&ProjectWatch);
        }
            
        string x = "Engaged SYMBOLS [";
        foreach(ii, key; keys){if(ii != 0)x ~= `,`; x ~= `"` ~ key ~`"`;}
        x ~= "]";
        Log().Entry(x);        
    }

    void Disengage()
    {
        if(Config.getBoolean("SYMBOLS", "auto_load_project_symbols", true))
        {
            Project.Event.disconnect(&ProjectWatch);
        }
        Log().Entry("Disengaged SYMBOLS");
    }


    //add a tag file to config that will always be in the symbol tree
    //need a remove commontagfile too
    void AddCommonTagFile(string key, string TagFile)
    {
        Config().setString("SYMBOLS", key, TagFile);
    }       

    
    //this will replace mSymbol[key] if it exists (otherwise adds of course)
    //actually loads a json file from dmd -X into this structure
    File XX;
    void Load(string key, string symfile)
    {
        XX.open(key ~".tmptags", "w");
        auto JRoot = parseJSON(readText(symfile));
        
        DSYMBOL X = new DSYMBOL;
        X.Name = key;
        X.Path = key;
        X.Scope = [key];
        X.Kind = "package";
        
        BuildSymbols(JRoot, X);

        mSymbols[key] = X;
        emit();
        XX.close();
    }

        
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
    

    DSYMBOL[] ExactMatches(string Candidate)
    {
        DSYMBOL[] RetSyms;
        auto CandiPath = GetCandidatePath(Candidate);
        auto CandiName = GetCandidateName(Candidate);



        void _Process(DSYMBOL x)
        {
            if( (CandiName.length < 1) ||  (x.Name == CandiName) )
            {
                if(CandiPath.length > 0)
                {
                    if( endsWith(x.Scope, CandiPath) )
                    {
                        RetSyms ~= x;

                        if(x.Base.length > 1)
                        {
                            RetSyms ~= GetMembers(x.Base);
                        }
                    }
                }
                else
                {
                    RetSyms ~= x;
                }
            }
            
            if(x.Kind == "function")RetSyms ~= GetMembers(x.ReturnType);
            

            foreach(kid; x.Children) _Process(kid);
        }

        foreach(symbol; mSymbols) _Process(symbol);
        
        
        return RetSyms;
    }

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

    DSYMBOL[] MatchCallTips( string Candidate)
    {
        writeln("\n------------\nhello");
        DSYMBOL[] ReturnSyms;

        ReturnSyms = Match(Candidate);
        writeln(Candidate,"/",GetCandidateName(Candidate));

        foreach(i, retsym; ReturnSyms)std.stdio.write(i,". ",retsym.Name,"/",retsym.Kind, " --" );

        writeln("\n!!!!len === ",ReturnSyms.length);
        if(ReturnSyms.length > 1) return ReturnSyms;

        auto CandiName = GetCandidateName(Candidate);
        writeln("calltip candiname = ", CandiName);
        if(CandiName.length > 0) ReturnSyms = Match("."~CandiName );

        foreach(i, retsym; ReturnSyms)std.stdio.write(i,". ",retsym.Name,"/",retsym.Kind, " --" );
        writeln("\n!!!!len === ",ReturnSyms.length);

        return ReturnSyms;
    }
        

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

    //alias GetCompletionSymbols Match;
    DSYMBOL[] GetInScopeSymbols(string[] Scope)
    {
        
        DSYMBOL[] ReturnSyms;
        string[] Bases;

        void _Process(DSYMBOL Sym)
        {

            foreach(kid; Sym.Children) _Process(kid);
            
            if(endsWith(Sym.Scope[0..$-1]   , Scope))
            {
                ReturnSyms ~= Sym;

            }

            
            
            if(endsWith(Sym.Scope, Scope))
            {

                if(Sym.Base.length > 0) ReturnSyms ~= GetInScopeSymbols([Sym.Base]);

                if(Sym.Kind == "variable") ReturnSyms ~= GetInScopeSymbols(split(Sym.Type, "."));
                if(Sym.Kind == "function") ReturnSyms ~= GetInScopeSymbols(split(Sym.ReturnType,"."));

            }                      
            
        }
        foreach(sym; mSymbols) _Process(sym);


        
        
        return ReturnSyms;
    }

        
        
        
        

    
    DSYMBOL[string] Symbols(){return  mSymbols.dup;}
        

    mixin Signal!();


    string StringPath(string Candidate)
    {
        string rv;
        rv = Candidate.removechars(std.ascii.whitespace);
        auto indx = rv.lastIndexOf(".");
        if(indx > 0) rv = rv[0..indx];
        else rv.length = 0;
        return rv;
    }

    string[] GetCandidatePath(string Candidate)
    {
        
        string[] rv = split(StringPath(Candidate), ".");

        return rv;
    }
         

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
        


}
