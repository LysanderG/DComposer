#!/bin/bash

#cd src
dmd -gc symbols.d dcomposer.d  dproject.d log.d dcore.d config.d ui.d docman.d document.d elements.d logui.d searchui.d projectdui.d symbolview.d indent.d docpop.d calltips.d scopelist.d symcompletion.d terminalui.d proview.d -I/usr/include/d -L-lgtkdsv -L-lgtkd -L-ldl -L-lvte -od../objfiles -of../dcomposer
yy=$?

cd ..
exit $yy
