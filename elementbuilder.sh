SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo ${SRCDIR}
cd ${SRCDIR}
cd lib/dcomposer/elements/src;

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
    do echo -n  ;
     ../../utils/buildelement.d ${SRCDIR} ${GTKD_IMPORT} $xes ;
     rv="$?" ;
     if [ "$rv" -eq 200 ]; then
         echo "Be sure to set the GTKD_IMPORT when calling elementbuilder";
         echo "e.g. ";
         echo "GTKD_IMPORT=/usr/include/ ./elementbuilder my_element.d";
         exit 200;
     fi;
     if [ "$rv" -ne 0 ]; then if [ "$error_arg" = "No errors" ]; then error_arg="First Error in $xes"; fi; fi;
    printf "%-24s %2d\n" $xes $rv;
done

echo $error_arg
