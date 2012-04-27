#!/bin/bash

echo "Building  Dcomposer"
#cd src
dmd -cov -gc -wi -w symbols.d  dcomposer.d   project.d  log.d  dcore.d  config.d  debugger.d search.d ui.d docman.d document.d elements.d logui.d searchui.d projectui.d symbolview.d indent.d autopopups.d calltips.d scopelist.d symcompletion.d terminalui.d proview.d dirview.d historyview.d debugui.d messageui.d symassistui.d assistantui.d preferencesui.d  -I/usr/include/d -L-lgtkdsv -L-lgtkd -L-ldl -L-lvte -od../objfiles -of../dcomposer

yy=$?

cd ..
exit $yy
