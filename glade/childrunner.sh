#!/bin/bash

$@
myrv=$?

if [ "$myrv" = 0 ];then
	echo "SUCCESS :" $@
    echo "exit status :"$myrv
else
	echo "FAILED :" $@
	echo "exit status :"$myrv
fi

exit 0

