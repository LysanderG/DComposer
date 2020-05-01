module quore;

public import log;
public import config;

void Engage(string[] args)
{    
    log.Engage(args);
    config.Engage(args);
	Log.Entry("Engaged");    
}

void Mesh()
{
    log.Mesh();
    //config.Mesh();    
    Log.Entry("Mesh");
}

void Disengage()
{
    config.Disengage();
    log.Disengage();
    Log.Entry("Disengaged");
    
    
}
