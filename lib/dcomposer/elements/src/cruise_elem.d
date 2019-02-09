module cruise_elem;

import std.uni;
import std.conv;
import std.format;
import std.algorithm;
import std.string;
import std.utf;
import std.typecons;
import std.signals; 
 


import gtk.Switch;

import dcore;
import ui;
import docman;
import elements;
import document;


extern (C) string GetClassName()
{
    return "cruise_elem.CRUISE_ELEM";
}


class CRUISE_ELEM : ELEMENT
{
    public:

    string Name(){return "Cruise element";}
    string Info(){return "Edit/browse \"cruise\" text from the keyboard akin to vim normal mode :)";}
    string Version(){return "00.01";}
    string License(){return "Unknown";}
    string CopyRight(){return "Anthony Goins © 2015";}
    string[] Authors(){return ["Anthony Goins <neontotem@gmail.com>"];}
    
    mixin Signal!(string) Snippet;


    void Engage()
    {
        //do something here to visually indicate that cruise mode is active
        // ie change highlight style or something
        
        
        LoadUI();
        LoadBindings();
        mRegisterKey = 0;
        
        
        mIndicatorLabel = new Label("hi");
        mIndicatorLabel.setMarkup(mIndicatorTextOFF);
        //mIndicatorFrame = new Frame(mIndicatorLabel, "");
        //AddStatusBox(mIndicatorFrame,false, false, 0);
        AddStatusBox(mIndicatorLabel,false, true, 0);

        mIndicatorLabel.showAll();
        
        

        DocMan.DocumentKeyDown.connect(&ProcessKeys);

        Log.Entry("Engaged");
    }

    void Disengage()
    {
        SaveBindings();
        
        RemoveExtraPage(uiRoot);
        uiRoot.destroy();
        
        DocMan.DocumentKeyDown.disconnect(&ProcessKeys);
        RemoveFromMenuBar(mActionMenuItem, mRootMenuNames[6]);
        RemoveAction("ActCruiseMode");
                
        //mIndicatorFrame.remove(mIndicatorLabel);
        RemoveStatusBox(mIndicatorLabel);
        //mIndicatorLabel.destroy();
        //mIndicatorFrame.destroy();
        Log.Entry("Disengaged");
    }

    void Configure()
    {
    }

    PREFERENCE_PAGE PreferencePage()
    {
        return null;
    }


    private:
//-------------------------------------------------------------------------------------------------------------

    bool                    mCruiseActive;
    bool                    mCatchLastInput;

    PRIME_COMMANDS[char]    mCommands;
    MOTIONS[char]           mMotions;
    string                  mInputString;
    string                  mLastCommand;
    
    string[][string]          mAliasKeys;

    TEXT_OBJECT[char]       mTextObjects;
    TEXT_OBJECT[char]        mSelObjects;

    bool                    mSettingRegisterKey;
    char                    mRegisterKey;
    string[char]            mRegisters;

    int                     mCount;
    string                  mCountString;

    SELECTION               mSelection;

    bool                    mReplacing;

    string[char]            mFilterCommands;

    MenuItem                mActionMenuItem;
    
    Box                     uiRoot;
    Switch                  uiSwitch;
    Entry                   uiCurrentCommand;
    Entry                   uiRepeatCount;
    Entry                   uiLastCommand;
    Entry                   uiRegister;
    TextView                uiRegisterText;
    TreeView                uiKeyTree;
    ListStore               uiKeyStore;
    
    Frame                   mIndicatorFrame;
    Label                   mIndicatorLabel;
    string                  mIndicatorTextOn = `Cruise Mode :<span color="red">ON </span>`;
    string                  mIndicatorTextOFF =`Cruise Mode :OFF`;

//-----------------------------------------------------------------------------------------------------------
    void ToggleCruiseMode(Action a)
    {
        auto y = cast(ToggleAction) a;
        mCruiseActive = y.getActive();
        if(mCruiseActive)
        {
            DocMan.SetBlockDocumentKeyPress();
            mCatchLastInput = true;
        }
        string statestring = "Cruise mode is "  ~ ( (mCruiseActive)? "on":"off");
        ResetCommand();
        //uiSwitch.setActive(mCruiseActive);
        mIndicatorLabel.setMarkup(mCruiseActive?mIndicatorTextOn:mIndicatorTextOFF);

        Log.Entry(statestring);
    }

    void LoadUI()
    {
        auto builder = new  Builder;
        
        builder.addFromFile(ElementPath(Config.GetValue("cruise", "glade_file", "resources/cruise.glade")));
        uiRoot = cast(Box)builder.getObject("box1");
        uiSwitch = cast(Switch)builder.getObject("switch1");
        uiCurrentCommand = cast(Entry)builder.getObject("entry4");
        uiRepeatCount = cast(Entry)builder.getObject("entry1");
        uiLastCommand = cast(Entry)builder.getObject("entry2");
        uiRegister = cast(Entry)builder.getObject("entry3");
        uiRegisterText = cast(TextView)builder.getObject("textview1");
        uiKeyTree = cast(TreeView)builder.getObject("treeview1");
        uiKeyStore = cast(ListStore)builder.getObject("liststore1");

        AddIcon("cruise_icon", ElementPath( Config.GetValue("cruise", "icon", "resources/dashboard.png")));
        AddToggleAction("ActCruiseMode","Cruise Mode", "Text cruising mode", "cruise_icon", "<Control>J",&ToggleCruiseMode);
        mActionMenuItem = AddToMenuBar("ActCruiseMode", mRootMenuNames[6], 0);
        
        uiSwitch.setRelatedAction(GetAction("ActCruiseMode"));
        
        
        
        AddExtraPage(uiRoot, "Cruise");
    }
    
