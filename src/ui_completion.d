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
				dwrite("///",comp.addProvider(provider));
				dwrite(comp, "--", provider);

			}
			dwrite(mProviders);
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
		dwrite("add provider " ,provider.gtkSourceCompletionProviderGetName ());
		foreach(doc; DocMan.GetOpenDocs())
		{
			auto srcDoc = cast(DOCUMENT)doc;
			//auto comp = srcDoc.getCompletion();
			//comp.addProvider(provider);
			srcDoc.getCompletion().addProvider(provider);
		}
		mProviders[provider. gtkSourceCompletionProviderGetName]  = provider;
		dwrite(mProviders);
	}

	void RemoveProvider(string ID)
	{
		if(ID !in mProviders) return;
		foreach(doc; DocMan.GetOpenDocs())
		{
			auto srcDoc = cast(DOCUMENT)doc;
			auto comp = srcDoc.getCompletion();
			dwrite(comp.removeProvider(mProviders[ID]));
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
