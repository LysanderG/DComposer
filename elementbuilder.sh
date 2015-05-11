cd elements/src;

if [ "$#" -eq 0 ]; then
    export xfiles=`ls -1 *.d`;
else
    export xfiles=$@;
fi

echo $xfiles;
echo
cd ../../ ;
for xes in $xfiles ;
    do echo -n $xes;
     ./utils/buildelement.d $xes;
     echo "$? <<<<<<";
     echo
done
cp elements/*.so ~/.config/dcomposer/elements;
