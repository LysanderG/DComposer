module buildelement;

import std.format;
import std.path;
import std.process;
import std.stdio;


//usage:
//utils/buildelement element_name | element_name.d
int main(string[] args)
{
    if(args.length < 2) return 1;
    if(args.length > 3) return 2;
    
    string gtkImportPath;
    if(args.length == 3) gtkImportPath = args[2];
    else gtkImportPath = "/usr/local/include/d/gtkd-3/";
    
    string rel_file = buildPath ("./elements", setExtension(args[1], ".d"));
    string output_file = setExtension(rel_file, ".so");

    string cmdLine = format("dmd %s -I./source -g -fPIC -shared -of%s -I%s", rel_file, output_file, gtkImportPath);
    
    writeln(cmdLine);    
    auto result = executeShell(cmdLine);
    writeln(result.output);
    return result.status;    
       
}
