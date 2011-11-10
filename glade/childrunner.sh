#!/bin/bash

$@
myrv=$?
echo $myrv
if [ "$myrv" = 0 ];then
	echo "Success :" $@
else
	echo "FAILED :" $@
	echo exit status  $myrv
fi

exit 0

