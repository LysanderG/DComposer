module ui_completion;

import dcore;
import ui;
import docman;
import document;


import gsv.SourceCompletion;
import gsv.SourceCompletionProviderIF;
import gsv.SourceCompletionProposalIF;





class UI_COMPLETION
{
    private:

    SourceCompletionProviderIF[string] mProviders;

    void WatchForNewDocuments(string EventName, DOC_IF Doc)
    {
        if ((EventName == "Create") || (EventName == "Open"))
        {
            auto srcDoc = cast(DOCUMENT) Doc;
            auto comp = srcDoc.getCompletion();
            foreach(provider; mProviders)
            {
                comp.addProvider(provider);
            }
        }
    }

    public:

    void Engage()
    {
        DocMan.connect(&WatchForNewDocuments);
        Log.Entry("Engaged");
    }

    void PostEngage()
    {
        Log.Entry("Post Engaged");
    }

    void Disengage()
    {
        Log.Entry("Disengaged");
    }

    void AddProvider(SourceCompletionProviderIF provider)
    {
        foreach(doc; DocMan.GetOpenDocs())
        {
            auto srcDoc = cast(DOCUMENT)doc;
            //auto comp = srcDoc.getCompletion();
            //comp.addProvider(provider);
            srcDoc.getCompletion().addProvider(provider);
        }
        mProviders[provider. gtkSourceCompletionProviderGetName]  = provider;
    }

    void RemoveProvider(string ID)
    {
        if(ID !in mProviders) return;
        foreach(doc; DocMan.GetOpenDocs())
        {
            auto srcDoc = cast(DOCUMENT)doc;
            auto comp = srcDoc.getCompletion();
        }
        mProviders.remove(ID);
    }

    void RemoveProvider(SourceCompletionProviderIF provider)
    {
        foreach(DOCUMENT doc; cast(DOCUMENT[])DocMan.GetOpenDocs())
        {
            auto comp = doc.getCompletion();
            comp.removeProvider(provider);
        }
        mProviders.remove(provider. gtkSourceCompletionProviderGetName);
    }
}
