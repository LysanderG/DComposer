#! /usr/bin/bash

origin=$(pwd)

if [[ $# -lt 3 ]]
then
	two="se"
else
	two=$2
fi

echo $two
echo $1
if [[ $two == *"s"* ]]; then
	echo SOURCES
	cd /home/anthony/projects/dcomposer/source
	grep --color=auto "$1" *.d 
	cd /home/anthony/projects/dcomposer/include/dcomposer/
	grep --color=auto "$1" *.d 
fi

if [[ $two == *"e"* ]]; then
	echo ELEMENTS
	cd /home/anthony/projects/dcomposer/lib/dcomposer/elements/src/
	grep --color=auto "$1" *.d
fi

cd $origin
