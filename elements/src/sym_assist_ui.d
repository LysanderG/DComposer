module sym_assist_ui;


import std.conv;
import std.string;
import std.path;
import std.xml;

import dcore;
import ui;
import elements;


export extern (C) string GetClassName()
{
    return "sym_assist_ui.SYM_ASSIST_UI";
}

class SYM_ASSIST_UI :ELEMENT
{
    public:

    string Name(){
        return "Symbol Assistant";
    }
    string Info(){
        return "View Symbol information";
    }
    string Version(){
        return "00.01";
    }
    string CopyRight() {
        return "Anthony Goins © 2015";
    }
    string License() {
        return "New BSD license";
    }
    string[] Authors() {
        return ["Anthony Goins <neontotem@gmail.com>"];
    }
    PREFERENCE_PAGE PreferencePage(){
        return null;
    }

    void Engage()
    {
        auto sauBuilder = new Builder;
        sauBuilder.addFromFile(SystemPath(Config.GetValue("sym_assist_ui", "glade_file", "elements/resources/sym_assist_ui.glade")));
        mRootBox  = cast(Box)sauBuilder.getObject("box1");
        //mMatchingLabel = cast(Label)sauBuilder.getObject("label1");
        mCandidatesComboBox = cast(ComboBoxText)sauBuilder.getObject("comboboxtext1");
        mPathLabel = cast(Label)sauBuilder.getObject("label2");
        //mSignatureLabel = cast(Label)sauBuilder.getObject("label3");
        mPane = cast(Paned)sauBuilder.getObject("paned1");
        mHierarchyView  = cast(TreeView)sauBuilder.getObject("treeview1");
        mInterfaceView  = cast(TreeView)sauBuilder.getObject("treeview2");
        mParentButton  = cast(Button)sauBuilder.getObject("button2");
        mTypeLabel  = cast(Label)sauBuilder.getObject("label9");
        mLocationButton = cast(Button)sauBuilder.getObject("button1");
        mMembersView  = cast(TreeView)sauBuilder.getObject("treeview3");
        mDocCommentsLabel = cast(Label)sauBuilder.getObject("label4");

        mHierachyStore = cast(TreeStore)sauBuilder.getObject("treestore1");
        mInterfaceStore = cast(ListStore)sauBuilder.getObject("liststore1");
        mMembersStore  = cast(ListStore)sauBuilder.getObject("liststore2");

        mCandidatesComboBox.addOnChanged(delegate void(ComboBoxText cbt){UpdateUI();});

        mHierarchyView.addOnRowActivated(&SelectSymbol);
        mInterfaceView.addOnRowActivated(&SelectSymbol);
        mMembersView.addOnRowActivated(&SelectSymbol);
        mLocationButton.addOnClicked(delegate void(Button me)
        {

            auto idx = mCandidatesComboBox.getActive();
            if((idx < 0) || (idx > mCandidates.length)) return;
            DocMan.Open(mCandidates[idx].File, mCandidates[idx].Line);
        });
        mParentButton.addOnClicked(delegate void(Button me)
        {
            UpScope();
        });




        AddIcon("dcmp-sym-assist", SystemPath(Config.GetValue("icons", "sym-assist-ui", "elements/resources/question-frame.png")));
        auto ActSymAssistUi = "ActSymAssistUI".AddAction("Symbol Assist", "See documentation for symbol", "dcmp-sym-assist", "F1",delegate void (Action){ActionAssist();});
        mActionMenuItem = AddToMenuBar("ActSymAssistUI", "E_lements");
        uiContextMenu.AddAction("ActSymAssistUI");


        Symbols.connect(&CatchSymbols);

        mPane.setPosition(Config.GetValue!int("sym_assist_ui", "pane_pos", 15));


        AddExtraPage(mRootBox, "Symbol Assist");

        Log.Entry("Engaged");


    }

    void Disengage()
    {
        RemoveFromMenuBar(mActionMenuItem, "E_lements");
        "ActSymAssistUI".RemoveAction();
        Config.SetValue("sym_assist_ui", "pane_pos", mPane.getPosition());
        Symbols.disconnect(&CatchSymbols);
        RemoveExtraPage(mRootBox);
        mRootBox.destroy();
        Log.Entry("Disengaged");

    }

    void Configure()
    {
    }

    private:

    Box             mRootBox;
    //Label           mMatchingLabel;
    ComboBoxText    mCandidatesComboBox;
    Label           mPathLabel;
    //Label           mSignatureLabel;
    Paned           mPane;
    TreeView        mHierarchyView;
    TreeView        mInterfaceView;
    Button          mParentButton;
    Label           mTypeLabel;
    Button          mLocationButton;
    TreeView        mMembersView;
    Label           mDocCommentsLabel;

