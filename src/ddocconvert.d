module ddocconvert;

import std.string;
import std.stdio;
import std.array;
import std.algorithm.searching;
import std.algorithm;
import std.regex;
import std.utf;

import dcore;



string Ddoc2Pango(string Input)
{
    string rvText;
    
    
    Input = ProcessEmbeddedCode(Input);
    Input = ProcessSections(Input);
    rvText = ProcessMacros(Input);

    return rvText;
}




string ProcessSections(string inputText)
{
    string[string] Section;
    string key = "DDOC_SUMMARY";

    LoadMacros();


    foreach(ndx, line; splitLines(inputText, KeepTerminator.yes))
    {
        if(ndx == 0)line = StartSection(key, line);
        if((line.length == 0) && (ndx > 0) && (key == "DDOC_SUMMARY"))
        {
            key = "DDOC_DESCRIPTION";
            line = StartSection(key,line);
        }

        auto colonIndex = indexOf(line, ":");

        if(colonIndex >= 0)
        {
            auto possibleSection = line[0..colonIndex].strip().toUpper();
            switch(possibleSection)
            {

                case "AUTHORS"              :key = "DDOC_AUTHORS";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "SOURCE"               :key = "DDOC_SOURCE";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "BUGS"                 :key = "DDOC_BUGS";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "COPYRIGHT"            :key = "DDOC_COPYRIGHT";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "DATE"                 :key = "DDOC_DATE";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "DEPRECATED"           :key = "DDOC_DEPRECATED";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "EXAMPLE"              :
                case "EXAMPLES"             :key = "DDOC_EXAMPLES";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "SINCE"                :
                case "HISTORY"              :key = "DDOC_HISTORY";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "LICENSE"              :key = "DDOC_LICENSE";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "RETURN"               :
                case "RETURNS"              :key = "DDOC_RETURNS";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "SEE ALSO"             :key = "DDOC_SEE_ALSO";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "SEE_ALSO"             :key = "DDOC_SEE_ALSO";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "STANDARDS"            :key = "DDOC_STANDARDS";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "THROWS"               :key = "DDOC_THROWS";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "VERSION"              :key = "DDOC_VERSION";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "PARAMS"               :key = "DDOC_PARAMS";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
                case "MACROS"               :key = "MACROS";
                                             line = StartSection(key, line[colonIndex .. $]);
                                             break;
               default : break;
            }

        }

        Section[key] ~= line;// ~ "\n";
    }

    string rv;

    foreach(secKey; OrderedKeys)
    {
        if(secKey in Section)
        {
            if(secKey == "MACROS")
            {
                AddMacros(Section[secKey]);
                continue;
            }
            if(secKey == "DDOC_PARAMS") rv ~= FormatParams(Section[secKey]);
            else rv ~= Section[secKey] ~ ")\n";
        }
    }
    
    return rv;
}


string ProcessMacros(string Input)
{
    string rvText;
    string macroText;

    while(true)
    {
        auto macroSplit = Input.findSplit("$(");

        if(macroSplit[1].empty)
        {
            rvText ~= macroSplit[0];
            break;
        }
        macroText = macroSplit[2].toRightParen();

        rvText ~= macroSplit[0];

        auto tmpText = MacroReplace(macroText);
        rvText ~= ProcessMacros(tmpText);
        Input = macroSplit[2].fromRightParen();
    }
    return rvText;
}




string toRightParen(string Text)
{
    string rvStr;
    int Pctr;

    foreach(ch; Text)
    {
        if(ch == '(') Pctr++;
        if(ch == ')') Pctr--;
        if(Pctr < 0) return rvStr;
        rvStr ~= ch;
    }
    //error here unbalanced parens
    return " unbalanced parens ";
}

string fromRightParen(string Text)
{
    string rvStr;
    int Pctr;

    foreach(indx, ch; Text)
    {
        rvStr = Text[indx .. $];
        if(ch == '(') Pctr++;
        if(ch == ')')Pctr--;
        if(Pctr < 0)
        {
            if(rvStr.length > 0) rvStr=rvStr[1..$];
            return rvStr;
        }

    }
    return " unbalanced Parens ";
}

