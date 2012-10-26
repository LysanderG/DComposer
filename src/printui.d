// printui.d
//
// Copyright 2012 Anthony Goins <neontotem@gmail.com>
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
// MA 02110-1301, USA.


module printui;

import std.stdio;
import std.algorithm;
import std.traits;


import dcore;
import ui;
import elements;
import dcomposer;

import gtk.Action;
import gtk.SeparatorMenuItem;
import gtk.PrintOperation;
import gtk.PrintContext;
import gtk.Builder;
import gtk.Widget;
import gtk.Box;
import gtk.Entry;
import gtk.CheckButton;

import gsv.SourcePrintCompositor;


class PRINTER : ELEMENT
{
	private:

	string		mName;
	string		mInfo;
	bool		mState;

	Action		mPrintAction;

	Box			mCustomPage;

	CheckButton mHighLight;
	CheckButton mWrapText;
	CheckButton mLineNumber;

	CheckButton mShowHeader;
	Entry 		mLHEntry;
	Entry 		mCHEntry;
	Entry 		mRHEntry;

	CheckButton mShowFooter;
	Entry 		mLFEntry;
	Entry 		mCFEntry;
	Entry 		mRFEntry;





	void PrintDoc()
	{
		auto FocusedDocument = dui.GetDocMan.GetDocument();
		if (FocusedDocument is null) return;
		auto SvCompositor = new SourcePrintCompositor(FocusedDocument);

		auto PrintOp = new PrintOperation();


		void BeginPrint(PrintContext pc, PrintOperation po)
		{
			while(!SvCompositor.paginate(pc)){}
			PrintOp.setNPages(SvCompositor.getNPages());
		}

		void DrawPage(PrintContext pc, int page, PrintOperation po)
		{
			SvCompositor.drawPage(pc, page);

		}

		GObject * AddCustomTab(PrintOperation po)
		{
			Builder xBuilder = new Builder;
			xBuilder.addFromFile(Config.getString("PRINTING", "glade_file", "$(HOME_DIR)/glade/printdialogpage.glade"));

			mCustomPage	= cast(Box)				xBuilder.getObject("root");

			mHighLight  	= cast(CheckButton) 	xBuilder.getObject("checkbutton1");
			mWrapText	= cast(CheckButton)		xBuilder.getObject("checkbutton2");
			mLineNumber 	= cast(CheckButton)		xBuilder.getObject("checkbutton3");

			mShowHeader 	= cast(CheckButton)		xBuilder.getObject("showheader");
			mLHEntry		= cast(Entry)			xBuilder.getObject("lhentry");
			mCHEntry		= cast(Entry)			xBuilder.getObject("chentry");
			mRHEntry		= cast(Entry)			xBuilder.getObject("rhentry");

			mShowFooter 	= cast(CheckButton)		xBuilder.getObject("showfooter");
			mLFEntry		= cast(Entry)			xBuilder.getObject("lfentry");
			mCFEntry		= cast(Entry)			xBuilder.getObject("cfentry");
			mRFEntry		= cast(Entry)			xBuilder.getObject("rfentry");

			mHighLight	.setActive	(Config.getBoolean("PRINTING", "mHighLight", false));
			mWrapText	.setActive	(Config.getBoolean("PRINTING", "wraptext", true));
			mLineNumber	.setActive	(Config.getBoolean("PRINTING", "linenumbers", true));

			mShowHeader	.setActive	(Config.getBoolean("PRINTING", "showheader", true));
			mLHEntry		.setText	(Config.getString("PRINTING", "left_header_text", "%f"));
			mCHEntry		.setText	(Config.getString("PRINTING", "center_header_text", ""));
			mRHEntry		.setText	(Config.getString("PRINTING", "right_header_text", "%N"));

			mShowFooter	.setActive	(Config.getBoolean("PRINTING", "showfooter", true));
			mLFEntry		.setText	(Config.getString("PRINTING", "left_footer_text", ""));
			mCFEntry		.setText	(Config.getString("PRINTING", "center_footer_text", ""));
			mRFEntry		.setText	(Config.getString("PRINTING", "right_footer_text", ""));

            return cast(GObject *)mCustomPage.getBoxStruct();
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

			Config.setBoolean("PRINTING", "mHighLight", PrintHighLighting);
			Config.setBoolean("PRINTING", "wraptext", PrintWrapText);
			Config.setBoolean("PRINTING", "linenumbers", PrintLineNumbers);
			Config.setBoolean("PRINTING", "showheader", PrintHeaders);
			Config.setBoolean("PRINTING", "showfooter", PrintFooters);

			Config.setString("PRINTING", "left_header_text", formatstr[0]);
			Config.setString("PRINTING", "center_header_text", formatstr[1]);
			Config.setString("PRINTING", "right_header_text", formatstr[2]);
			Config.setString("PRINTING", "left_footer_text", formatstr[3]);
			Config.setString("PRINTING", "center_footer_text", formatstr[4]);
			Config.setString("PRINTING", "right_footer_text", formatstr[5]);

			foreach (ref s; formatstr)
			{
				auto r =s.findSplit("%f");
				if(r[1].length > 0) s = r[0] ~ dui.GetDocMan.GetName() ~ r[2];
			}



			SvCompositor.setHighlightSyntax(PrintHighLighting);
			SvCompositor.setWrapMode( (PrintWrapText)?(GtkWrapMode.WORD):(GtkWrapMode.NONE));
			SvCompositor.setPrintLineNumbers(PrintLineNumbers);

			SvCompositor.setPrintHeader(PrintHeaders);
			SvCompositor.setPrintFooter(PrintFooters);
			SvCompositor.setHeaderFormat(1, formatstr[0], formatstr[1], formatstr[2]);
			SvCompositor.setFooterFormat(1, formatstr[3], formatstr[4], formatstr[5]);

		}




		PrintOp.addOnCreateCustomWidget (&AddCustomTab);
		PrintOp.addOnCustomWidgetApply(&ApplyCustomTab);
		PrintOp.addOnBeginPrint (&BeginPrint);
		PrintOp.addOnDrawPage(&DrawPage);

		PrintOp.setCustomTabLabel("Source Code");

		auto PrintReturn = PrintOp.run( PrintOperationAction.PRINT_DIALOG, dui.GetWindow());

		writefln("Print operation returned %s, which is a %s", PrintReturn, typeid(PrintReturn));
	}



