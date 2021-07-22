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
	auto jsonFlags = jsonObject();
	
	auto rxVersion = regex(`v(\d+\.\d+\.\d+)`);
	auto rxFlag = regex(`^\s*-+(?P<fullswitch>\S+)\s*(?P<brief>.*)`, "gm");
	
	
	auto dmdresults = executeShell("dmd -h");	
	if(dmdresults.status != 0) return dmdresults.status;
	
	auto matchVersion = matchFirst(dmdresults.output, rxVersion);
	string dmdVersion = matchVersion.front;

	
	auto allMatches = matchAll(dmdresults.output, rxFlag);
	
	File output = File("OUTPUT","w");
	foreach(m;allMatches)
	{
	    if(m["fullswitch"] == "help")continue;
	    if(m["fullswitch"] == "version")continue;
	    if(m["fullswitch"] == "man")continue;
	    if(m["fullswitch"] == "run")continue;
	    if(m["fullswitch"].canFind("?"))continue;
	    
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
	     
	    auto jItem = jsonObject();
	    string id;
	    string flag;
	    ARG_TYPE arg_type;
	    string brief;

	    switch(processedSwitch["args"])
	    {
	        case "":                arg_type = ARG_TYPE.SIMPLE;
	                                break;
	        case "<num>":
	        case "<nnn>":   
	        case "<level>":         arg_type = ARG_TYPE.NUMBER;
	                                break;
	        case "<filename>":
	        case "<directory>":
	        case "<driverflag>":
	        case "<name>":          arg_type = ARG_TYPE.STRING;
	                                break;
	        default:                if(m["fullswitch"].canFind("[="))
	                                    arg_type = ARG_TYPE.STRING;
	                                else if(processedSwitch["args"].canFind("|"))
	                                    arg_type = ARG_TYPE.CHOICE;
	                                else arg_type = ARG_TYPE.SIMPLE;	                                
	    }
	    if((arg_type == ARG_TYPE.CHOICE) && choices.length) arg_type = ARG_TYPE.HEADER;
	    
	    id = m["fullswitch"];
	    flag = "-" ~ processedSwitch["switch"];
	    brief = m["brief"];
	    
	    foreach(index, ch; choices)
	    {
	        auto jSubItem = jsonObject;
	        jSubItem["arg_type"] = ARG_TYPE.SIMPLE;
	        jSubItem["flag"] = "-" ~ ch;
	        jSubItem["brief"] = choiceBriefs[index];
	        jSubItem["id"]  = ch;
	        jsonFlags[ch] = jSubItem;
	    }
	    jItem["id"] = id;
	    jItem["arg_type"] = arg_type;
	    jItem["flag"] = flag;
	    jItem["brief"] = brief;
	
	    jsonFlags[id] = jItem;
	    
	   
	}        
    auto jsonVersion = jsonObject;
    jsonVersion["Version"] = dmdVersion;
    jsonFlags["dmdVersion"] = jsonVersion;

    flagFileName = "utils/dmd_flags_v_" ~ dmdVersion ~ ".json";
	writeJSON!4(jsonFlags, File(flagFileName, "w"));
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
	SIMPLE = "SIMPLE" ,  // NO ARGUMENT JUST BOOL FLAG (-c ... or -cov=ctfe  <-- not an argument just a long flag
	STRING = "STRING" ,  // a string --> name filename directory in <>
	NUMBER = "NUMBER" ,  // a number --> cov=85 
	CHOICE = "CHOICE",  // an array of choices
	HEADER = "HEADER",  // NOT usable, kind of a place holder with a brief ??? contains simple choices

}
