DCOMPOSER
===
A naive IDE for the D programming language.

#WHO
dcomposer copyright 2011-2012 Anthony Goins.
neontotem@gmail.com
That's me, a hobby programmer.  In fact this is not just my first D project but the first serious programming I' have done since learning pascal on a Radio Shack TRS-80.  Wow, times have changed.  So looking for a fresh start I found D and decided to not only learn it but in the process contribute a, hopefully, functional tool.

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
* Built under Linux and FreeBSD.

All the preceding features are still under development and can stand to be improved.

I can't say there is anything particularly special about dcomposer, but I am very happy that it has made it this far.  My desire is to make it a valuable asset to the D community. 

#WHERE
The [dcomposer repository](https://github.com/LysanderG/DComposer) is hosted on Github. (If you're reading this you probably already know this.)

#HOW

###Requirements
* dmd (2.059) or gdc's gdmd (any d compiler should build dcomposer.  But dcomposer only works with the dmd interface (for now).)
* gtkd, gtkdsv from GtkD
* libvte
* libutil, libdl(Linux only).  These should be present already.
* gnu make (only one tested, only one I'm slightly familiar with)
* (optional) webkit gtk 1.0.

###Building/Installing
To clone and build dcomposer from your terminal ...
```
git clone https://github.com/LysanderG/DComposer.git .
make
```
If you are brave (normally should be root for the next 2 )
```
make install
```
eventually followed by
```
make uninstall
```

###Running/Using dcomposer
Dcomposer is very much in its infancy.  The user interface is in many instances extremely unintuitive.  In some cases it is just dead wrong.  I am actively working on fixing the problems of which I am aware and discovering those that still elude me.
In other words you are on your own for now.


#WHY
DComposer is a fun challenge.  Originally I had no intention of creating an IDE.  I tried several IDE/editors in the beginning.  None of them were truly satisfying.  Many did not fully support D, others were far too complicated to set up and use (never sure if I installed one of them correctly).  Emacs and Vim just had horrific learning curves.  Geany was the IDE I settled for.  I contemplated making a D plug-in for Geany.  Realizing I would have to actually learn C, I gave up the plug-in idea.

So I went on a tangent and started DComposer.  It was never my intention to reinvent the low level components of an IDE (parsing, editing, compiling, debugging ...) but simply to pull existing tools into one application.  How hard could that be?

While working on DComposer I have learned that much of my problems with other programming tools (Geany and Vim mostly) have been the result of my own ignorance.  I have grown very comfortable with Geany (still need a cheat sheet for Vim).  Never the less I hope DComposer may evolve into a useful tool one day.

No one can say the world is crowded with Linux IDE's for the D programming language (not yet any way).
 

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
* Icons!! need icons!
* custom key bindings
* better project management 
* export project to makefile
* allow building source files with out creating a projects.
* ask to save modified files before closing main window
* faster tag creation/loading/parsing
* symbols for local variables (only global supported now)
* more command line options
* fix and improve search ui
* beautify assistantui doc text
* debugger! gdb and d == frustration! tried 2 approaches, 2 fails
* plug-ins. dmd supports shared libs now so...

And I will add ...
* snippets
* split windows
* manual
* support for more languages / compilers
* export to different build systems
* file templates
* env variables for embedded terminal, easier to work with command line tools
* code "prettify"
* vcs support
* auto-save/backup
* helper for building tags for libraries/packages
* a vim mode.  hot key turns to vim beep mode (must add lots of beeps for beginners and hide the way out!)
* way to put embedded terminal output into document editor
* scripting (lua, python, angel, squirrel, tcl, guile)
* convert hexadecimal, decimal, octal, binary
* okay enough plenty more left though.


