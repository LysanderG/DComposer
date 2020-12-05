module extractflags;

import std.algorithm;
import std.array;
import std.string;
import std.regex;
import std.stdio;
import std.process;

import json;


int main(string[] args)
{
	string flagFileName;
	auto jsonFlags = jsonArray();
	
	auto rxVersion = regex(`v(\d+\.\d+\.\d+)`);
	//									1             2            3
	
	auto rxFlag = regex(`^\s*-+(?P<fullswitch>\S+)\s*(?P<brief>.*)`, "gm");
	
	
	auto dmdresults = executeShell("dmd -h");	
	if(dmdresults.status != 0) return dmdresults.status;
	
	auto allMatches = matchAll(dmdresults.output, rxFlag);
	
	File output = File("OUTPUT","w");
	foreach(m;allMatches)
	{
	    if(m["fullswitch"] == "help")continue;
	    if(m["fullswitch"] == "version")continue;
	    if(m["fullswitch"] == "man")continue;
	    if(m["fullswitch"].canFind("h|help|?"))continue;
	    
	    output.writeln("1 ",m);
	    output.writeln("2 ",m["fullswitch"]);
	    output.writeln("3 ",m["brief"]);
	    string x = m["fullswitch"] ~ "\n";
	    auto rxSwitch = regex(`(?P<switch>[\w-]*)[\[=]*\[*(?P<args>[^\n\]]*).*\n`);
	    
	    auto processedSwitch = matchFirst(x, rxSwitch);	    
	    output.writeln("4 ",processedSwitch["switch"]);
	    output.writeln("5 ",processedSwitch["args"]);    
	    output.writeln("-------------"); 
	    string[] choiceBriefs;
	    auto choices = ProcessChoices(processedSwitch["switch"],choiceBriefs);
	    foreach( ulong indx, ch; choices)
	    {
	        output.writeln(ch);
	        output.writeln("\t", choiceBriefs[indx]);
	    }
	    output.writeln("--------------");
    }
	return 0;
	
}

/*
@disable bool ProcessArgs(string flag, string argInput, out ARG_TYPE type, out string[] choices)
{
		if(argInput.length == 0)
		{
			type = ARG_TYPE.NONE;
			choices = ProcessChoices(flag);			
			return true;
		}
		if((argInput == "<num>") || (argInput == "<nnn>") || (argInput == "<level>"))
		{
			type = ARG_TYPE.NUMBER;
			choices = ProcessChoices(flag);
			return true;
        }
        if(argInput[0] != '[') 
        {
	        type = ARG_TYPE.STRING;
			choices = ProcessChoices(flag);	
	        return true;
        }
        
        type = ARG_TYPE.STR_ARRAY;
        long endPoint = argInput.countUntil("]");
        if(endPoint == -1) endPoint = argInput.length;
        argInput = argInput[1..endPoint];
        choices = argInput.split('|'); 
        //this is an 'extra' line for the same flag that just says do flag=help to get choices... so skip it
        if (choices.canFind("help"))return false; 
        string[] longChoices = ProcessChoices(flag);
        if(longChoices.length) choices = longChoices;
        return true;        
}*/

string[] ProcessChoices(string flag, out string[] subBrief)
{

	string[] rv;
    //man launches web browser!! so skip this
    if(flag == "man")return rv;
    
	//auto choiceLine = regex(`^[^=]+=(\w+)((\s+)|(\[=)(\[.+\])\])\s+(.*)$`, "gm");
	auto choiceLine = regex(`^\s*(=[^\[=\s]+)\S*\s*(.*)`, "gm");
	string shellCommand = format("dmd -%s=help",flag);
	auto results = executeShell(shellCommand);
	if(results.status)return rv;
	//sometimes it just acts like dmd --help and status is success so...
	if(results.output.startsWith("DMD")) return rv;
	
	auto matches = matchAll(results.output, choiceLine);

	foreach(match; matches)
	{
		string tmp = flag.stripRight()~ match[1].stripLeft();
	    writeln(tmp);
		rv ~= tmp;
		subBrief ~= match[2];
    }
	return rv;
}

enum ARG_TYPE : string
{
	NONE = "NONE",
	STRING = "STRING",
	NUMBER = "NUMBER",
	STR_ARRAY = "STR_ARRAY",
}
