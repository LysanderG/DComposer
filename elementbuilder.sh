cd elements/src;
export xfiles=`ls -1 *.d`;
echo $xfiles;
cd ../../ ;
for xes in $xfiles ;
	do echo $xes;
	 pwd;
	 ./utils/buildelement.d $xes;
done
cp elements/*.so ~/.config/dcomposer/elements;