    TreeStore       mHierachyStore;
    ListStore       mInterfaceStore;
    ListStore       mAliasThisStore;
    ListStore       mMembersStore;

    MenuItem        mActionMenuItem;

    DSYMBOL[]         mCandidates;



    void UpdateUI()
    {
        TreeIter ti = new TreeIter;
        auto ndx = mCandidatesComboBox.getActive();
        if((ndx < 0) || (ndx >= mCandidates.length)) return;

        auto candi = mCandidates[ndx];

        mPathLabel.setText(candi.Path);
        //mSignatureLabel.setText(candi.Signature);


        string parentname =  "(none)";
        auto parentscopeindex = lastIndexOf(candi.Path, '.');
        if(parentscopeindex > 0)
        {
            parentname = candi.Path[0..parentscopeindex];
        }
        mParentButton.setLabel(parentname);


        mHierachyStore.clear();
        auto ancestors = Symbols.FindAncestors(candi.Path);
        auto descendants = Symbols.FindDescendants(candi.Path);

        foreach(index,oldy; ancestors)
        {
            mHierachyStore.prepend(ti, null);
            if(index == 0) mHierachyStore.setValue(ti, 0, "\t"~oldy.Path~"\t");
            else mHierachyStore.setValue(ti, 0, oldy.Path);
            mHierachyStore.setValue(ti,1, oldy.Path);
        }
        if((ancestors.length == 0) && (candi.Base.length > 0))
        {
            //ancestor not in symbol library but we know it
            mHierachyStore.prepend(ti, null);
            mHierachyStore.setValue(ti, 0, candi.Base);
            mHierachyStore.setValue(ti, 1, candi.Base);
        }
        foreach (youngun; descendants)
        {
            mHierachyStore.append(ti, null);
            mHierachyStore.setValue(ti, 0, "\t\t"~youngun.Path);
            mHierachyStore.setValue(ti, 1, youngun.Path);
        }

        mInterfaceStore.clear();
        foreach(iface; candi.Interfaces)
        {
            mInterfaceStore.append(ti);
            mInterfaceStore.setValue(ti, 0, iface);
            mInterfaceStore.setValue(ti, 1, iface);
        }

        string type;
        if(candi.Type.length > 0)type = candi.Type;
        else type = to!string(candi.Kind);
        mTypeLabel.setText(type);

        string file;
        if(candi.File.length > 0) file = format("Open %s:%s",baseName(candi.File), candi.Line);
        else file = "No source file (package)";
        mLocationButton.setLabel(file);

        mMembersStore.clear();
        foreach(member; candi.Children)
        {
            mMembersStore.append(ti);
            mMembersStore.setValue(ti, 0, member.Name);
            mMembersStore.setValue(ti, 1, member.Path);
        }

        string initialisedComment = "<span foreground=\"red\">Failed to parse markup text</span>";
        string comments = initialisedComment;

        mDocCommentsLabel.setMarkup(comments);

        if(candi.Signature.length > 0)comments = "<big><u>" ~ candi.Signature ~ "</u></big>\n";
        else comments = "<big><u>" ~ to!string(candi.Kind) ~ " " ~ candi.Name ~ "</u></big>\n";

        comments ~= Ddoc2Pango(candi.Comment.encode());
        mDocCommentsLabel.setMarkup(comments);
        if(initialisedComment == mDocCommentsLabel.getText())
        {
            Log.Entry("Unable to parse documentation comments", "Error");
            mDocCommentsLabel.setText(comments);
        }
    }


    void CatchSymbols(DSYMBOL[] Candidates)
    {
        mCandidates = Candidates;

        mCandidatesComboBox.removeAll();
        foreach(int ndx,candi; mCandidates)
        {
            mCandidatesComboBox.insertText(ndx,candi.Path);
        }

        mCandidatesComboBox.setActive(0);

    }

    void SelectSymbol(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        auto ti = new TreeIter;
        if(tv.getModel().getIter(ti, tp))
        {
            string candidate = tv.getModel().getValueString(ti, 1);
            //auto syms = Symbols.FindExact(candidate.strip());
            auto syms = Symbols.FindExact(candidate);
            if(syms.length == 0) syms = Symbols.GetCompletions([candidate]);
            CatchSymbols(syms);
        }
    }

    void UpScope()
    {
        string ParentPath = mParentButton.getLabel();
        auto syms = Symbols.FindExact(ParentPath);
        CatchSymbols(syms);
    }


    void ActionAssist()
    {
        if(DocMan.Current is null)return;
        auto symCandidate = DocMan.Current.FullSymbol();

        if(symCandidate.length < 1) return;

        auto dsyms = Symbols.GetCompletions(symCandidate.split('.'));
        if(dsyms.length < 1) return;

        Symbols.emit(dsyms);
    }

}

