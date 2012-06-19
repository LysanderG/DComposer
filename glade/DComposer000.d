module silkmain;

int main(string[] args)
{
	writeln("This is madness!");
	writeln("This is DComposer!!!!!!");
	
	writeln ("There are/is ", args.length, " commandline elements.");
	writeln ("They are ...");
	foreach (a; args) writeln("%3i: %s", a);
	return 0;
}	