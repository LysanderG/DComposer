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

	Box		CustomPage;

	CheckButton HighLight;
	CheckButton WrapText;	
	CheckButton LineNumber; 
	
	CheckButton ShowHeader; 
	Entry LHEntry;	
	Entry CHEntry;	
	Entry RHEntry;	
	
	CheckButton ShowFooter; 
	Entry LFEntry;	
	Entry CFEntry;	
	Entry RFEntry;	



	

	void PrintDoc()
	{
		auto FocusedDocument = dui.GetDocMan.GetDocument();
		if (FocusedDocument is null) return;
		auto SvCompositor = new SourcePrintCompositor(FocusedDocument);

		auto PrintOp = new PrintOperation();

		
		void BeginPrint(PrintContext pc, PrintOperation po)
		{
			writeln("in begin print!");
			while(!SvCompositor.paginate(pc)){}
			PrintOp.setNPages(SvCompositor.getNPages());			
		}

		void DrawPage(PrintContext pc, int page, PrintOperation po)
		{
			writeln("in DrawPage");
			SvCompositor.drawPage(pc, page);
			
		}

		GObject * AddCustomTab(PrintOperation po)
		{
			Builder xBuilder = new Builder;
			xBuilder.addFromFile(Config.getString("PRINTING", "glade_file", "$(HOME_DIR)/glade/printdialogpage.glade"));

			CustomPage = cast(Box)				xBuilder.getObject("root");

			HighLight  = cast(CheckButton) 	xBuilder.getObject("checkbutton1");
			WrapText	= cast(CheckButton)		xBuilder.getObject("checkbutton2");
			LineNumber = cast(CheckButton)		xBuilder.getObject("checkbutton3");

			ShowHeader = cast(CheckButton)		xBuilder.getObject("showheader");
			LHEntry	= cast(Entry)			xBuilder.getObject("lhentry");
			CHEntry	= cast(Entry)			xBuilder.getObject("chentry");
			RHEntry	= cast(Entry)			xBuilder.getObject("rhentry");

			ShowFooter = cast(CheckButton)		xBuilder.getObject("showfooter");
			LFEntry	= cast(Entry)			xBuilder.getObject("lfentry");
			CFEntry	= cast(Entry)			xBuilder.getObject("cfentry");
			RFEntry	= cast(Entry)			xBuilder.getObject("rfentry");

			HighLight	.setActive(Config.getBoolean("PRINTING", "highlight", false));
			WrapText	.setActive(Config.getBoolean("PRINTING", "wraptext", true));
			LineNumber	.setActive(Config.getBoolean("PRINTING", "linenumbers", true));

			ShowHeader	.setActive(Config.getBoolean("PRINTING", "showheader", true));
			LHEntry		.setText(Config.getString("PRINTING", "left_header_text", "%f"));
			CHEntry		.setText(Config.getString("PRINTING", "center_header_text", ""));
			RHEntry		.setText(Config.getString("PRINTING", "right_header_text", "%N"));
			
			ShowFooter	.setActive(Config.getBoolean("PRINTING", "showfooter", true));
			LFEntry		.setText(Config.getString("PRINTING", "left_footer_text", ""));
			CFEntry		.setText(Config.getString("PRINTING", "center_footer_text", ""));
			RFEntry		.setText(Config.getString("PRINTING", "right_footer_text", ""));			

			return cast(GObject*)CustomPage.getBoxStruct();
		}

		void ApplyCustomTab(Widget w, PrintOperation po)
		{
			int PrintHighlighting = HighLight.getActive();
			int PrintWrapText = WrapText.getActive();
			int PrintLineNumbers = LineNumber.getActive();

			int PrintHeaders = ShowHeader.getActive();
			int PrintFooters = ShowFooter.getActive();
			string[6] formatstr;
				
			formatstr[0]= LHEntry.getText();
			formatstr[1]= CHEntry.getText();
			formatstr[2]= RHEntry.getText();
			formatstr[3]= LFEntry.getText();
			formatstr[4]= CFEntry.getText();
			formatstr[5]= RFEntry.getText();

			Config.setBoolean("PRINTING", "highlight", PrintHighlighting);
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

			

			SvCompositor.setHighlightSyntax(PrintHighlighting);
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
        dui.AddIcon("dcomposer-print", Config.getString("ICONS", "dcomposer_split", "$(HOME_DIR)/glade/printer.png"));
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
	



