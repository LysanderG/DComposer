echo Building DCOMPOSER YAHOO!!!!
echo This build script attempts to build the dcomposer ide with the dmd compiler.
echo It depends on linking with a COMPATIBLE version of gtkd.
echo GtkD built with different compilers \(ldc,gdc\) or with a different version of 
echo dmd \(than what is being used now\) will most likely result in a flood of 
echo undefined symbol errors.
echo No problem :\)
echo Just rebuild GtkD with your current dmd compiler or change this script to meet
echo your needs.
echo
echo Oh, if this script can\'t find your GtkD just set the GTKD_PREFIX
echo \(if you used dub it would probably be ~/.dub/packages/gtk-d-x.x.x/gtk-d/\)
echo Good luck let the building begin!!
echo ...

#collect build variables
rdmd utils/builddata.d;
echo ...

# this build script assumes gtkd is installed at
# /usr/local/  thus -I/usr/local/include/d/gtkd-3/ -L/usr/local/lib/
# tried using pkg-config but some systems I tried did not set 
# the environment path to gtkd's default /usr/local/share/pkgconfig
GTKD_PREFIX="${GTKD_PREFIX:-/home/anthony/projects/GtkD/}"
GTKD_IMPORT_PATH="${GTKD_PREFIX}generated/"

dmd \
-of=bin/dcomposer \
-g \
-debug \
-I./include/dcomposer/ \
-I${GTKD_IMPORT_PATH}gtkd \
-I${GTKD_IMPORT_PATH}sourceview \
-I${GTKD_IMPORT_PATH}vte \
-L-LDL \
-defaultlib=libphobos2.so \
include/dcomposer/dcomposer.d \
include/dcomposer/dcore.d \
include/dcomposer/config.d \
include/dcomposer/log.d \
include/dcomposer/docman.d \
include/dcomposer/symbols.d \
include/dcomposer/document.d \
include/dcomposer/project.d \
include/dcomposer/search.d \
include/dcomposer/shellfilter.d \
include/dcomposer/ddocconvert.d \
include/dcomposer/debugger.d \
include/dcomposer/ui.d \
include/dcomposer/ui_search.d \
include/dcomposer/ui_completion.d \
include/dcomposer/ui_list.d \
include/dcomposer/ui_project.d \
include/dcomposer/ui_elementmanager.d \
include/dcomposer/ui_preferences.d \
include/dcomposer/ui_contextmenu.d \
include/dcomposer/ui_docbook.d \
include/dcomposer/elements.d \
include/dcomposer/json.d \
${GTKD_PREFIX}libgtkdsv-3.a \
${GTKD_PREFIX}libvted-3.a \
${GTKD_PREFIX}libgtkd-3.a \
-odobjdir -J./ 
