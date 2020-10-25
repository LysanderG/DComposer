module qore;

public import log;
public import config;
public import docman;

void Engage(ref string[] args)
{    
    log.Engage(args);
    config.Engage(args);
    docman.Engage(args);
	Log.Entry("Engaged");    
}

void Mesh()
{
    log.Mesh();
    config.Mesh();    
    docman.Mesh();
    Log.Entry("Mesh");
}

void Disengage()
{
    docman.Disengage();
    config.Disengage();
    log.Disengage();
    Log.Entry("Disengaged");
}
 
/* qore stuff
log
config
docman
search
ddoc2Pango
textFilter
*/
