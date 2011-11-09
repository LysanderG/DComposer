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
	bool		Scoped;             //does this symbol have children
	string		Type;               //basically the signature (w/o the name) ie void(int, string) or uint or not always present
	string		Kind;               //variable function constructor template struct class module union enum alias ... 
	string		Comment;            //ddoc comment associated with symbol (only if compiled with -D)
	string		Base;               //what the symbol inheirits (enum's can inherit a type?)
    string      Protection;         //this is newly added ... going to screw me up!
        
    string		InFile;             //the file where symbol is defined 
	int			OnLine;             //the line on which it is defined on

    string      Path;               //full path of this symbol

    DSYMBOL[]   Children;           //All children
	DSYMBOL[string]	ScopedChildren; //subset of children that have members


    string GetIcon()
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
            case "module"       :rv = color ~ `▣</span>`;break;
            case "template"     :rv = color ~ `◌</span>`;break;
            case "function"     :rv = color ~ `◈</span>`;break;
            case "struct"       :rv = color ~ `◎</span>`;break;
            case "class"        :rv = color ~ `◉</span>`;break;
            case "variable"     :rv = color ~ `◇</span>`;break;
            case "alias"        :rv = color ~ `↭</span>`;break;
            case "constructor"  :rv = color ~ `✵</span>`;break;
            case "enum"         :rv = color ~ `◬</span>`;break;
            case "enum member"  :rv = color ~ `△ </span>`;break;
            case "union"        :rv = color ~ `○</span>`;break;

            default : rv = color ~ `X</span>`;
        }
        return rv;
    }
}


class SYMBOLS
{
    private:
    
    //ok symbols will be like mSymbols["std"] or mSymbols["gtk"] mSymbols[GetProject().Name]
    //or if project type is null foreach opendoc mSymbol["docname"].load ...
    DSYMBOL[string] mSymbols;


    DSYMBOL[] FindScope(string[] Scopes)
    {
        DSYMBOL[] RV;

        void _FindScope(DSYMBOL symX, string[] scopeX)
        {
            if(symX.Name == scopeX[0])
            {
                
                if (scopeX.length == 1) 
                {
                    RV.length = RV.length +1;
                    RV[$-1] = symX;
                    return;
                }
                scopeX = scopeX[1..$];
            }
            foreach(kid; symX.Children) _FindScope(kid, scopeX);

        }
        writeln("scope == ",Scopes);
        foreach (sym; mSymbols)
        {
            _FindScope(sym, Scopes);
        }
        foreach(R; RV) writeln(R.Path);
        return RV;
    }

