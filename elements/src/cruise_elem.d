module cruise_elem;

import std.uni;
import std.conv;
import std.format;
import std.algorithm;
import std.string;

import gtk.Switch;

import dcore;
import ui;
import docman;
import elements;


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


    void Engage()
    {
        //do something here to visually indicate that cruise mode is active
        // ie change highlight style or something
        
        
        LoadUI();
        LoadBindings();
        mRegisterKey = 0;

        DocMan.DocumentKeyDown.connect(&ProcessKeys);


        AddToggleAction("ActCruiseMode","Cruise Mode", "Text cruising mode", "", "<Control>J",&ToggleCruiseMode);
        mActionMenuItem = AddToMenuBar("ActCruiseMode", mRootMenuNames[6], 0);

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
    SEL_OBJECT[char]        mSelObjects;

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
        dwrite("block=",mCruiseActive," catchlast=",mCatchLastInput);
        string statestring = "Cruise mode is "  ~ ( (mCruiseActive)? "on":"off");
        ResetCommand();
        //uiSwitch.setActive(mCruiseActive);

        Log.Entry(statestring);
    }

    void LoadUI()
    {
        auto builder = new  Builder;
        
        builder.addFromFile(SystemPath(Config.GetValue("cruise", "glade_file", "elements/resources/cruise.glade")));
        uiRoot = cast(Box)builder.getObject("box1");
        uiSwitch = cast(Switch)builder.getObject("switch1");
        uiCurrentCommand = cast(Entry)builder.getObject("entry4");
        uiRepeatCount = cast(Entry)builder.getObject("entry1");
        uiLastCommand = cast(Entry)builder.getObject("entry2");
        uiRegister = cast(Entry)builder.getObject("entry3");
        uiRegisterText = cast(TextView)builder.getObject("textview1");
        uiKeyTree = cast(TreeView)builder.getObject("treeview1");
        uiKeyStore = cast(ListStore)builder.getObject("liststore1");
        
        
        AddExtraPage(uiRoot, "Cruise");
    }
    
    void UpdateUI()
    {
        uiSwitch.setActive(mCruiseActive);
        uiCurrentCommand.setText(mInputString);
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
            "p PASTE --> Insert Current Register",
            "P PASTE_AFTER --> Insert Current Register after cursor",
            "i INSERT --> Exit Cruise mode",
            "I INSERT_NL --> Create a new line and return to insert mode",
            "r REPLACE --> Insert keyboard text until Return/Enter key is pressed",
            "f FILTER --> Shell command to change text",
            "u UNDO --> undo last change",
            "U REDO --> redo last undo",
            "Y SCROLL_UP --> Scroll up (cursor does not move)",
            "y SCROLL_DOWN --> Scroll down (Cursor does not move)",
            "M SCROLL_CENTER --> Center cursor mid screen",
            ", REPEAT --> Issue last command (1 time only)",
            "R REVERT --> Undo all changes to text"
        ];
        
        auto primekeys = Config.GetArray("cruise", "primary_commands", defprimekeys);
        
        foreach (line; primekeys)
        {
            formattedRead(line,"%s %s --> %s", &key, &cmd, &help);
            mCommands[key] = cast(PRIME_COMMANDS)cmd;
            
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, [key]);
            uiKeyStore.setValue(ti, 1, cmd);
            uiKeyStore.setValue(ti, 2, "Command");
            uiKeyStore.setValue(ti, 3, help);
        }
        dwrite("past prime");

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
            "A DOC_PREV --> Move previous comment boundary"
        ];
        
        auto motionkeys = Config.GetArray("cruise", "motion_commands", defmotionkeys);
        
        foreach(line; motionkeys)
        {
            formattedRead(line, "%s %s --> %s", &key, &cmd, &help);
            mMotions[key] = cast(MOTIONS)cmd;
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, [key]);
            uiKeyStore.setValue(ti, 1, cmd);
            uiKeyStore.setValue(ti, 2, "Motion");
            uiKeyStore.setValue(ti, 3, help);            
        }
        dwrite("past motions");

