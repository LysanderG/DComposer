module search;

import std.regex;
import std.string;
import std.file;
import std.signals;
import std.stdio;
import std.path;

import dcore;


struct SEARCH_OPTIONS
{
    bool    Regex;
    bool    CaseSensitive;
    bool    StartsWord;
    bool    EndsWord;
    bool    RecurseDirectory;
}

struct ITEM
{
    string  DocFile;
    string  Text;
    int     Line;
    int     OffsetStart;
    int     OffsetEnd;

    this(string ItemFile, string ItemText, int ItemLine, int ItemStart, int ItemEnd)
    {
        DocFile = ItemFile;
        Text = ItemText;
        Line = ItemLine;
        OffsetStart = ItemStart;
        OffsetEnd = ItemEnd;
    }


}

enum SCOPE { DOC_CURRENT, DOC_OPEN, PROJ_SOURCE, PROJ_ALL, FOLDER}



ITEM[] FindInDoc(DOC_IF doc, Regex!char Needle)
{
    import std.xml;
    ITEM[] rv;
    auto HayStackLines = doc.GetText().splitLines();

    foreach(ulong line, string text; HayStackLines)
    {
        auto found = matchAll(text, Needle);
        foreach(find; found) rv ~= ITEM(doc.Name, find.pre ~  find.hit  ~ find.post, cast(int)line, cast(int)find.pre.length, cast(int)find.pre.length + cast(int)find.hit.length);
    }
    return rv;
}

ITEM[] FindInFile(string FileName, Regex!char Needle)
{
    ITEM[] rv;
    if(!FileName.exists)
    {
        Log.Entry("Can not search non existant file :" ~ FileName);
        return rv;
    }

    auto HayStackLines = readText(FileName).splitLines();
    foreach(ulong line, string text; HayStackLines)
    {
        auto found = matchAll(text, Needle);
        foreach(find; found) rv ~= ITEM(FileName, text, cast(int)line, cast(int)find.pre.length, cast(int)find.pre.length + cast(int)find.hit.length);
    }
    return rv;
}



ITEM[] Search( SCOPE Scope, string Needle, SEARCH_OPTIONS Opts)
{

    try
    {
        if(!Opts.Regex)Needle = Needle.Escape();
        if(Opts.StartsWord) Needle = `\b` ~ Needle;
        if(Opts.EndsWord) Needle = Needle ~ `\b`;

        string Flags = "";
        if(!Opts.CaseSensitive) Flags ~= "i";


        auto rgx = regex(Needle, Flags);


        ITEM[] rv;

        final switch(Scope) with (SCOPE)
        {
            case DOC_CURRENT :
            {
                if(DocMan.Current())rv = FindInDoc(DocMan.Current(), rgx);
                break;
            }
            case DOC_OPEN :
            {
                foreach(doc; DocMan.GetOpenDocs) rv ~= FindInDoc(doc, rgx);
                break;
            }
            case PROJ_ALL :
            {
                if(Project.Lists[LIST_NAMES.REL_FILES] != [""])
                foreach(item; Project.Lists[LIST_NAMES.SRC_FILES] ~ Project.Lists[LIST_NAMES.REL_FILES])
		{
			if(DocMan.IsOpen(item)) rv ~= FindInDoc(DocMan.GetDoc(item), rgx);
			else rv ~= FindInFile(item, rgx);
		}
                break;
            }

            case PROJ_SOURCE :
            {
                if(Project.Lists[LIST_NAMES.SRC_FILES] == [""])break;
                foreach(item; Project.Lists[LIST_NAMES.SRC_FILES]) 
		{
			if(DocMan.IsOpen(item)) rv ~= FindInDoc(DocMan.GetDoc(item), rgx);
			else rv ~= FindInFile(item, rgx);
		}
                break;
            }
            case FOLDER :
            {
                auto mode = SpanMode.shallow;
                if(Opts.RecurseDirectory) mode = SpanMode.breadth;

                string searchPath;
                auto currDoc = DocMan.Current;
                if(currDoc is null) searchPath = CurrentPath();
                else searchPath = currDoc.Name.dirName();

                foreach(string FileItem; dirEntries(searchPath, mode))
                {
                    scope(failure)continue;
                    if(DocMan.IsOpen(FileItem))rv ~= FindInDoc(DocMan.GetDoc(FileItem), rgx);
                    else rv ~= FindInFile(FileItem, rgx);
                }
                break;
            }
        }
        Found.emit(Needle, "hmmm", rv);
        return rv;
    }
    //catch (RegexException rgxX)
    catch(Exception allexceptions)
    {
        writeln(allexceptions);
        return [];
    }
}

string Escape(string OldNeedle)
{
    import std.array;
    string rv = OldNeedle;
    string specials = "[]-{}()*+?.,^$|#";

    rv = rv.replace(`\`, `\\`);
    foreach(specChar; specials) rv = rv.replace([specChar], ['\\'] ~specChar);

    return rv;

}

//class just to implement signals?? really?
class FOUND
{
    mixin Signal!(string, string, ITEM[]);
}

FOUND Found;

void Engage()
{
    Found = new FOUND;
    Log.Entry("Engaged");
}

void PostEngage()
{
    Log.Entry("PostEngaged");
}

void Disengage()
{
    Log.Entry("Disengaged");
}
