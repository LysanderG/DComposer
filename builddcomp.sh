#!/bin/bash

echo "Building  Dcomposer"
#cd src
dmd  -gc -debug symbols.d dcomposer.d  project.d log.d dcore.d config.d debugger.d search.d ui.d docman.d document.d elements.d logui.d searchui.d projectui.d symbolview.d indent.d docpop.d calltips.d scopelist.d symcompletion.d terminalui.d proview.d dirview.d historyview.d debugui.d messageui.d -I/usr/include/d -L-lgtkdsv -L-lgtkd -L-ldl -L-lvte -od../objfiles -of../dcomposer -version=DMD 

#/opt/gdc/bin/gdmd -gc -w symbols.d dcomposer.d  dproject.d log.d dcore.d config.d debugger.d ui.d docman.d document.d elements.d logui.d searchui.d projectdui.d symbolview.d indent.d docpop.d calltips.d scopelist.d symcompletion.d terminalui.d proview.d dirview.d historyview.d messageui.d -L-lgtkdsv -L-lgtkd -L-ldl -L-lvte -od../objfiles -of../dcomposer -version=GDMD -L-lgphobos2
yy=$?

cd ..
exit $yy
