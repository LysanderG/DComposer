module completion_words;



import gsv.SourceCompletionWords;

import qore;
import transmit;
import document;


WORDS Words;

class WORDS
{
    SourceCompletionWords mWords;
    
    void Engage()
    {
        mWords = new SourceCompletionWords("words", null);
        Transmit.DocManEvent.connect(&WatchDocMan);
        Log.Entry("Engaged");
    }
    void Mesh()
    {
        Log.Entry("Meshed");
    }
    void Disengage()
    {
        Transmit.DocManEvent.disconnect(&WatchDocMan);
        Log.Entry("Disengaged");
    }
    
    void WatchDocMan(DOCMAN_EVENT managerEvent, string docKey)
    {
        auto tb = (cast(DOCUMENT)GetDoc(docKey)).getBuffer();
        
        if(managerEvent ==DOCMAN_EVENT.ADD)
        {
            mWords.register(tb);
            return;
        }
        if(managerEvent == DOCMAN_EVENT.REMOVE)
        {
            mWords.unregister(tb);
            return;
        }
    }
    
}
