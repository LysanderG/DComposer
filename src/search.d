// search.d
// 
// Copyright 2012 Anthony Goins <anthony@LinuxGen11>
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
// MA 02110-1301, USA.


module search;

import std.algorithm;
import std.range;
import std.string;
import std.file;
import std.regex;
import std.stdio;

import dcore;

struct SEARCH_OPTIONS
{
    bool    UseRegex;
    bool    CaseInSensitive;
    bool    WholeWordOnly;
    bool    WordStart;
    bool    RecurseFolder;
}


struct SEARCH_RESULT
{
    string  DocName;
    int     LineNumber;
    string  LineText;

    ulong     StartOffset;
    ulong     EndOffset;

    this(string title, int line, string text, ulong start, ulong end)
    {
        DocName = title;
        LineNumber = line;
        LineText = text;
        StartOffset = start;
        EndOffset = end;
    }
}


SEARCH_RESULT[] FindInString(string HayStack, string Needle, string DocTitle, SEARCH_OPTIONS opts)
{
    SEARCH_RESULT[] Results;
    if(opts.CaseInSensitive)Needle = Needle.toLower();

    auto StackLines = HayStack.splitLines();
    
    void SearchLine(string lineText, int lineNo)
    {
        ulong MultiMatchAddToOffset = 0;
        string FullLineText = lineText;
        do
        {
            if(opts.CaseInSensitive)lineText = lineText.toLower();
            auto foundSplits = findSplit(lineText, Needle);
            if (foundSplits[1].empty) break;
            Results.length += 1;
            Results[$-1] = SEARCH_RESULT(DocTitle, lineNo+1, FullLineText, foundSplits[0].length + MultiMatchAddToOffset, (foundSplits[0] ~ foundSplits[1]).length + MultiMatchAddToOffset );
            MultiMatchAddToOffset = Results[$-1].EndOffset;
            lineText = foundSplits[2];
        }while (true);
    }

	void SearchLineRegex(string lineText, int lineNo)
	{
        ulong MultiMatchAddToOffset = 0;
		string FullLineText = lineText;

		do
		{
			if(opts.CaseInSensitive)lineText = lineText.toLower();

			auto foundMatch = match(lineText, regex(Needle));
			if(foundMatch.empty) break;
			Results.length +=1;
			Results[$-1] = SEARCH_RESULT(DocTitle, lineNo+1, FullLineText, foundMatch.pre.length + MultiMatchAddToOffset, (foundMatch.pre ~ foundMatch.hit).length + MultiMatchAddToOffset);

            MultiMatchAddToOffset = Results[$-1].EndOffset;
			lineText = foundMatch.post;
		}while(true);
	}

	void delegate (string, int) Search;
	
	if(opts.UseRegex)
	{
		Search = &SearchLineRegex;
		if(opts.WholeWordOnly) Needle = `\b` ~ Needle ~ `\b`;
	}
		
	else
	{
		Search = &SearchLine;
		if(opts.WholeWordOnly)
		{
			Search = &SearchLineRegex;
			Needle = `\b` ~ Needle ~ `\b`;
		}
	}


    foreach(int lineNumber, lineText; StackLines)Search(lineText, lineNumber);

    return Results;
}



SEARCH_RESULT[] FindInFile(string FileName, string Needle, SEARCH_OPTIONS Opts)
{
    scope(failure)
    {
		Log.Entry("Failed to search in file " ~ FileName);
		return null;
	}
    string HayStack = readText(FileName);


    return FindInString(HayStack, Needle, FileName, Opts);
}


SEARCH_RESULT[] FindInStrings(string[string] HayStacks, string Needle, SEARCH_OPTIONS Opts)
{
    SEARCH_RESULT[] Results;

    
    foreach (DocKey, HayStack; HayStacks)
    {
        Results ~= FindInString(HayStack, Needle, DocKey, Opts);
    }
    return Results;
}

SEARCH_RESULT[] FindInFiles(string[] Filenames, string Needle, SEARCH_OPTIONS Opts)
{
    string[string] HayStacks;
    
    foreach(file; Filenames)
    {
		writeln("searching ", file);
        HayStacks[file] = readText(file);
    }
    return FindInStrings(HayStacks, Needle, Opts);

}

