//      lugui.d
//      
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//      
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//      
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//      
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.

module logui;

import std.stdio;

import gtk.ScrolledWindow;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.ListStore;
import gtk.CellRendererText;
import gtk.Label;
import gtk.Widget;
import gtk.Notebook;
import gtk.Adjustment;



ELEMENT AcquireElement()
{
    return new LOG_UI;
}

class LOG_UI : ELEMENT
{
    private:
    
	string 				mName;
    string              mInformation;
    
	ScrolledWindow		mScroller;
	TreeView			mTreeView;
	ListStore			mList;
	Label				mLabel;

	bool 				mState;


    @property string Name() {return mName;}
    @property string Information() {return mInformation;}
    @property bool   State() {return mState;}
    @property void   State(bool NuState)
    {
        if (NuState == mState) return;
        Nustate ? Enage() : Disengage();
    }



	void Engage()
	{
		mName = "LOG_UI";
        mInformation = "Element to capture log output and redirect to a pretty window"

        mState = true;        
        
        
		mScroller = new ScrolledWindow;
		mTreeView = new TreeView;
		mList = new ListStore([GType.STRING, GType.STRING, GType.STRING]);
		mLabel = new Label("Log Viewer");

		TreeViewColumn tvc  = new TreeViewColumn("Message", new CellRendererText, "markup", 0);
		mTreeView.appendColumn(tvc);

		mTreeView.setRulesHint(1);
		mTreeView.setModel(mList);

		mScroller.add(mTreeView);

		
		dui.GetExtraPane.appendPage(mScroller, mLabel);
		mScroller.showAll();
		GetLog.connect(&CatchLog);

        //catch up on missed log entries before we turned on this visual log viewer
		foreach (s; GetLog.GetEntries())CatchLog(s, "Info", null);

		mScroller.getVadjustment().addOnChanged(delegate void(Adjustment adj){adj.setValue(adj.getUpper());});
		
	}

	void Disengage()
	{
        mState = false;
		mScroller.hide(); //??
		log.GetDefaultLog().disconnect(&CatchLog);
	}
		


	void CatchLog(string mesg, string level, string mod)
	{
		//todo make sure to remove or escape "&" from markup text --- causes weird artifacts
		//dmd "usage output" prints both <= and & both are used by markup text causing gtk-warnings and bad output to treeview lines
		if(level == "Error") mesg = `<span foreground="red">`~mesg~ "</span>";
		if(level == "Debug") mesg = `<span foreground="blue">`~mesg~ "</span>";
		auto trit = new TreeIter;
		
		mList.append(trit);
		mList.setValue(trit, 0, mesg);
		mTreeView.setModel(mList);

		//mScroller.getVadjustment().setValue(mScroller.getVadjustment().getUpper());
	}
}
