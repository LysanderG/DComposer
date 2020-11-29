module qore;

public import log;
public import config;
public import docman;
public import transmit;
public import project;

void Engage(ref string[] args)
{    
    log.Engage(args);
    config.Engage(args);
    transmit.Engage(args);
    docman.Engage(args);
    project.Engage(args);
	Log.Entry("Engaged");    
}

void Mesh()
{
    log.Mesh();
    config.Mesh();
    transmit.Mesh();    
    docman.Mesh();
    project.Mesh();
    Log.Entry("Mesh");
}

void Disengage()
{
	project.Disengage();
    docman.Disengage();
    transmit.Disengage();
    config.Disengage();
    log.Disengage();
    Log.Entry("Disengaged");
}

void CoreSkipUI()
{
	import ui;
	ui.SkipUI();
}
/* qore stuff
log
config
docman
search
ddoc2Pango
textFilter
*/