    void UpdateUI()
    {
        
        uiSwitch.setActive(mCruiseActive);
        uiCurrentCommand.setText(" " ~ mInputString);
        uiRepeatCount.setText(" " ~ mCount.to!string);
        uiLastCommand.setText(" " ~ mLastCommand);
        uiRegister.setText(" " ~ mRegisterKey);
        if(mRegisterKey in mRegisters)
            uiRegisterText.getBuffer().setText(mRegisters[mRegisterKey]);
        else
            uiRegisterText.getBuffer().setText("[Register unset or invalid]");
    }

    void LoadBindings()
    {
        TEXT_OBJECT[string] tmpobjs;
        
        char key;
        string cmd, help;
        TreeIter ti;
        uiKeyStore.clear();
        
//prime        
        string[] defprimekeys = [
            "c COPY --> Copy selection or motion to current register",
            "x CUT --> Delete selection or motion, put in current register",
            "d DELETE --> Delete selection or motion",
            "D DELETE_LINE --> Delete current line",
            "s SELECT --> Select text from next input",
            "S SELECT_LOCK --> Select text from next inputs until unlocked",
            "\x1C SEL_SHRINK_LEFT --> Shrink selection from the left ",
            "\x1D SEL_SHRINK_RIGHT --> Shrink selection from the right",
            "\x1E SEL_SHRINK --> Shrink selection range",
            "\x1F SEL_EXPAND --> Expand selection range",
            "p PASTE --> Insert Current Register",
            "P PASTE_AFTER --> Insert Current Register after cursor",
            "i INSERT --> Exit Cruise mode",
            "I INSERT_NL --> Create a new line and return to insert mode",
            "\n NEWLINE --> Create a new line and stay in cruise mode",
            "r REPLACE --> Insert keyboard text until Return/Enter key is pressed",
            "> INDENT --> Indent line",
            "< UNINDENT --> Remove line indentation",
            "f FILTER --> Shell command to change text",
            "u UNDO --> undo last change",
            "U REDO --> redo last undo",
            "Y SCROLL_UP --> Scroll up (cursor does not move)",
            "y SCROLL_DOWN --> Scroll down (Cursor does not move)",
            "M SCROLL_CENTER --> Center cursor mid screen",
            ", REPEAT --> Issue last command (1 time only)",
            "R REVERT --> Undo all changes to text",
            "\t SNIPPET --> Emit a snippet trigger to snippet engine"
        ];
        
        auto primekeys = Config.GetArray("cruise", "primary_commands", defprimekeys);
        
        foreach (line; primekeys)
        {
            formattedRead(line,"%s %s --> %s", &key, &cmd, &help);
            mCommands[key] = cast(PRIME_COMMANDS)cmd;
            string strkey = [key];
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, strkey);
            uiKeyStore.setValue(ti, 1, cmd);
            uiKeyStore.setValue(ti, 2, "Command");
            uiKeyStore.setValue(ti, 3, help);
        }
//motion
        string[] defmotionkeys = [
            "h MOVE_LEFT --> Move Left",
            "j MOVE_DOWN --> Move Down",
            "k MOVE_UP --> Move Up",
            "l MOVE_RIGHT --> Move Right",
            "H MOVE_LINE_START --> Move Line Start / first non-white space",
            "J MOVE_PAGE_DOWN --> Page Down",
            "K MOVE_PAGE_UP --> Page Up",
            "L MOVE_LINE_END --> Move Line End",
            "T MOVE_BOF --> Move Beginning of file",
            "B MOVE_EOF --> Move End of file",
            "/ MOVE_CURRENT_NEXT --> Move to next appearance of word at cursor",
            "? MOVE_CURRENT_PREV --> Move to previous appearance of word at cursor",
            "o MOVE_OBJECT_NEXT --> Move to next object",
            "O MOVE_OBJECT_PREV --> Move to previous object",
            "g SELECT_OBJ_NEXT --> Select next Text Object",
            "G SELECT_OBJ_PREV --> Select previous Text Object",
            "m MATCH_BRACKET --> Move to matching bracket",
            "{ BLOCK_OUTER --> Move to \"outer\" scope",
            "} BLOCK_INNER --> Move to \"inner\" scope",
            "[ BLOCK_UP --> Move \"up\" scope",
            "] BLOCK_DOWN --> Move \"down\" scope",
            "q STRING_NEXT --> Move next quote boundary",
            "Q STRING_PREV --> Move previous quote boundary",
            "a DOC_NEXT --> Move next comment boundary",
            "A DOC_PREV --> Move previous comment boundary",
            "n MOVE_CHAR_NEXT --> Move to next character (argument)",
            "N MOVE_CHAR_PREV --> Move to previous character(argument)"
        ];
        
