module extractflags;

import std.algorithm;
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
	auto rxFlag = regex(`^([\s]*-)([^\[\s=<]*)[=]*([\S\[\<]*)\s+([^\n]*)`, "gm");
	
	auto dmdresults = executeShell("dmd -h");
	
	if(dmdresults.status != 0) return dmdresults.status;
	
	auto versionEndLine = indexOf(dmdresults.output, '\n');
	string versionLine = dmdresults.output[0..versionEndLine];
	writeln("hi ", versionEndLine, " _ ", versionLine, " ^ ");	
	auto vmatch = matchFirst(versionLine, rxVersion);
	writeln(vmatch);
	string dmdVersion = vmatch[1];
	auto jversion = jsonObject();
	jversion["dmdVersion"] = dmdVersion;
	jsonFlags ~= jversion;
	
	
	auto matches = matchAll(dmdresults.output, rxFlag);
	foreach(match; matches)
	{ 
		auto jitem = jsonObject();
		ARG_TYPE argType;
		string[] argChoices;
		
		jitem["switch"]= match[2];
		jitem["brief"] = match[4];
		
		
		ProcessArgs(match[3], argType, argChoices);
		jitem["argType"] = argType;
		jitem["choices"] = jsonArray();
		foreach(achoice; argChoices)jitem["choices"] ~= achoice;
		
		jsonFlags ~= jitem;
		if(argType != ARG_TYPE.NONE) writefln("switch [%s] %s [%s]", match[2],match[3], match[4]);
		//writefln("switch %s  :  %s ::%s",match[2], match[3], match[4]);
    }
	
	flagFileName = "utils/dmd_flags_v_" ~ dmdVersion ~ ".json";
	writeJSON!4(jsonFlags, File(flagFileName, "w"));
	return 0;
}


void ProcessArgs(string argInput, out ARG_TYPE type, out string[] choices)
{
		if(argInput.length == 0)
		{
			type = ARG_TYPE.NONE;
			return;
		}
		if((argInput == "<num>") || (argInput == "<nnn>") || (argInput == "<level>"))
		{
			type = ARG_TYPE.NUMBER;
			return;
        }
        if(argInput[0] != '[') 
        {
	        type = ARG_TYPE.STRING;
	        return;
        }
        
        type = ARG_TYPE.STR_ARRAY;
        long endPoint = argInput.countUntil("]");
        if(endPoint == -1) endPoint = argInput.length;
        argInput = argInput[1..endPoint-1];
        choices = argInput.split('|');
        
}

enum ARG_TYPE : string
{
	NONE = "NONE",
	STRING = "STRING",
	NUMBER = "NUMBER",
	STR_ARRAY = "STR_ARRAY",
}