    DSYMBOL[] AllSymbols()
    {
        DSYMBOL[] rv;

        void GetSyms(DSYMBOL symX)
        {
            rv ~= symX;
            foreach(kid; symX.Children)
            {
                GetSyms(kid);
            }
        }
                
        
        foreach(sym; mSymbols)
        {
            GetSyms(sym);
        }

        return rv;
    }           
       

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

                    
                    if(tsym.Scoped)sym.ScopedChildren[tsym.Name] = tsym;
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
                        case "comment"      : sym.Comment       = obj.str;break;
                        case "protection"   : sym.Protection    = obj.str;break;
                        case "file"         : Module            = obj.str;break;
                        case "line"         : sym.OnLine        = cast(int)obj.integer;break;
                        default         : break;
                    }
                }
                if(sym.Kind != "module")
                {
                    sym.Name = sym.Name.replace(".","﹒");
                }      
                sym.InFile = Module;
                if(sym.Name is null)sym.Name = baseName(Module.chomp(".d"));
                if(!sym.Path.empty)sym.Path ~= "." ~ sym.Name;
                else sym.Path = sym.Name;
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
    public :

    void Engage()
    {
        ulong waste;
        string[] keys = GetConfig().getKeys("SYMBOLS", waste);

        foreach(key; keys)
        {
            auto tmp = GetConfig().getString("SYMBOLS", key);
            
            Load(key, tmp);
        }

        GetLog().Entry("Engaged SYMBOLS");        
    }

    void Disengage()
    {
        GetLog().Entry("Disengaged SYMBOLS");
    }

    void AddCommonTagFile(string key, string TagFile)
    {
        GetConfig().setString("SYMBOLS", key, TagFile);
    }       

    
    //this will replace mSymbol[key] if it exists
    //actually loads a json file from dmd -X into this structure
    void Load(string key, string symfile)
    {
        auto JRoot = parseJSON(readText(symfile));
        
        DSYMBOL X = new DSYMBOL;
        X.Name = key;
        //X.Path = key;
        BuildSymbols(JRoot, X);

        mSymbols[key] = X;
        emit();
    }

    //same as Load above but infers the key from the actual tag file
    void Load(string symfile)
    {}

    

        
    //given the Candidate (preferably fully scoped -- std.stdio.File.writef --
    //return return found scopes and set refs modules[] and lineno[] to locations
    string[] GetLocation(string ScopedCandidate, out string[] Modules, out int[] LineNo)
    {
        string[] rv;
        string[] Candidate = ScopedCandidate.split(".");
        DSYMBOL[] matches = FindScope(Candidate);

        foreach (match; matches)
        {
            rv ~= match.Path;
            Modules ~= match.InFile;
            LineNo ~= match.OnLine;
        }
        return rv;
    }

    string[] GetCallTips(string Candidate)
    {
        string[] rv;
        string[] CandiPath = Candidate.split(".");

        DSYMBOL[] matches = FindScope(CandiPath);
       
        foreach(match; matches)
        {
            if(match.Kind == "function")
            {
                auto cut = findSplit(match.Type,"(");
                //= " " ~ cut[0] ~ " " ~ match.Name ~ cut[1] ~ cut[2];
                rv ~= match.GetIcon() ~ SimpleXML.escapeText(" " ~ cut[0] ~ " " ~ match.Name ~ cut[1] ~ cut[2],-1);
            }
        }

        return rv;
    }

    string[] GetMembers(string Candidate)
    {
        string[] rv;
        string[] CandiPath = Candidate.split(".");

        DSYMBOL[] PREmatches = FindScope(CandiPath);

        foreach(preM; PREmatches)
        {
            //if prem has kids add those to rv
            //if prem is a variable of a type that has kids add those to rv
            //if prem is a function with a return type that has kids add those to rv

            if(preM.Scoped) foreach(kid; preM.Children)
            {
                rv ~= kid.GetIcon() ~ " " ~  SimpleXML.escapeText(kid.Name, -1);
                continue;
            }
            if(preM.Kind == "variable")
            {
                auto scp = split(preM.Type, ".");
                DSYMBOL[] POSTmatches = FindScope(scp);
                foreach(sym; POSTmatches)
                {
                    if(sym.Scoped) foreach(kid; sym.Children) rv ~= kid.GetIcon() ~ " " ~  SimpleXML.escapeText(kid.Name, -1);
                }
            }
            if (preM.Kind == "function")
            {
                string[] FuncRetType = split(preM.Type, "(");
                auto tmp = split(FuncRetType[0], ".");
                DSYMBOL[] POSTmatches = FindScope(tmp);
                foreach(sym; POSTmatches)
                {
                    if(sym.Scoped) foreach(kid; sym.Children) rv ~= kid.GetIcon() ~ " " ~  SimpleXML.escapeText(kid.Name, -1);
                }
            }
        }

        return rv;
    }

    string[] Match(string Candidate)
    {
        if(Candidate.length < 2) return null;
        string[] rv;
        string[] CandiPath = Candidate.split(".");
        
        DSYMBOL[] matches;
        if(CandiPath.length  == 1) matches = AllSymbols();
        else matches = FindScope(CandiPath[0..$-1]);
        foreach (match; matches)
        {

            /*if(startsWith(match.Name, CandiPath[$-1]) > 0)
            {
                
                rv ~= match.GetIcon() ~ " " ~ SimpleXML.escapeText(match.Name, -1);
            }*/
            foreach(kid; match.Children)
            {
                if(kid.Kind == "template") continue;
                if(startsWith(kid.Name, CandiPath[$-1]) > 0) rv ~= kid.GetIcon() ~ " " ~ SimpleXML.escapeText(kid.Name, -1);
            }
        }
        return rv;
    }


 
        

        

    
    DSYMBOL[string] Symbols(){return  mSymbols.dup;}

    string GetValueFromType(string type)
    {
        if(type == "module")        return `<span foreground="red" >▣</span>`;
        if(type == "template")      return `<span foreground="green" >◌</span>`;
        if(type == "function")      return `<span foreground="yellow">▶</span>`;
        if(type == "struct")        return `<span foreground="black">◎</span>`;
        if(type == "class")         return `<span foreground="black">◉</span>`;
        if(type == "variable")      return `<span foreground="green">▶</span>`;
        if(type == "alias")         return `<span foreground="black">▰</span>`;
        if(type == "constructor")   return `<span foreground="black">✵</span>`;
        if(type == "enum")          return `<span foreground="cyan">▲</span>`;
        if(type == "enum member")   return `<span foreground="cyan">◬ </span>`;
        if(type == "union")         return `<span foreground="black">○</span>`;
        return " ";
        
        //◈
    }            

    mixin Signal!();
}