        auto motionkeys = Config.GetArray("cruise", "motion_commands", defmotionkeys);
        
        foreach(line; motionkeys)
        {
            formattedRead(line, "%s %s --> %s", &key, &cmd, &help);
            mMotions[key] = cast(MOTIONS)cmd;
            string strKey = [key];
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, strKey);
            uiKeyStore.setValue(ti, 1, cmd);
            uiKeyStore.setValue(ti, 2, "Motion");
            uiKeyStore.setValue(ti, 3, help);            
        }
//object
        string[] defobjectkeys = [
        //key object location regex 
        r"w OBJECT_WORD START (?<=^|[^_\p{L}\p{N}])([_\p{L}][_\p{L}\p{N}]*)#-->Word start",
        r"e OBJECT_WORD END (?<=^|[^_\p{L}\p{N}])([_\p{L}][_\p{L}\p{N}]*)#-->Word end",
        r"( OBJECT_LIST START (\(|\[)(?>[^()\[\]]|(?R))*(\)|\])#-->Array/Arguments start",
        r") OBJECT_LIST END (\(|\[)(?>[^()\[\]]|(?R))*(\)|\])#-->Array/Arguments end",
        r"i OBJECT_ITEM START (?<=[\[\(,])[^,\)\] ]+(?=[\)\],])#-->Element/Parameter start",
        r"I OBJECT_ITEM END (?<=[\[\(,])[^,\)\]]+(?=[\)\],])#-->Element/Parameter end",
        r"n OBJECT_INT START \b((0[Xx][0-9a-fA-F][0-9a-fA-F_]+)|(0[BbB][01][01_]+)|([0-9][0-9_]+[uU]?L?))#-->Integer start",
        r"N OBJECT_INT END \b((0[Xx][0-9a-fA-F][0-9a-fA-F_]+)|(0[BbB][01][01_]+)|([0-9][0-9_]+[uU]?L?))#-->Integer end",   
        r"f OBJECT_FLOAT START \b(([-+]?[0-9][0-9_]*\.[0-9_]+([eEPp][-+]?[0-9][0-9_]+)?[fF]?L?i?)|(0[xX][0-9a-fA-F][0-9a-fA-F_]+\.[0-9a-fA-F_]+[Pp][+-]?[0-9][0-9_]+[fFL]?))#-->Decimal start",
        r"F OBJECT_FLOAT END \b(([-+]?[0-9][0-9_]*\.[0-9_]+([eEPp][-+]?[0-9][0-9_]+)?[fF]?L?i?)|(0[xX][0-9a-fA-F][0-9a-fA-F_]+\.[0-9a-fA-F_]+[Pp][+-]?[0-9][0-9_]+[fFL]?))#-->Decimal end",
        r"c OBJECT_CAMEL_CASE START _?[\p{Ll}\p{Lu}][\p{Ll}\p{N}_]+#-->camelCase start",
        r"C OBJECT_CAMEL_CASE END _?[\p{Ll}\p{Lu}][\p{Ll}\p{N}_]+#-->camelCase end"
        ];
        
        auto objectkeys = Config.GetArray("cruise", "object_keys", defobjectkeys);

        foreach(line; objectkeys)
        {
            string object, location, regex;
            formattedRead(line, " %s %s %s %s#-->%s", &key, &object, &location, &regex, &help);
            mTextObjects[key] = TEXT_OBJECT(object, key, cast(TEXT_OBJECT_CURSOR)location, regex);
            tmpobjs[object] = mTextObjects[key];
            
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, "o|O" ~ key);
            uiKeyStore.setValue(ti, 1, object);
            uiKeyStore.setValue(ti, 2, "Text Object");
            uiKeyStore.setValue(ti, 3, help);
            
        }
//selection objects        
        string[] defobjSelKeys = [
            //key, obj start, obj end
            "w OBJECT_WORD--> Word",
            "p OBJECT_LIST--> List",
            "i OBJECT_ITEM--> List Item",
            "n OBJECT_INT--> Integer",
            "f OBJECT_FLOAT--> Float",
            "c OBJECT_CAMEL_CASE-->CamelCase"
        ];
        
        auto objSelKeys = Config.GetArray("cruise", "selection_keys", defobjSelKeys);
                
        foreach(line; objSelKeys)
        {
            string obj1, obj2;
            formattedRead(line, "%s %s--> %s", &key, &obj1, &help);
            mSelObjects[key] = tmpobjs[obj1];
            
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, "g|G" ~ key);
            uiKeyStore.setValue(ti, 1, obj1);
            uiKeyStore.setValue(ti, 2, "Selection Object");
            uiKeyStore.setValue(ti, 3, help);
 
        }

//filters
        string[] deffilterkeys = [
            "d:date-->Date",
            "s:sort-->Sort selection lines",
            "r:tac-->Reverse selection lines",
            //q"[a:sed -r ':L;s=\b([0-9^\.]+)([0-9]{3})\b=\1,\2=g;t L;s/,/_/g'-->Format numbers with underscores]"
        ];
        
        auto filterkeys = Config.GetArray("cruise", "filter_keys", deffilterkeys);
        
        foreach(line; filterkeys)
        {
            formattedRead(line, "%s:%s-->%s", &key, &cmd , &help);
            mFilterCommands[key] = cmd;
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, "f" ~ key);
            uiKeyStore.setValue(ti, 1, cmd);
            uiKeyStore.setValue(ti, 2, "Shell Command");
            uiKeyStore.setValue(ti, 3, help);

        }        
