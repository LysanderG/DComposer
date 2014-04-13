module createflagfile;

import std.stdio;
import std.process;
import std.string;
import std.uni;
import std.algorithm;

int main(string[] args)
{
	string CmdString;
	string Brief;
	bool HasArgs;
	bool AdjustComma;
	
	string FlagsOutFile;
	if (args.length > 1) FlagsOutFile = args[1];
	else FlagsOutFile = "flags.json";
	
	File x = File(FlagsOutFile, "w");
	string dmdoutput;
	{
		dmdoutput = shell("dmd --help");
		scope(failure)writeln("huh");
	}
	
	
	foreach(index,line; dmdoutput.splitLines)
	{
		line = line.stripLeft;
		if(index = 0)
        {
            
    		x.write("[");
		if(line.startsWith("-"))
		{

			auto indx = countUntil!(std.uni.isWhite)(line);
			CmdString = stripLeft(line[0.. indx]);
			Brief = stripLeft(line[indx..$]);
			
			auto checkstate = CheckState(CmdString);
			
			if(checkstate == 0) continue; //multiple arguments 
			if(checkstate == 1) HasArgs = true;
			if(checkstate == 2) HasArgs = false;
			
			
			
			
			if(AdjustComma) x.write(",\n");
			else x.write("\n");
			AdjustComma = true;
			x.write("{\n");
			x.write("\"brief\":\"" ~ Brief ~ "\",\n");
			x.write("\"cmdstring\":\"" ~ CmdString ~ "\",\n");
			if(HasArgs) x.write("\"hasargument\":true\n");
			else 		x.write("\"hasargument\":false\n");
			x.write("}");
			
			
		}
	}
	x.write("\n]\n");
	
	return 0;
}			
			


int CheckState(ref string Cmd)
{
	//0 = multi args 1 = single args 2 = no args
	
	writeln(Cmd);
	if(Cmd.length < 4) return 2; //no args

	if(Cmd.startsWith("-version=")) return 0; //skip, multi args
	if(Cmd.startsWith("-debug=")) return 0;

	if(Cmd.startsWith("-L")) return 0;
	if(Cmd.startsWith("-I") || Cmd.startsWith("-J")) return 0;
	
	
	if(Cmd.canFind("=")) //single arg
	{
		Cmd = Cmd[0..Cmd.countUntil!("a == b ")("=")];
		return 1;
	}
	
	if(Cmd.startsWith("-run")) return 1;
	
	auto tmp = Cmd.endsWith("filename" , "directory", "objdir");
	if (tmp > 0)
	{
		if(tmp == 1) Cmd = Cmd.chomp("filename");
		if(tmp == 2) Cmd = Cmd.chomp("directory");
		if(tmp == 3) Cmd = Cmd.chomp("objdir");
		return 1;
	}	
	
	writeln("Confirm ", Cmd);
	writeln("If ",Cmd," takes one argument enter command switch...");
	writeln("ie -Odobjdir you would enter \"-Od\"");
	writeln(`(for default `, Cmd[0..3], ` enter "-") :`);
	string response = readln();
	response = chomp(response);
	if(response == "-") 
	{
		Cmd = Cmd[0..3];
		return 1;
	}
	if(response.length <2) return 2;
	Cmd = response;
	return 1;
	
}