string MacroReplace(string Text)
{
    string macName;
    string Arguments;
    string[] Arg;
    string ArgPlus;
    string rvText;

    //get macro name
    foreach(indx, ch; Text)
    {
        if(ch.isSymbolCharacter) macName ~= ch;
        else break;
    }
    
    if (macName == Text) //no arguments like $(TITLE)
    {

        return GetMacro(macName);
    }
    Text = Text[macName.length+1.. $]; //$(D someSymbolName)
    
    //IF its d_code
    if(macName == "D_CODE")
    {
        Text = FormatDCodeLines(Text);
    }
    
    //get arguments ... arg zero
    Arguments = Text;

    Arg ~= Arguments;

    //1--9
    auto splits = Arguments.splitter(",");
    foreach (indx, substr; split(Arguments, ','))
    {
        Arg ~= substr; // goes past nine but ... it shouldn't crash
    }

    ArgPlus = Text.findSplitAfter(",")[1];


    string macText = GetMacro(macName);

    string rpltxt(Captures!(string) match)
    {
        switch(match.hit)
        {
            case "$0" : return Arguments;
            case "$1" : return Arg[1];
            case "$2" : return Arg[2];
            case "$3" : return Arg[3];
            case "$4" : return Arg[4];
            case "$5" : return Arg[5];
            case "$6" : return Arg[6];
            case "$7" : return Arg[7];
            case "$8" : return Arg[8];
            case "$9" : return Arg[9];
            case "$+" : return ArgPlus;
            default : return "";
        }
    }


    rvText = replaceAll!(rpltxt)(macText, regex(`\$[\d+]`));

    return rvText;

}

bool isSymbolCharacter(char Char)
{
    return "_0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".canFind(Char);
}

string GetMacro(string MacroName)
{
    MacroName = MacroName.toUpper();
    auto m = (MacroName in Macro);

    if(m is null) return "$0";
    return Macro[MacroName];
}


string FormatDCodeLines(string codeInput)
{
    string rv;
    ulong longestLine;

    foreach(line; codeInput.splitLines(KeepTerminator.yes))
    {
        if(std.utf.count(line) > longestLine)longestLine = std.utf.count(line);
    }
    foreach(line; codeInput.splitLines(KeepTerminator.no))
    {
        auto decodelen = std.xml.decode(line).length;
        auto diff = line.length - decodelen;
        rv ~= line.leftJustify(longestLine + diff) ~ '\n';

    }
    return rv;
}


/*
 * Of course this does not work correctly because of 
 * ddoc macro expansion and pango markup tags.
 * The visual length is rarely equal to the 'physical'
 * length of the strings (not to mention I'm really ignoring 
 * unicode stuff)
 * */
string FormatParams(string paramInput)
{
    string procInput;
    foreach(line; paramInput.splitLines())
    {
        if(line.startsWith("$(DDOC_PARAM"))continue;
        if(line.indexOf("=")>0) procInput ~= " |" ~ line;
        else procInput ~= line;
    }
    procInput ~= " |";
    procInput = procInput.tr("\n", " ");
    dwrite(procInput);
    
    string[string] Parameters;
    string Identifier;
    
    ulong pipeindex = 1;
    auto indx = procInput.indexOf("=");
    while(indx > 0)
    {
        Identifier = procInput[pipeindex+1..indx].strip();
        pipeindex = procInput.indexOf("|", indx);
        Parameters[Identifier] = procInput[indx + 1..pipeindex].strip();
        indx = procInput.indexOf("=", pipeindex);
    }
    foreach(p;Parameters)dwrite("->",p);
    
    int col1end   = 31; //30
    int sep       = 32; //1
    int col2start = 33;
    int col2end   = 93; //60
    int end       = 94; //1
    
    string output = "╔";
    foreach(i; 1..col1end) output ~= "═";
    output ~= "╦";
    foreach(i; col2start..col2end) output ~= "═";
    output ~= " \n";
    
    bool xguard;
    foreach(key, param; Parameters)
    {
        if(xguard)
        {
            output ~= "╠";
            foreach(i; 1..col1end) output ~= "═";
            output ~= "╬";
            foreach(i; col2start..col2end) output ~= "═";
            output ~= " \n";
        }
        xguard=true;
        
        string col1 = key.center(col1end - 1);
        string col2;
        ulong height;
        if(param.length >= (col2end - col2start))
        {
            col2 = param.wrap((col2end - col2start));
            height = col2.countchars("\n");
        }
        else
        {
            col2 = param.leftJustify((col2end - col2start));
            height = 1;
        }
        foreach(h; 0..height)
        {
            output ~= "║";
            if(height == 1) output ~= col1 ~ "║" ~ col2 ~ " \n";
            else
            {
                if(h == 0) output ~= col1 ;
                else output ~= " ".center(col1end - 1);
                output ~= "║";
                output ~= col2.splitLines()[h].leftJustify(col2end-col2start) ~ " \n";
            }
        }

    }
    
        output ~= "╚";
        foreach(i; 1..col1end) output ~= "═";
        output ~= "╩";
        foreach(i; col2start..col2end) output ~= "═";
        output ~= " \n";
    
    dwrite(output);
    return "$(DDOC_PARAMS " ~ output ~ ")\n";
}
            
        