	public:

    this()
    {
        mName = "PRINTER";
        mInfo = "Sends current document to the printer.";
        mState = false;

        PREFERENCE_PAGE mPrefPage = null;
        dui.AddIcon("dcomposer-print", Config.getString("ICONS", "dcomposer_print", "$(HOME_DIR)/glade/printer.png"));
    }

    @property string Name() {return mName;}
    @property string Information(){return mInfo;}
    @property bool   State() {return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        if(mState) Engage();
        else Disengage();

    }
    PREFERENCE_PAGE GetPreferenceObject()
	{
		return null;
	}



    void Engage()
    {

		mPrintAction = new Action("PrintAct", "_Print", "Summon from the Digital Plane", "dcomposer-print");

		mPrintAction.addOnActivate( delegate void (Action x){PrintDoc();});
		mPrintAction.setAccelGroup(dui.GetAccel());
		dui.Actions().addActionWithAccel(mPrintAction, "<CONTROL>P");
        mPrintAction.connectAccelerator();

		//dui.AddMenuItem("_System",new SeparatorMenuItem(),2  );

        dui.AddMenuItem("_System", mPrintAction.createMenuItem(),2);
		dui.AddToolBarItem(mPrintAction.createToolItem());
		dui.GetDocMan.AddContextMenuAction(mPrintAction);

		Log.Entry("Engaged "~Name()~"\t\t\telement.");
	}

	void Disengage()
	{
		mState = false;
		Log.Entry("Disengaged "~mName~"\t\telement.");
	}
}