//object
        string[] defobjectkeys = [
            //key, object BEG start END end
            r"w OBJECT_WORD_START (?<=[^\p{L}_])([\p{L}_])-->Word start object",
            //r"e OBJECT_WORD_END (?<=[\p{L}_\d])[\n\p{Zs}\p{P}\p{Zl}\p{S}]",
            r"e OBJECT_WORD_END [^_\p{L}\p{N}]*-->Word end object",
            //`; OBJECT_STATEMENT_END (^|[;{}:])[^{};:]*`
            //r"s OBJECT_STATEMENT_START (^|[;{}:])[^{};:]*",
            r"s OBJECT_STATEMENT_START (?!\s)([^;\}\{]*)\s*-->Statement start object",
            r"; OBJECT_STATEMENT_END ((((?<=[;}])|(?<=\)\n))\n*[\s ]*)|(\n[\s]*{))-->Statement end object",
            r"( OBJECT_PARAMETER_START (?<!foreach)(?<!while)(\(|\[)-->List start  object",
            r") OBJECT_PARAMETER_END \)-->List end object",
            r"I OBJECT_ITEM_START (?<=[\(\[,])[^\)\],]*-->List Item start",
            r"i OBJECT_ITEM_END (?<=[^\(\[])[,\]\)]-->List Item start",
            r"f OBJECT_FUNCTION_START ((?<=[^\p{L}_\{N}])[\p{L}_][\p{L}_\p{N}]*)(?<!else|return)[\s]+[\p{L}_][\p{L}_\p{N}]*[\s]*\(-->Function"
            //r", doc.MoveNextParameterStart(mCount, selection) --> Next Item (??)"
        ];
        
        auto objectkeys = Config.GetArray("cruise", "object_keys", defobjectkeys);

        foreach(line; objectkeys)
        {
            string object, regex;
            formattedRead(line, " %s %s %s-->%s", &key, &object, &regex, &help);
            mTextObjects[key] = TEXT_OBJECT(object, key, regex);
            tmpobjs[object] = mTextObjects[key];
            
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, "o|O" ~ key);
            uiKeyStore.setValue(ti, 1, object);
            uiKeyStore.setValue(ti, 2, "Text Object");
            uiKeyStore.setValue(ti, 3, help);
            
        }
        dwrite("past objects");

//selection objects        
        string[] defobjSelKeys = [
            //key, obj start, obj end
            "w OBJECT_WORD_START OBJECT_WORD_END --> Word",
            "s OBJECT_STATEMENT_START OBJECT_STATEMENT_END --> Statement",
            "p OBJECT_PARAMETER_START OBJECT_PARAMETER_END --> List",
            "i OBJECT_ITEM_START OBJECT_ITEM_END --> List Item"
        ];
        
        auto objSelKeys = Config.GetArray("cruise", "selection_keys", defobjSelKeys);
                
        foreach(line; objSelKeys)
        {
            string obj1, obj2;
            formattedRead(line, "%s %s %s --> %s", &key, &obj1, &obj2, &help);
            mSelObjects[key] = SEL_OBJECT(tmpobjs[obj1], tmpobjs[obj2]);
            
            uiKeyStore.append(ti);
            uiKeyStore.setValue(ti, 0, "g|G" ~ key);
            uiKeyStore.setValue(ti, 1, obj1 ~ " " ~ obj2);
            uiKeyStore.setValue(ti, 2, "Selection Object");
            uiKeyStore.setValue(ti, 3, help);
 
        }
        dwrite("past objsel");

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
        dwrite("past filter");
        
