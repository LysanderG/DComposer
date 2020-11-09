module qore;

public import log;
public import config;
public import docman;
public import transmit;

void Engage(ref string[] args)
{    
    log.Engage(args);
    config.Engage(args);
    transmit.Engage(args);
    docman.Engage(args);
	Log.Entry("Engaged");    
}

void Mesh()
{
    log.Mesh();
    config.Mesh();
    transmit.Mesh();    
    docman.Mesh();
    Log.Entry("Mesh");
}

void Disengage()
{
    docman.Disengage();
    transmit.Disengage();
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