string ProcessEmbeddedCode(string inputText)
{
    string rv;
    bool endParen;
    
    foreach(line; inputText.splitLines(KeepTerminator.yes))
    {
        if(line.stripLeft().startsWith("---"))
        {
            if(endParen)
            {
                line = ")\n";
                endParen = false;
            }
            else
            {
                line = "$(D_CODE \n";
                endParen = true;
            }
        }
        rv ~= line;
    }
    return rv;
}
        


string StartSection(string key, string line)
{

    string rv;
    if( (line.length == 1) && (line[0] == ':') ) line.length = 0;
    if( (line.length >  1) && (line[0] == ':') ) line = line[1..$];

    rv ~= "$(" ~ key ~ " " ~ line;
    return rv;
}


string[string] Macro;

void LoadMacros()
{
    Macro["TITLE"] = __MODULE__;
    Macro["D"] = "$(BLUE $0)";
    Macro["B"] = "<b>$0</b>";
    Macro["I"] = "<i>$0</i>";
    Macro["U"] = "<u>$0</u>";
    Macro["P"] = "$(BR)$0$(BR)";
    Macro["DL"] = "$0$(BR)";
    Macro["DT"] = "$0 :$(BR)";
    Macro["DD"] = "\t$(I $0)$(BR)";
    Macro["TABLE"] = "===============$(BR)$0$(BR)===============$(BR)";
    Macro["TR"] = `$0$(BR)`;
    Macro["TH"] = "<span background=\"#AAAAAA\">\t$(U $0)\t</span>";
    Macro["TD"] = "$0";
    Macro["OL"] = "$0$(BR)";
    Macro["UL"] = "$0$(BR)";
    Macro["LI"] = "\t* $0$(BR)";
    Macro["BIG"]= "<big>$0</big>";
    Macro["SMALL"] = "<small>$0</small>";
    Macro["BR"] = "\n";
    Macro["LINK"] = "$(BLUE $0)";
    Macro["LINK2"] = "$(BLUE $2)$(SMALL $(GRAY [$1]))";
    Macro["GRAY"] = `<span foreground="#777777">$0</span>`;
    Macro["BLUE"] = `<span foreground="blue">$0</span>`;
    Macro["RED"] = `<span foreground="red">$0</span>`;
    Macro["GREEN"] = `<span foreground="green">$0</span>`;
    Macro["BLACK"] = `<span foreground="black">$0</span>`;
    Macro["WHITE"] = `<span foreground="white">$0</span>`;

    //Macro["D_CODE"] = `$(BR)----$(BR)<span background="#777777">$0</span>$(BR)----$(BR)`;
    Macro["D_CODE"] = `$(BR)<span foreground="yellow" background="black" font="monospace">$0</span>$(BR)`;
    Macro["D_COMMENT"] = "$(GREEN $0)";
    Macro["D_STRING"] = "$(RED $0)";
    Macro["D_KEYWORD"] = "$(BLUE $0)";
    Macro["D_PSYMBOL"] = "$(U $0)";
    Macro["D_PARAM"] = "$(I $0)";

    Macro["DDOC"] = "$0";
    Macro["DDOC_COMMENT"] = "";
    Macro["DDOC_DECL"] = "$(DT $(BIG $0)";
    Macro["DDOC_DECL_DD"] = "$(DD $0)";
    Macro["DDOC_DITTO"] = "$(BR)$0";
    Macro["DDOC_SECTIONS"] = "$0";
    Macro["DDOC_SUMMARY"] = "$0$(BR)";
    Macro["DDOC_DESCRIPTION"] = "$0$(BR)";
    Macro["DDOC_AUTHORS"] = "$(B Authors:)$(BR)$0$(BR)";
    Macro["DDOC_SOURCE"] = "$(B Source:)$(BR)$0$(BR)";
    Macro["DDOC_BUGS"] = "$(RED BUGS:)$(BR)$0$(BR)";
    Macro["DDOC_COPYRIGHT"] = "$(B Copyright:)$(BR)$0$(BR)";
    Macro["DDOC_DATE"] = "$(B Date:)$(BR)$0$(BR)";
    Macro["DDOC_DEPRECATED"] = "$(B $(RED Deprecated:))$(BR)$0($BR)";
    //Macro["DDOC_EXAMPLES"] = "$(B Examples:)$(BR)$(D_CODE $0)$(BR)$(BR)";
    //Macro["DDOC_EXAMPLE"] = "$(B Examples:)$(BR)$(D_CODE $0)$(BR)$(BR)";
    Macro["DDOC_EXAMPLES"] = "$(B Examples:)$(BR)$0$(BR)";
    Macro["DDOC_EXAMPLE"] = "$(B Examples:)$(BR)$0$(BR)";
    Macro["DDOC_HISTORY"] = "$(B History:)$(BR)$0$(BR)";
    Macro["DDOC_LICENSE"] = "$(B License:)$(BR)$0$(BR)";
    Macro["DDOC_RETURNS"] = "$(B Returns:)$(BR)$0$(BR)";
    Macro["DDOC_SEE_ALSO"] = "$(B See Also:)$(BR)$0$(BR)";
    Macro["DDOC_HISTORY"] = "$(B History:)$(BR)$0$(BR)";
    Macro["DDOC_STANDARDS"] = "$(B Sandards:)$(BR)$0$(BR)";
    Macro["DDOC_THROWS"] = "$(B Throws:)$(BR)$0$(BR)";
    Macro["DDOC_VERSION"] = "$(B Version:)$(BR)$0$(BR)";
    Macro["DDOC_SECTION_H"] = "$(B $0)$(BR)$(BR)";
    Macro["DDOC_SECTION"] = "$0$(BR)$(BR)";
    Macro["DDOC_MEMBERS"] = "$(DL $0)";
    Macro["DDOC_MODULE_MEMBERS"] = "$(DDOC_MEMBERS $0)";
    Macro["DDOC_CLASS_MEMBERS"] = "$(DDOC_MEMBERS $0)";
    Macro["DDOC_STRUCT_MEMBERS"] = "$(DDOC_MEMBERS $0)";
    Macro["DDOC_ENUM_MEMBERS"] = "$(DDOC_MEMBERS $0)";
    Macro["DDOC_TEMPLATE_MEMBERS"] = "$(DDOC_MEMBERS $0)";
    Macro["DDOC_ENUM_BASETYPE"] = "$0";
    //Macro["DDOC_PARAMS"] = "$(B PARAMETERS:)$(BR)\n$(TABLE $0)$(BR)";
    Macro["DDOC_PARAMS"] = "$(B PARAMETERS:)$(BR)$0$(BR)";
    Macro["DDOC_PARAM_ROW"] = "$(TR $0)";
    Macro["DDOC_PARAM_ID"] = "$(TD $0)";
    Macro["DDOC_PARAM_DESC"] = "$(TD $0)";
    Macro["DDOC_MODULE_MEMBERS"] = "$(DDOC_MEMBERS $0)";
    Macro["DDOC_BLANKLINE"] = "$(BR)$(BR)";
    Macro["DDOC_ANCHOR"] = "";
    Macro["DDOC_PSYMBOL"] = "$(U $0)";
    Macro["DDOC_PSUPER_SYMBOL"] = "$(U $0)";
    Macro["DDOC_KEYWORD"] = "$(B $0)";
    Macro["DDOC_PARAM"] = "$(I $0)";
    Macro["ESCAPES"] = "/</&lt;//>/&gt;//&/&amp;/";

    Macro["BACKTICK"] = "`";
    Macro["DDOC_BACKQUOTED"] = "$(D_INLINECODE $0)";
    Macro["D_INLINECODE"] = "HI $(D_CODE $0)";

    //other crap
    Macro["LPAREN"] = "(";
    Macro["RPAREN"] = ")";
    Macro["DOLLAR"] = "$";
    Macro["DEPRECATED"] = "$0";
    Macro["TDNW"] = "$(TD $(U $0))$(BR)";
    Macro["LESS"] = "&lt;";
    Macro["GREATER"] = "&gt;";
    Macro["HREF"] = "$(LINK2 $0)";

}

void AddMacros(string MacroSection)
{
    foreach (line; MacroSection.splitLines())
    {
        auto result = findSplit(line, "=");
        if(result[1].length)
        {
            Macro[result[0].strip] = result[2].strip;
        }
    }
}

string[] OrderedKeys =
[

    "DDOC_SUMMARY",
    "DDOC_DEPRECATED",
    "DDOC_DESCRIPTION",
    "DDOC_HISTORY",
    "DDOC_PARAMS",
    "DDOC_RETURNS",
    "DDOC_THROWS",
    "DDOC_EXAMPLES",
    "DDOC_BUGS",
    "DDOC_VERSION",
    "DDOC_STANDARDS",
    "DDOC_SEE_ALSO",
    "DDOC_AUTHORS",
    "DDOC_DATE",
    "DDOC_LICENSE",
    "DDOC_COPYRIGHT",
    "DDOC_SOURCE",      //NOT A STANDARD SECTION, do not see anything about non standard sections in docs
    "MACROS",
    "ESCAPES"
];