//alias        
        string[] defaliaskeys = [
            "w:ow-->Move to next word start",
            "W:Ow-->Move to previous word start",
            "e:oe-->Move to next word end",
            "E:Oe-->Move to previous word end",
            "gb:{|M|s|m-->Select outer block",
            "Gb:[|M|s|m-->Select \"previous\" block",
            "gl:L|s|H-->Select line",
            "Gl:H|s|L-->Select line"
        ];
        
        auto aliaskeys = Config.GetArray("cruise", "alias_keys", defaliaskeys);
        
        foreach(line; aliaskeys)
        {
            string keys, originalkeys;
            formattedRead(line, " %s:%s-->%s", &keys, &originalkeys, &help);
            mAliasKeys[keys] = originalkeys.split('|');
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, keys);
            uiKeyStore.setValue(ti, 1, originalkeys);
            uiKeyStore.setValue(ti, 2, "Alias Command");
            uiKeyStore.setValue(ti, 3, help);
        }

//extra stuff for ui
        uiKeyStore.append(ti);
        uiKeyStore.setValue(ti, 0, " ");
        uiKeyStore.setValue(ti, 1, "SPACE");
        uiKeyStore.setValue(ti, 2, "Command");
        uiKeyStore.setValue(ti, 3, "Resets command input, count and turns off selecting");
        
        uiKeyStore.append(ti);
        uiKeyStore.setValue(ti, 0, "0-9");
        uiKeyStore.setValue(ti, 1, "REPEAT_COUNT");
        uiKeyStore.setValue(ti, 2, "COMMAND");
        uiKeyStore.setValue(ti, 3, "Sets number of times to perform next command");
        
        uiKeyStore.append(ti);
        uiKeyStore.setValue(ti, 0, "'");
        uiKeyStore.setValue(ti, 1, "REGISTER");
        uiKeyStore.setValue(ti, 2, "Command");
        uiKeyStore.setValue(ti, 3, "Preps cruise so next input (a-z) sets current register");
        
        
    }
    
    void SaveBindings()
    {}

    void ProcessKeys(uint keyValue, uint modKeyFlag)
    {
        scope(exit)UpdateUI();
        
        //is cruise active (and also catch last input)
        if(mCruiseActive is false)
        {
            if(mCatchLastInput)
            {
                mCatchLastInput = false;
            }
            else
            {
                //DocMan.SetBlockDocumentKeyPress(false);
            }
            return;
        }
        DocMan.SetBlockDocumentKeyPress();

        //stuff we may need
        auto uniKey = cast(char)Keymap.keyvalToUnicode(keyValue);
        bool ctrlKey = cast(bool)modKeyFlag & GdkModifierType.CONTROL_MASK;
        bool shiftKey = modKeyFlag & GdkModifierType.SHIFT_MASK;

        if(mReplacing)
        {
            DoReplace(uniKey);
            return;
        }

        bool itsAControlKeyBail = uniKey.isControl();
                
        if(keyValue == 65362){uniKey = '\x1F';itsAControlKeyBail = false;}
        if(keyValue == 65364){uniKey = '\x1E';itsAControlKeyBail = false;}
        if(keyValue == 65363){uniKey = '\x1D';itsAControlKeyBail = false;}
        if(keyValue == 65361){uniKey = '\x1C';itsAControlKeyBail = false;}
        if(keyValue == GdkKeysyms.GDK_Return) 
        {
            itsAControlKeyBail = false;
            uniKey = '\n';
        }
        if(keyValue == GdkKeysyms.GDK_Tab)
        {
            itsAControlKeyBail = false;
        }
        
        if(itsAControlKeyBail)return;

        //we are setting the register key
        if(uniKey == '\'')
        {
            mSettingRegisterKey = true;
            return;
        }
        if(mSettingRegisterKey)
        {
            SetRegisterKey(uniKey);
            mSettingRegisterKey = false;
            return;
        }

        //space resets command ... obvious from the code?
        if(uniKey == ' ')
        {
            ResetCommand();
            return;
        }

        //we are setting the count (or number of times to perform next command)
        if(uniKey.isNumber())
        {
            scope(failure) mCount = 1;
            mCountString ~= uniKey;
            mCount = mCountString.to!int;
            if(mCount < 1) mCount = 1;
            return;
        }
        else
        {
            mCountString.length = 0;
        }

        //now process the key
        mInputString ~= uniKey;
        
        RunCommand();


    }

    bool SetRegisterKey(char newKey)
    {
        if("abcdefghijklmnopqrstuvwxyz".canFind(newKey))
        {
            mRegisterKey = newKey;
            return true;
        }

        if(newKey == ' ')
        {
            mRegisterKey = 0;
            return true;
        }
        return false;
    }

    bool SetRegister(string NewRegText)
    {
        if(mRegisterKey == '\0')
        {
            Clipboard.get(intern("CLIPBOARD", true)).setText(NewRegText, cast(int)NewRegText.length);
            return true;
        }

        if(!"abcdefghijklmnopqrstuvwxyz".canFind(mRegisterKey)) return false;
        mRegisters[mRegisterKey] = NewRegText;
        return true;
    }

    string GetRegister()
    {
        if(mRegisterKey == 0) return Clipboard.get(intern("CLIPBOARD", true)).waitForText();
        if(mRegisterKey !in mRegisters) mRegisters[mRegisterKey] = "";
        return mRegisters[mRegisterKey];

    }

    void ResetCommand()
    {
        mInputString.length = 0;
        mCount = 1;
        mCountString.length = 0;
        mSelection = SELECTION.OFF;
        mReplacing = false;
    }

    void SaveAsLastCommand(string curCmd)
    {
        if(curCmd[0] in mCommands)
            if(mCommands[curCmd[0]] == PRIME_COMMANDS.REPEAT) return;
        mLastCommand = curCmd;
    }


    void RunCommand()
    {
        assert(mInputString.length > 0);
        
        STATUS Status;
        
        if( mInputString[0] in mCommands)
        {
            final switch(mCommands[mInputString[0]]) with (PRIME_COMMANDS)
            {
                case COPY            :
                    Status = DoCopy(mInputString);
                    break;
                case CUT            :
                    Status = DoCopy(mInputString);
                    if(Status == STATUS.SUCCESS)
                        Status = DoDelete(mInputString);
                    break;
                case DELETE         :
                    Status = DoDelete(mInputString);
                    break;
                case DELETE_LINE    :
                    Status = DoDeleteLine();
                    break;
                case SELECT         :
                    mSelection = (mSelection == SELECTION.OFF) ? SELECTION.ON : SELECTION.OFF;
                    Status = STATUS.INCOMPLETE;
                    mInputString.length = 0;
                    break;
                case SELECT_LOCK    :
                    mSelection = SELECTION.LOCKED;
                    Status = STATUS.INCOMPLETE;
                    mInputString.length = 0;
                    break;
                case SEL_EXPAND     :
                    //CHEATING CASTING TO DOCUMENT
                    auto doc = cast(DOCUMENT)DocMan.Current();
                    auto buff = doc.getBuffer();
                    TextIter startTi, endTi;
                    buff.getSelectionBounds(startTi, endTi);
                    startTi.backwardChars(mCount);
                    endTi.forwardChars(mCount);
                    buff.selectRange(startTi, endTi);
                    break;
                case SEL_SHRINK     :
                    auto doc = cast(DOCUMENT)DocMan.Current();
                    auto buff = doc.getBuffer();
                    TextIter startTi, endTi;
                    buff.getSelectionBounds(startTi, endTi);
                    startTi.forwardChars(mCount);
                    if(startTi.compare(endTi) > 0 )startTi = endTi.copy();
                    endTi.backwardChars(mCount);
                    if(endTi.compare(startTi) < 0)endTi = startTi.copy();
                    buff.selectRange(startTi, endTi);
                    break;
                case SEL_SHRINK_LEFT:
                    auto doc = cast(DOCUMENT)DocMan.Current();
                    auto buff = doc.getBuffer();
                    TextIter startTi, endTi;
                    buff.getSelectionBounds(startTi, endTi);
                    startTi.forwardChars(mCount);
                    if(startTi.compare(endTi) > 0) startTi = endTi.copy();
                    buff.selectRange(startTi,endTi);
                    break;
                case SEL_SHRINK_RIGHT:
                    auto doc = cast(DOCUMENT)DocMan.Current();
                    auto buff = doc.getBuffer();
                    TextIter startTi, endTi;
                    buff.getSelectionBounds(startTi, endTi);
                    endTi.backwardChars(mCount);
                    if(endTi.compare(startTi) < 0) endTi = startTi.copy();
                    buff.selectRange(startTi, endTi);
                    break;
                case PASTE          :
                    Status = DoPaste();
                    break;
                case PASTE_AFTER    :
                    Status = DoPasteAfter();
                    break;
                case NEWLINE        :
                    DocMan.Current().MoveLineStart(1,false);
                    DocMan.Current().MoveLineStart(1,true);
                    auto whitespace = DocMan.Current().Selection();
                    DocMan.Current().MoveLineEnd(1, false);
                    string newlines;
                    foreach(i; 0..mCount)newlines ~= "\n";
                    DocMan.Current().InsertText(newlines ~ whitespace);
                    break;
                case INSERT_NL      :
                    DocMan.Current().MoveLineStart(1,false);
                    DocMan.Current().MoveLineStart(1,true);
                    auto whitespace = DocMan.Current().Selection();
                    DocMan.Current().MoveLineEnd(1, false);
                    string newlines;
                    foreach(i; 0..mCount)newlines ~= "\n";
                    DocMan.Current().InsertText(newlines ~ whitespace);
                    goto case;//pass through
                case INSERT         :
                    auto CruiseAction = cast(ToggleAction)GetAction("ActCruiseMode");
                    CruiseAction.setActive(false);
                    Status = STATUS.INCOMPLETE; // this is not right maybe just return from RunCommand?
                    break;
                case REPLACE        :
                    DoReplace(0);
                    Status = STATUS.SUCCESS;
                    break;
                case INDENT         :
                    DocMan.Current.IndentLines(mCount);
                    break;
                case UNINDENT       :
                    DocMan.Current.UnIndentLines(mCount);
                    break;
                case FILTER         :
                    Status = DoFilter();
                    break;
                case UNDO           :
                    Status = DoUndo();
                    break;
                case REDO           :
                    Status = DoRedo();
                    break;
                case REVERT         :
                    Status = DoRevert();
                    break;
                case REPEAT         :
                    Status = DoLastCommand();
                    break;
                case SCROLL_CENTER  :
                    Status = DoScrollCenter();
                    break;
                case SCROLL_UP      :
                    DocMan.Current().ScrollDown(mCount);
                    Status = STATUS.SUCCESS;
                    break;
                case SCROLL_DOWN    :
                    DocMan.Current().ScrollUp(mCount);
                    Status = STATUS.SUCCESS;
                    break;
                case SNIPPET        :
                    Status = DoEmitSnippetTrigger();
                    break;
            }
        }
        else
            Status = DoMotion(mInputString, (mSelection != SELECTION.OFF));
        
        if(Status == STATUS.FAILURE)Status = DoAlias(mInputString);

        final switch(Status)
        {
            case STATUS.SUCCESS :
                SaveAsLastCommand(mInputString);
                mInputString.length = 0;
                mCount = 1;
                if(mSelection == SELECTION.ON) mSelection = SELECTION.OFF;
                return;
            case STATUS.FAILURE :
                mInputString.length = 0;
                mCount =1;
                if(mSelection == SELECTION.ON) mSelection = SELECTION.OFF;
                return;
            case STATUS.INCOMPLETE :
                return;
        }

    }


    STATUS DoMotion(string MotionCommand, bool selection = false)
    {

        assert(MotionCommand.length > 0);
        if(MotionCommand[0] !in mMotions) return STATUS.FAILURE;
        auto doc = DocMan.Current();
        final switch(mMotions[MotionCommand[0]]) with (MOTIONS)
        {
            case LEFT           :
                doc.MoveLeft(mCount, selection);
                return STATUS.SUCCESS;
            case DOWN           :
                doc.MoveDown(mCount, selection);
                return STATUS.SUCCESS;
            case UP             :
                doc.MoveUp(mCount, selection);
                return STATUS.SUCCESS;
            case RIGHT          :
                doc.MoveRight(mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_LINE_START:
                doc.MoveLineStart(mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_LINE_END  :
                doc.MoveLineEnd(mCount, selection);
                return STATUS.SUCCESS;                
            case MOVE_PAGE_UP   :
                doc.MovePageUp(mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_PAGE_DOWN :
                doc.MovePageDown(mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_BOF       :
                doc.MoveStart(mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_EOF       :
                doc.MoveEnd(mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_CURRENT_NEXT :
                doc.MoveNextSymbol(mCount, selection);
                //doc.MoveNextWordStart(mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_CURRENT_PREV :
                doc.MovePrevSymbol(mCount, selection);
                return STATUS.SUCCESS;            
            case OBJECT_PREV    :
                if(MotionCommand.length < 2) return STATUS.INCOMPLETE;
                char objkey = MotionCommand[1];
                if(objkey !in mTextObjects)return STATUS.FAILURE;
                //doc.MoveObjectPrev(mTextObjects[objkey], mCount, selection);
                doc.MoveObjectPrev(mTextObjects[objkey], mTextObjects[objkey].mCursor, mCount, selection);
                return STATUS.SUCCESS;
            case OBJECT_NEXT    :
                if(MotionCommand.length < 2) return STATUS.INCOMPLETE;
                char objkey = MotionCommand[1];
                if(objkey !in mTextObjects)return STATUS.FAILURE;   
                doc.MoveObjectNext(mTextObjects[objkey],mTextObjects[objkey].mCursor, mCount, selection);
                return STATUS.SUCCESS;
            case SELECT_OBJ_NEXT    :
                if(MotionCommand.length < 2) return STATUS.INCOMPLETE;
                char sel_obj_key = MotionCommand[1];
                if(sel_obj_key !in mSelObjects)return STATUS.FAILURE;
                doc.MoveObjectNext(mSelObjects[sel_obj_key], TEXT_OBJECT_CURSOR.RANGE, mCount, false);
                return STATUS.SUCCESS;
            case SELECT_OBJ_PREV    :
                if(MotionCommand.length <2) return STATUS.INCOMPLETE;
                char sel_obj_key = MotionCommand[1];
                if(sel_obj_key !in mSelObjects)return STATUS.FAILURE;
                doc.MoveObjectPrev(mSelObjects[sel_obj_key],TEXT_OBJECT_CURSOR.RANGE, mCount, false);
                return STATUS.SUCCESS;
            case MATCH_BRACKET      :
                doc.MoveBracketMatch(selection);
                return STATUS.SUCCESS;
            case BLOCK_OUTER        :
                doc.MoveUpperScope(mCount, selection);
                return STATUS.SUCCESS;
            case BLOCK_INNER        :
                doc.MoveLowerScope(mCount, selection);
                return STATUS.SUCCESS;
            case BLOCK_UP           :
                doc.MovePrevScope(mCount, selection);
                return STATUS.SUCCESS;
            case BLOCK_DOWN         :
                doc.MoveNextScope(mCount, selection);
                return STATUS.SUCCESS;
            case STRING_NEXT        :
                doc.MoveNextStringBoundary(mCount, selection);
                return STATUS.SUCCESS;
            case STRING_PREV        :
                doc.MovePrevStringBoundary(mCount, selection);
                return STATUS.SUCCESS;
            case DOC_NEXT           :
                doc.MoveNextCommentBoundary(mCount, selection);
                return STATUS.SUCCESS;
            case DOC_PREV           :
                doc.MovePrevCommentBoundary(mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_CHAR_NEXT     :
                if(MotionCommand.length != 2) return STATUS.INCOMPLETE;
                doc.MoveNextCharArg(MotionCommand[1], mCount, selection);
                return STATUS.SUCCESS;
            case MOVE_CHAR_PREV     :
                if(MotionCommand.length != 2) return STATUS.INCOMPLETE;
                doc.MovePrevCharArg(MotionCommand[1], mCount, selection);
                return STATUS.SUCCESS;
        }

    }

    STATUS DoCopy(string CpyCmd)
    {
        auto doc = DocMan.Current();

        if(doc.Selection().length > 0)
        {
            SetRegister(doc.Selection());
            return STATUS.SUCCESS;
        }

        if(CpyCmd.length < 2) return STATUS.INCOMPLETE;
        auto motionStatus = DoMotion(CpyCmd[1..$], SELECTION.ON);
        if(motionStatus == STATUS.FAILURE) 
        {   
            mSelection = SELECTION.ON;
            motionStatus = DoAlias(CpyCmd[1..$]);
        }
        if(motionStatus == STATUS.SUCCESS)
        {
            SetRegister(doc.Selection());
        }
        return motionStatus;
    }

    STATUS DoDelete(string DelCmd)
    {
        auto doc = DocMan.Current();
        if(doc.Selection().length > 0)
        {
            doc.ReplaceSelection("");
            return STATUS.SUCCESS;
        }
        if(DelCmd.length < 2) return STATUS.INCOMPLETE;
        auto motionStatus = DoMotion(DelCmd[1..$], SELECTION.ON);
        if(motionStatus == STATUS.FAILURE) 
        {   
            mSelection = SELECTION.ON;
            motionStatus = DoAlias(DelCmd[1..$]);
        }
        if(motionStatus == STATUS.SUCCESS)
        {
            doc.ReplaceSelection("");
        }
        return motionStatus;
    }

    STATUS DoDeleteLine()
    {
        auto doc = DocMan.Current();
        doc.MoveLineStart(1, false);
        doc.MoveLineEnd(mCount, true);
        doc.MoveRight(1, true);
        doc.ReplaceSelection("");

        return STATUS.SUCCESS;
    }

    STATUS DoPaste()
    {
        auto pasteText = GetRegister();
        if(pasteText.length < 1) return STATUS.FAILURE;
        auto doc = DocMan.Current();
        doc.ReplaceSelection(pasteText);
        return STATUS.SUCCESS;
    }

    STATUS DoPasteAfter()
    {
        auto pasteText = GetRegister();
        if(pasteText.length < 1) return STATUS.FAILURE;
        auto doc = DocMan.Current();
        doc.ReplaceSelection(pasteText);
        auto charcount = cast(int)std.utf.count(pasteText);

        doc.MoveLeft(charcount, false);
        return STATUS.SUCCESS;
    }

    void DoReplace(char inputChar)
    {

        static int insStart;
        auto doc = DocMan.Current();

        if(mReplacing == false)
        {
            insStart = doc.Column();
            mReplacing = true;
            return;
        }

        if( (inputChar == '\r') || (inputChar == '\n'))
        {
            if(uiCompletion.GetState() != COMPLETION_STATUS.ACTIVE)
            {
                doc.ClearHiliteAllSearchResults();
                insStart = 0;
                mReplacing = false;
                return;
            }
            
            doc.HiliteAllSearchResults(doc.Line(),insStart, doc.Column());
            return;
        }
        if((inputChar == '\b'))
        {
            auto currColumn = doc.Column();
            if(currColumn <= insStart) return;
            doc.MoveLeft(1, true);
            doc.ReplaceSelection("");
        }
        else
        {
            if((inputChar == '\t') && (uiCompletion.GetState() != COMPLETION_STATUS.INERT)) return;
            if((inputChar != '\t') && (inputChar.isControl()))return;
            doc.ReplaceSelection([inputChar]);
        }
        
        doc.HiliteAllSearchResults(doc.Line(),insStart, doc.Column());

    }

    STATUS DoUndo()
    {
        foreach(ctr; 0..mCount)DocMan.Undo();
        return STATUS.SUCCESS;
    }
    STATUS DoRedo()
    {
        foreach(ctr; 0..mCount)DocMan.Redo();
        return STATUS.SUCCESS;
    }
    STATUS DoRevert()
    {
        DocMan.Revert();
        return STATUS.SUCCESS;
    }
        
    
    STATUS DoScrollCenter()
    {
        DocMan.Current().ScrollCenterCursor();
        return STATUS.SUCCESS;
    }

    STATUS DoFilter()
    {
        if(mInputString.length == 1) return STATUS.INCOMPLETE;

        if(mInputString[1] !in mFilterCommands) return STATUS.FAILURE;

        auto rv = Filter(DocMan.Current.Selection(), mFilterCommands[mInputString[1]]);
        DocMan.Current().ReplaceSelection(rv.chomp());
        return STATUS.SUCCESS;
    }
    
    STATUS DoEmitSnippetTrigger()
    {
        if(mInputString.length < 3) return STATUS.INCOMPLETE;
        if(mInputString[$-1] == '\t')
        {
            auto trigger = mInputString[1..$-1];
            
            mCruiseActive = false;

            string statestring = "Cruise mode is "  ~ ( (mCruiseActive)? "on":"off");

            mIndicatorLabel.setMarkup(mCruiseActive?mIndicatorTextOn:mIndicatorTextOFF);
            Log.Entry(statestring);
              
            DocMan.SnippetTrigger.emit(DocMan.Current(), trigger);
            return STATUS.SUCCESS;
        }
        return STATUS.INCOMPLETE;
    }
        



    STATUS DoLastCommand()
    {
        auto tmp = mInputString;
        mInputString = mLastCommand;
        RunCommand();
        mInputString = tmp;

        return STATUS.SUCCESS;
    }
    
    STATUS DoAlias(string cmdAlias)
    {
        string savedInput = mInputString;
        scope(exit)mInputString = savedInput;
        
        if(cmdAlias in mAliasKeys)
        {
            foreach(cmdStep; mAliasKeys[cmdAlias])
            {
                mInputString = cmdStep;
                RunCommand();
            }
            return STATUS.SUCCESS;
        }
        foreach(key; mAliasKeys.byKey())
        {
            if(key.startsWith(cmdAlias)) return STATUS.INCOMPLETE;
        }
        
        return STATUS.FAILURE;
    }
        
    
}




/*struct SEL_OBJECT
{
    TEXT_OBJECT Start;
    TEXT_OBJECT End;
}
*/

enum SELECTION
{
    OFF,
    ON,
    LOCKED
}

enum STATUS
{
    SUCCESS,
    FAILURE,
    INCOMPLETE
}

enum PRIME_COMMANDS :string
{
    CUT             = "CUT",
    COPY            = "COPY",
    DELETE          = "DELETE",
    DELETE_LINE     = "DELETE_LINE",
    SELECT          = "SELECT",
    SELECT_LOCK     = "SELECT_LOCK",
    SEL_SHRINK_LEFT = "SEL_SHRINK_LEFT",
    SEL_SHRINK_RIGHT= "SEL_SHRINK_RIGHT",
    SEL_SHRINK      = "SEL_SHRINK",
    SEL_EXPAND      = "SEL_EXPAND",
    PASTE           = "PASTE",
    PASTE_AFTER     = "PASTE_AFTER",
    INSERT          = "INSERT",
    INSERT_NL       = "INSERT_NL",
    NEWLINE         = "NEWLINE",
    INDENT          = "INDENT",
    UNINDENT        = "UNINDENT",
    REPLACE         = "REPLACE",
    FILTER          = "FILTER",
    UNDO            = "UNDO",
    REDO            = "REDO",
    REVERT          = "REVERT",
    REPEAT          = "REPEAT",
    SCROLL_CENTER   = "SCROLL_CENTER",
    SCROLL_UP       = "SCROLL_UP",
    SCROLL_DOWN     = "SCROLL_DOWN",
    SNIPPET         = "SNIPPET"
}

enum MOTIONS :string
{
    LEFT            = "MOVE_LEFT",
    DOWN            = "MOVE_DOWN",
    UP              = "MOVE_UP",
    RIGHT           = "MOVE_RIGHT",
    MOVE_LINE_START = "MOVE_LINE_START",
    MOVE_LINE_END   = "MOVE_LINE_END",
    MOVE_PAGE_DOWN  = "MOVE_PAGE_DOWN",
    MOVE_PAGE_UP    = "MOVE_PAGE_UP",
    MOVE_BOF        = "MOVE_BOF",
    MOVE_EOF        = "MOVE_EOF",
    MOVE_CURRENT_NEXT = "MOVE_CURRENT_NEXT",
    MOVE_CURRENT_PREV = "MOVE_CURRENT_PREV",
    MOVE_CHAR_NEXT  = "MOVE_CHAR_NEXT",
    MOVE_CHAR_PREV  = "MOVE_CHAR_PREV",
    OBJECT_PREV     = "MOVE_OBJECT_PREV",
    OBJECT_NEXT     = "MOVE_OBJECT_NEXT",
    SELECT_OBJ_NEXT = "SELECT_OBJ_NEXT",
    SELECT_OBJ_PREV = "SELECT_OBJ_PREV",
    MATCH_BRACKET   = "MATCH_BRACKET",
    BLOCK_OUTER     = "BLOCK_OUTER",
    BLOCK_INNER     = "BLOCK_INNER",
    BLOCK_UP        = "BLOCK_UP",
    BLOCK_DOWN      = "BLOCK_DOWN",
    STRING_NEXT     = "STRING_NEXT",
    STRING_PREV     = "STRING_PREV",
    DOC_NEXT        = "DOC_NEXT",
    DOC_PREV        = "DOC_PREV"
}
