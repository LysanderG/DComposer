rdmd utils/builddata.d;

dmd -gc -debug -I./src -Ideps/dson/ \
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
deps/dson/json.d \
-odobjdir -J./ \
-L-lvted-3 \
-L-lgtkdsv-3 \
-L-lgtkd-3 \
-defaultlib=libphobos2.so \
-L-ldl
