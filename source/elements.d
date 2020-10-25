module elements;

void Engage(ref string[] args)
{
}

void Mesh()
{
}

void Disengage()
{
}

string GetCmdLineOptions()
{
	string rv;
	rv  ="\t-X	--disableElements\tDisable loading all elements for session.\n";
	rv ~="\t-x	--suppress=ELEMENT\tDisable specific ELEMENT for session.\n";
	return rv;
}
