DCOMPOSER
===
A naive IDE for the D programming language.

#WHO
dcomposer copyright 2011-2012 Anthony Goins.
neontotem@gmail.com
That's me, a hobby programmer.
In fact this is not just my first D project but the first serious programming I' have done since learning pascal on a Radio Shack TRS-80.
Wow, times have changed.
So looking for a fresh start I found D and decided to not only learn it but in the process contribute a, hopefully, functional tool.

#WHAT
Originally I thought to create a D plug-in for Geany.  Then I realized that I'd have to actually learn C.  So I decided to let Geany be my model and code dcomposer completely in D.
So the stuff that is in dcomposer...
* gtk 2.0 GUI. Through GtkD.
* gtkSourceView for the editor. GtkD again.
* uses DMD -X option to get symbols
    * symbol completion.
    * call tips.
    * scope list.
    * symbol assist.  Shows ddoc comments for symbols.
* Project Management.
* Embedded terminal.
* Shell Filter.  Process text through shell commands.
* Split editor windows.
* Bookmarks.
* Extensible (kind of).
* Built under Linux and FreeBSD. (My wife wont let me play on her windows box.)

All the preceding features are still under development and can stand to be improved.

I can't say there is anything particularly special about dcomposer, but I am very happy that it has made it this far.  My desire is to make it a valuable asset to the D community.



#WHERE
The [dcomposer repository](https://github.com/LysanderG/DComposer) is hosted on Github.
(If you're reading this you probably already know this.)

#HOW

###Requirements
* dmd 2.060
* gtkd, gtkdsv from GtkD
* libvte
* libutil, libdl(Linux only).  These should be present already.
* (optional) webkit gtk 1.0.

###Building/Installing
To clone and build dcomposer from your terminal ...
```
git clone https://github.com/LysanderG/DComposer.git .
make
```
variables: release=_0_/1 debug=0/_1_ webkit=0/_1_

If you are brave (normally should be root for the next 2 )
```
make install
```
prefix defaults to '/usr/local/'

eventually followed by
```
make uninstall
```
note: Makefile assumes gnu make, so on some systems you might have to use gmake.


###Running/Using dcomposer
Dcomposer is very much in its infancy.
The user interface is in many instances extremely unintuitive.
In some cases it is just dead wrong.
I am actively working on fixing the problems of which I am aware and discovering those that still elude me.
In other words you are on your own for now.



#WHY
I am making DComposer as a challenge.
Originally I had no intention of creating an IDE.
I tried several IDE/editors in the beginning.
None of them were truly satisfying.
Many did not fully support D, others were far too complicated to set up and use (never sure if I installed one of them correctly).
Emacs and Vim just had horrific learning curves.
Geany was the IDE I settled for.
I contemplated making a D plug-in for Geany.
Realizing I would have to actually learn C, I gave up the plug-in idea.
So I went on a tangent and started DComposer.
It was never my intention to reinvent the low level components of an IDE (parsing, editing, compiling, debugging ...) but simply to pull existing tools into one application.
How hard could that be?


#WHO REALLY
DMD Compiler and Phobos standard library
* Walter Bright
* and others (http://dlang.org/acknowledgements.html)

"The D Programming Language" (The book)
* Andrei Alexandrescu

[GtkD](www.dsource.org/projects/gtkd)
* Frank Benoit
* Jake Day
* Jonas Kivi
* Alan Knowles
* Antonio Monteiro
* Sebastián E. Peyrott
* John Reimer
* Mike Wey
* hauptmech

Gtk(http://developer.gnome.org/gtk-faq/stable/x52.html)

GtkSourceView
* Paolo Maggi paolo@gnome.org
* Paolo Borelli pborelli@katamail.com
* Yevgen Muntyan muntyan@tamu.edu

* Gustavo Giráldez gustavo.giraldez@gmx.net
* Jeroen Zwartepoorte  jeroen@xs4all.nl
* Mikael Hermansson  mike.tielie@gmail.com
* Chris Phelps  chicane@reninet.com


#WHEN
At some time I'll fix (among many others) the following...
* Non standard menubar
* Consistent use of notebook tabs (dragging rearranging etc)
* ~~Icons!! need icons!~~
* custom key bindings
* better project management
* export project to makefile
* ~~allow building source files with out creating a project.~~
* ~~ask to save modified files before closing main window~~
* faster tag creation/loading/parsing
* symbols for local variables (only global supported now)
* create tags for incomplete (non-compiling) source files
* more command line options
* fix and improve search ui. (Update: making small steps)
* beautify assistantui doc text
* debugger! gdb and d == frustration! tried 2 approaches, 2 fails
* plug-ins. dmd supports shared libs now so...
* more user configurable options

And I will add ...
* snippets
* ~~split windows~~
* manual
* support for more languages / compilers
* export to different build systems (autotools, cmake, waf ...)
* file templates
* ~~env variables for embedded terminal, easier to work with command line tools~~ Shell Filter
* vcs support
* auto-save/backup
* helper script for building tags for libraries/packages
* helper script for keeping up with dmd interface changes
* scripting (lua, python, angel, squirrel, tcl, guile) curious about D with rdmd.
