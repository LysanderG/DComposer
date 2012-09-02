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


import dcore;
import ui;
import elements;

import gtk.Action;
import gtk.SeparatorMenuItem;
import gtk.PrintOperation;
import gtk.PrintContext;

import gsv.SourcePrintCompositor;


class PRINTER : ELEMENT
{
	private:

	string		mName;
	string		mInfo;
	bool		mState;

	Action		mPrintAction;

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
		
		

		PrintOp.addOnBeginPrint (&BeginPrint);
		PrintOp.addOnDrawPage(&DrawPage);

		auto PrintReturn = PrintOp.run( PrintOperationAction.PRINT_DIALOG, dui.GetWindow());
		
		writefln("Print operation returned %s, which is a %s", PrintReturn, typeid(PrintReturn));
	}
		
	
	
	public:

    this()
    {
        mName = "SPLIT_DOCUMENT";
        mInfo = "Split Documents into 2 views";
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
		
		mPrintAction = new Action("PrintAct", "_Print", "Print Current Document", "dcomposer-print");

		mPrintAction.addOnActivate( delegate void (Action x){PrintDoc();});
		mPrintAction.setAccelGroup(dui.GetAccel());
		dui.Actions().addActionWithAccel(mPrintAction, "<CONTROL>P");        
        mPrintAction.connectAccelerator();

		dui.AddMenuItem("_Documents",new SeparatorMenuItem()    );
		
        dui.AddMenuItem("_Documents", mPrintAction.createMenuItem());
		dui.AddToolBarItem(mPrintAction.createToolItem());
		dui.GetDocMan.AddContextMenuAction(mPrintAction);

		Log.Entry("Engaged PRINT_UI element.");
	}

	void Disengage()
	{
		mState = false;
		Log.Entry("Disengaged PRINT_UI element.");
	}
}
	



