#!/bin/bash

echo "Building  Dcomposer"
#cd src
#dmd -gc  -debug -w symbols.d  dcomposer.d   project.d  log.d  dcore.d  config.d  debugger.d debugger2.d search.d ui.d docman.d document.d elements.d logui.d searchui.d projectui.d symbolview.d indent.d autopopups.d calltips.d scopelist.d symcompletion.d terminalui.d proview.d dirview.d historyview.d debugui.d messageui.d symassistui.d assistantui.d preferencesui.d debuggerui.d  -I/usr/include/d -L-lgtkdsv -L-lgtkd -L-ldl -L-lvte -L-lutil -od../objfiles -of../dcomposer
 dmd  -debug -J.. -D -Dd../docs -gc   -w symbols.d  dcomposer.d   project.d  log.d  dcore.d  config.d  search.d ui.d docman.d document.d elements.d logui.d searchui.d projectui.d symbolview.d indent.d autopopups.d calltips.d scopelist.d symcompletion.d terminalui.d proview.d dirview.d historyview.d  messageui.d symassistui.d assistantui.d preferencesui.d   -I/usr/include/d -L-lgtkdsv -L-lgtkd -L-ldl -L-lvte -L-lutil -od../objfiles -of../dcomposer

yy=$?

cd ..
exit $yy
