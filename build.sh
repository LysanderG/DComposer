

#collect build variables
rdmd utils/builddata.d;

# this build script assumes gtkd is installed at
# /usr/local/  thus -I/usr/local/include/d/gtkd-3/ -L/usr/local/lib/
# tried using pkg-config but some systems I tried did not set 
# the environment path to gtkd's default /usr/local/share/pkgconfig
#GTKD_PREFIX="/usr/local/"
GTKD_PREFIX="/home/anthony/projects/gtkd-dmd/"
GTKD_IMPORT_PATH="${GTKD_PREFIX}generated/"
GTKD_LIB_PATH="${GTKD_PREFIX}"

dmd -g -debug -I./src  \
-I${GTKD_IMPORT_PATH}gtkd \
-I${GTKD_IMPORT_PATH}sourceview \
-I${GTKD_IMPORT_PATH}vte \
-L-L${GTKD_PREFIX} \
-L-ldl \
-defaultlib=libphobos2.so \
src/dcomposer.d \
src/dcore.d \
src/config.d \
src/log.d \
src/docman.d \
src/symbols.d \
src/document.d \
src/project.d \
src/search.d \
src/shellfilter.d \
src/ddocconvert.d \
src/debugger.d \
src/ui.d \
src/ui_search.d \
src/ui_completion.d \
src/ui_list.d \
src/ui_project.d \
src/ui_elementmanager.d \
src/ui_preferences.d \
src/ui_contextmenu.d \
src/ui_docbook.d \
src/elements.d \
src/json.d \
/home/anthony/projects/gtkd-dmd/libgtkdsv-3.a \
/home/anthony/projects/gtkd-dmd/libvted-3.a \
/home/anthony/projects/gtkd-dmd/libgtkd-3.a \
-odobjdir -J./ 
#if [ $? -eq 0 ]; then 
#    bash elementbuilder.sh
#fi
