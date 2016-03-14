cd elements/src;

error_arg="No errors"

if [ "$#" -eq 0 ]; then
    export xfiles=`ls -1 *.d`;
else
    export xfiles=$@;
fi

echo $xfiles
echo
cd ../../
for xes in $xfiles ;
    do echo -n $xes ;
     ./utils/buildelement.d $xes ;
     rv="$?" ;
     if [ "$rv" -ne 0 ]; then if [ "$error_arg" = "No errors" ]; then error_arg="First Error in $xes"; fi; fi;
     echo "$rv <<<<<<";
     echo ;
done
cp elements/*.so ~/.config/dcomposer/elements;

echo $error_arg