//alias        
        string[] defaliaskeys = [
            "w:ow-->Move to next word start",
            "W:Ow-->Move to previous word start",
            "e:oe-->Move to next word end",
            "E:Oe-->Move to previous word end",
            "gb:{|M|s|m-->Select outer block",
            "zb:[|M|s|m-->Select \"previous\" block"
        ];
        
        auto aliaskeys = Config.GetArray("cruise", "alias_keys", defaliaskeys);
        
        foreach(line; aliaskeys)
        {
            dwrite(line);
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
        dwrite(cast(uint)uniKey, "<<<<< ",keyValue);
        bool ctrlKey = cast(bool)modKeyFlag & GdkModifierType.CONTROL_MASK;
        bool shiftKey = modKeyFlag & GdkModifierType.SHIFT_MASK;

        if(mReplacing)
        {
            DoReplace(uniKey);
            return;
        }


        if(uniKey.isControl())return;

        //space resets command ... obvious from the code?
        if(uniKey == ' ')
        {
            ResetCommand();
            return;
        }

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

        //dwrite(">",mInputString, ": x",mCount,"(",mCountString,")","/",mSelection );
        RunCommand();
        //dwrite("<",mInputString, ": x",mCount,"(",mCountString,")","/",mSelection );


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
        //dwrite("'",curCmd,"'");
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
                case PASTE          :
                    Status = DoPaste();
                    break;
                case PASTE_AFTER    :
                    Status = DoPasteAfter();
                    break;
                case INSERT_NL      :
                    DocMan.Current().MoveLineStart(1,false);
                    DocMan.Current().MoveLineStart(1,true);
                    auto whitespace = DocMan.Current().Selection();
                    DocMan.Current().MoveLineEnd(1, false);
                    DocMan.Current().InsertText("\n" ~ whitespace);
                    //pass through
                case INSERT         :
                    auto CruiseAction = cast(ToggleAction)GetAction("ActCruiseMode");
                    CruiseAction.setActive(false);
                    Status = STATUS.INCOMPLETE; // this is not right maybe just return from RunCommand?
                    break;
                case REPLACE        :
                    DoReplace(0);
                    Status = STATUS.SUCCESS;
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
            }
        }
        else
            Status = DoMotion(mInputString, (mSelection != SELECTION.OFF));


        final switch(Status)
        {
            case STATUS.SUCCESS :
                SaveAsLastCommand(mInputString);
                mInputString.length = 0;
                mCount = 1;
                if(mSelection == SELECTION.ON) mSelection = SELECTION.OFF;
                return;
            case STATUS.FAILURE :
                if(mInputString in mAliasKeys)
                {
                    auto shortcut = mInputString;
                    foreach(cmdstep; mAliasKeys[shortcut])
                    {
                        mInputString = cmdstep;
                        RunCommand();
                    }
                    mLastCommand = shortcut; //not the plan... should be in SaveLastCommand
                }
                else
                {
                    if(mInputString.length < 2) return; //??incomplete try with another keystroke added
                }
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
        //scope(exit) if(mSelection == SELECTION.ON) mSelection = SELECTION.OFF;

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
                return STATUS.SUCCESS;
            case MOVE_CURRENT_PREV :
                doc.MovePrevSymbol(mCount, selection);
                return STATUS.SUCCESS;            
            case OBJECT_PREV    :
                //dwrite(MotionCommand);
                if(MotionCommand.length < 2) return STATUS.INCOMPLETE;
                //dwrite("?");
                char objkey = MotionCommand[1];
                if(objkey !in mTextObjects)return STATUS.FAILURE;
                doc.MoveObjectPrev(mTextObjects[objkey], mCount, selection);
                return STATUS.SUCCESS;
            case OBJECT_NEXT    :
                //dwrite(MotionCommand);
                if(MotionCommand.length < 2) return STATUS.INCOMPLETE;
                char objkey = MotionCommand[1];
                if(objkey !in mTextObjects)return STATUS.FAILURE;
                if(mTextObjects[objkey].mId.startsWith("doc"))
                {
                    mixin("doc.MoveNextParameterStart(mCount,selection);");
                    return STATUS.SUCCESS;
                }
                doc.MoveObjectNext(mTextObjects[objkey], mCount, selection);
                return STATUS.SUCCESS;
            case SELECT_OBJ_NEXT    :
                if(MotionCommand.length < 2) return STATUS.INCOMPLETE;
                char sel_obj_key = MotionCommand[1];
                if(sel_obj_key !in mSelObjects)return STATUS.FAILURE;
                doc.MoveObjectNext(mSelObjects[sel_obj_key].End, mCount, false);
                doc.MoveObjectPrev(mSelObjects[sel_obj_key].Start, 1, true);
                return STATUS.SUCCESS;
            case SELECT_OBJ_PREV    :
                if(MotionCommand.length <2) return STATUS.INCOMPLETE;
                char sel_obj_key = MotionCommand[1];
                if(sel_obj_key !in mSelObjects)return STATUS.FAILURE;
                doc.MoveObjectPrev(mSelObjects[sel_obj_key].Start, mCount, false);
                doc.MoveObjectNext(mSelObjects[sel_obj_key].End, 1, true);
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

        if(inputChar == 0)
        {
            insStart = doc.Column();
            mReplacing = true;
            return;
        }

        if( (inputChar == '\r') || (inputChar == '\n'))
        {
            doc.ClearHiliteAllSearchResults();
            insStart = 0;
            mReplacing = false;
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



    STATUS DoLastCommand()
    {
        auto tmp = mInputString;
        mInputString = mLastCommand;
        RunCommand();
        mInputString = tmp;

        return STATUS.SUCCESS;
    }

}


struct SEL_OBJECT
{
    TEXT_OBJECT Start;
    TEXT_OBJECT End;
}


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
    PASTE           = "PASTE",
    PASTE_AFTER     = "PASTE_AFTER",
    INSERT          = "INSERT",
    INSERT_NL       = "INSERT_NL",
    REPLACE         = "REPLACE",
    FILTER          = "FILTER",
    UNDO            = "UNDO",
    REDO            = "REDO",
    REVERT          = "REVERT",
    REPEAT          = "REPEAT",
    SCROLL_CENTER   = "SCROLL_CENTER",
    SCROLL_UP       = "SCROLL_UP",
    SCROLL_DOWN     = "SCROLL_DOWN"
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