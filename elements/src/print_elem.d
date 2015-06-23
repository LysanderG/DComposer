module print_elem;


import std.algorithm;

import dcore;
import ui;
import elements;




extern (C) string GetClassName()
{
    return "print_elem.PRINT_ELEM";
}

class PRINT_ELEM : ELEMENT
{
    public:

    string Name(){return "Print element";}
    string Info(){return "Dialog to print current document";}
    string Version(){return "00.01";}
    string License(){return "Unknown";}
    string CopyRight(){return "Anthony Goins © 2015";}
    string[] Authors(){return ["Anthony Goins <neontotem@gmail.com>"];}


    void Engage()
    {
        AddIcon("print-element", SystemPath(Config.GetValue("print_elem", "icon", "elements/resources/printer.png")));
        AddAction("ActPrint", "Print", "Print current document", "print-element", "<Control><Shift>P",
            delegate void (Action a){ PrintDoc();});

        AddToMenuBar("ActPrint", "_System", 0);
        uiContextMenu.AddAction("ActPrint");

        Log.Entry("Engaged");

    }

    void Disengage()
    {
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


    Box         mCustomPage;

    CheckButton mHighLight;
    CheckButton mWrapText;
    CheckButton mLineNumber;

    CheckButton mShowHeader;
    Entry       mLHEntry;
    Entry       mCHEntry;
    Entry       mRHEntry;

    CheckButton mShowFooter;
    Entry       mLFEntry;
    Entry       mCFEntry;
    Entry       mRFEntry;


    void PrintDoc()
    {
        auto FocusedDocument = cast(SourceView)DocMan.Current();
        if (FocusedDocument is null) return;
        auto SvCompositor = new SourcePrintCompositor(FocusedDocument);
        dwrite(SvCompositor);

        auto PrintOp = new PrintOperation();
        dwrite(PrintOp);


        void BeginPrint(PrintContext pc, PrintOperation po)
        {
            dwrite("in begin print!");
            while(!SvCompositor.paginate(pc)){}
            PrintOp.setNPages(SvCompositor.getNPages());
        }

        void DrawPage(PrintContext pc, int page, PrintOperation po)
        {
            dwrite("in DrawPage");
            SvCompositor.drawPage(pc, page);

        }

        ObjectG AddCustomTab(PrintOperation po)
        {
            dwrite("zpre");
            Builder xBuilder = new Builder;
            xBuilder.addFromFile(SystemPath(Config.GetValue("print_elem", "glade_file", "elements/resources/print_elem.glade")));

            mCustomPage = cast(Box)             xBuilder.getObject("root");

            mHighLight      = cast(CheckButton)     xBuilder.getObject("checkbutton1");
            mWrapText   = cast(CheckButton)     xBuilder.getObject("checkbutton2");
            mLineNumber     = cast(CheckButton)     xBuilder.getObject("checkbutton3");

            mShowHeader     = cast(CheckButton)     xBuilder.getObject("showheader");
            mLHEntry        = cast(Entry)           xBuilder.getObject("lhentry");
            mCHEntry        = cast(Entry)           xBuilder.getObject("chentry");
            mRHEntry        = cast(Entry)           xBuilder.getObject("rhentry");

            mShowFooter     = cast(CheckButton)     xBuilder.getObject("showfooter");
            mLFEntry        = cast(Entry)           xBuilder.getObject("lfentry");
            mCFEntry        = cast(Entry)           xBuilder.getObject("cfentry");
            mRFEntry        = cast(Entry)           xBuilder.getObject("rfentry");

            mHighLight  .setActive  (Config.GetValue("print_elem", "mHighLight", false));
            mWrapText   .setActive  (Config.GetValue("print_elem", "wraptext", true));
            mLineNumber .setActive  (Config.GetValue("print_elem", "linenumbers", true));

            mShowHeader .setActive  (Config.GetValue("print_elem", "showheader", true));
            mLHEntry        .setText    (Config.GetValue("print_elem", "left_header_text", "%f"));
            mCHEntry        .setText    (Config.GetValue("print_elem", "center_header_text", ""));
            mRHEntry        .setText    (Config.GetValue("print_elem", "right_header_text", "%N"));

            mShowFooter .setActive  (Config.GetValue("print_elem", "showfooter", true));
            mLFEntry        .setText    (Config.GetValue("print_elem", "left_footer_text", ""));
            mCFEntry        .setText    (Config.GetValue("print_elem", "center_footer_text", ""));
            mRFEntry        .setText    (Config.GetValue("print_elem", "right_footer_text", ""));

            dwrite("z");
            return mCustomPage;
        }

        void ApplyCustomTab(Widget w, PrintOperation po)
        {
            int PrintHighLighting =mHighLight.getActive();
            int PrintWrapText = mWrapText.getActive();
            int PrintLineNumbers = mLineNumber.getActive();

            int PrintHeaders = mShowHeader.getActive();
            int PrintFooters = mShowFooter.getActive();
            string[6] formatstr;

            formatstr[0]= mLHEntry.getText();
            formatstr[1]= mCHEntry.getText();
            formatstr[2]= mRHEntry.getText();
            formatstr[3]= mLFEntry.getText();
            formatstr[4]= mCFEntry.getText();
            formatstr[5]= mRFEntry.getText();

            Config.SetValue("print_elem", "mHighLight", PrintHighLighting);
            Config.SetValue("print_elem", "wraptext", PrintWrapText);
            Config.SetValue("print_elem", "linenumbers", PrintLineNumbers);
            Config.SetValue("print_elem", "showheader", PrintHeaders);
            Config.SetValue("print_elem", "showfooter", PrintFooters);

            Config.SetValue("print_elem", "left_header_text", formatstr[0]);
            Config.SetValue("print_elem", "center_header_text", formatstr[1]);
            Config.SetValue("print_elem", "right_header_text", formatstr[2]);
            Config.SetValue("print_elem", "left_footer_text", formatstr[3]);
            Config.SetValue("print_elem", "center_footer_text", formatstr[4]);
            Config.SetValue("print_elem", "right_footer_text", formatstr[5]);

            foreach (ref s; formatstr)
            {
                auto r =s.findSplit("%f");
                if(r[1].length > 0) s = r[0] ~ DocMan.Current.Name() ~ r[2];
            }

            dwrite("a");

            SvCompositor.setHighlightSyntax(cast(bool)PrintHighLighting);
            SvCompositor.setWrapMode( (PrintWrapText)?(GtkWrapMode.WORD):(GtkWrapMode.NONE));
            SvCompositor.setPrintLineNumbers(PrintLineNumbers);

            dwrite("b");
            SvCompositor.setPrintHeader(cast(bool)PrintHeaders);
            SvCompositor.setPrintFooter(cast(bool)PrintFooters);
            SvCompositor.setHeaderFormat(1, formatstr[0], formatstr[1], formatstr[2]);
            SvCompositor.setFooterFormat(1, formatstr[3], formatstr[4], formatstr[5]);

        }


        dwrite("c");

        PrintOp.addOnCreateCustomWidget (&AddCustomTab);
        PrintOp.addOnCustomWidgetApply(&ApplyCustomTab);
        PrintOp.addOnBeginPrint (&BeginPrint);
        PrintOp.addOnDrawPage(&DrawPage);

        dwrite("d");

        PrintOp.setCustomTabLabel("Source Code");

        dwrite("e");

        auto PrintReturn = PrintOp.run( PrintOperationAction.PRINT_DIALOG, ui.MainWindow);

        dwrite("Print operation returned ", PrintReturn, ", which is a ", typeid(PrintReturn));
    }



}
