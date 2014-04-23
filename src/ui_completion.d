module ui_completion;


import dcore;
import ui;
import document;

import gtk.Window;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.CellRendererText;
import gtk.CellRenderer;
import gtk.ScrolledWindow;
import gtk.ListStore;
import gtk.TreeIter;
import gtk.Widget;
import gtk.Main;
import gtk.TreePath;
import gtk.TreeSelection;
import gtk.Builder;


import gdk.Keysyms;
import gdk.Event;
import gdk.Gdk;

import std.conv;


struct POSSIBLES
{
	ListStore	mStore;
	int			mXpos;
	int			mYpos;
	int			mXlen;
	int			mYlen;

	DSYMBOL[]	mSymbols;

	void Set(DSYMBOL[] Choices, RECTANGLE where, bool isCallTip = false)
	{
		TreeIter ti = new TreeIter;
		mXpos = where.x;
		mYpos = where.y;
		mXlen = where.xl;
		mYlen = where.yl;
		mSymbols = Choices;

		mStore = new ListStore([GType.STRING, GType.STRING]);
		foreach(choice; Choices)
		{
			string NameOrSig = isCallTip ? choice.Signature : choice.Name;
			mStore.append(ti);
			mStore.setValue(ti, 0, choice.Icon);
			mStore.setValue(ti, 1, NameOrSig);
		}
	}
	void Set(string[] Choices, RECTANGLE where, bool isCallTip = false)
	{
		TreeIter ti = new TreeIter;
		mXpos = where.x;
		mYpos = where.y;
		mXlen = where.xl;
		mYlen = where.yl;
		mSymbols.length = 0;

		mStore = new ListStore([GType.STRING, GType.STRING]);
		foreach(choice; Choices)
		{

			mStore.append(ti);
			mStore.setValue(ti, 0, " ");
			mStore.setValue(ti, 1, choice);

			DSYMBOL incompleteSymbol = new DSYMBOL;
			incompleteSymbol.Name = choice.dup;
			mSymbols ~= incompleteSymbol;

		}
	}


	bool Empty(){return (mSymbols.length < 1)? true : false;}

	ListStore GetModel(){return mStore;}

}

class UI_COMPLETION
{

	private:

	Window					mWindow;
	TreeView				mList;
	ScrolledWindow			mScrollBox;
	POSSIBLES[MAX_DEPTH]	mPossibleTips;
	POSSIBLES				mPossibleCompletes;

	int						mTipsDepth;
	enum 					INVALID_DEPTH = -1;
	enum					MAX_DEPTH = 64;
	enum
	{
		OFF,
		TIP,
		COMPLETION
	}
	int						mState;
	int						mMaxWindowWidth;
	int						mMaxWindowHeight;


	void InsertCompletion()
	{
		if(mState != COMPLETION) return;
		auto doc = cast(DOCUMENT)DocMan.Current();
		TreePath tp = new TreePath;
		TreeViewColumn tvc = new TreeViewColumn;
		mList.getCursor(tp, tvc);
		auto ti = new TreeIter(mList.getModel, tp);
		//doc.insertText(ti.getValueString(1));
		doc.CompleteSymbol(ti.getValueString(1));
	}


    void MoveSelectionDown()
    {
        TreePath tp = new TreePath;
        auto lasttp = new TreePath(true);
        TreeViewColumn tvc = new TreeViewColumn;

		mList.getCursor(tp, tvc);
		if(tp is null) tp = new TreePath(true);
		else
		{
			lasttp = tp.copy();
			tp.next();
		}
		mList.setCursor(tp, tvc, 0);
		tp.free();
		mList.getCursor(tp, tvc);
		if(tp is null)
		{
			mList.setCursor(lasttp, tvc, 0);
			lasttp.free();
		}
		else
		{
			tp.free();
		}
	}

	void MoveSelectionUp()
    {
        TreePath tp = new TreePath;
        TreeViewColumn tvc = new TreeViewColumn;

		mList.getCursor(tp, tvc);

		if(tp is null) tp = new TreePath(true);
		else tp.prev();

		mList.setCursor(tp, tvc, 0);
		tp.free();

		mList.getCursor(tp, tvc);
		if(tp is null)
		{
			tp = new TreePath(true);
			mList.setCursor(tp, tvc, 0);
		}
		tp.free();
	}

	 void SetUpCompletion()
	{

		mWindow.setTransientFor(ui.MainWindow);
		mMaxWindowWidth = Config.GetValue("ui_completion", "window_x_size", 120);
		mMaxWindowHeight= Config.GetValue("ui_completion", "window_y_size", 600);

		mScrollBox.setSizeRequest(mMaxWindowWidth, mMaxWindowHeight);

		mList.setEnableSearch(0);
		mList.setHeadersVisible(0);
		mList.addOnRowActivated (&WatchTreeActivated);
		mList.addOnSizeAllocate (delegate void (GdkRectangle* r, Widget w){ResizeWindow();});

	}


	void WatchForNewDocuments(string EventType, DOC_IF nuDoc)
	{
		if(!((EventType == "Create") || (EventType == "Open"))) return;
		auto doc = cast(DOCUMENT) nuDoc;

		doc.addOnFocusOut(delegate bool(Event, Widget){KillAll();return false;});
		doc.addOnButtonRelease(delegate bool(Event, Widget){KillAll();return false;});
		doc.addOnScroll(delegate bool(Event, Widget){KillAll();return false;});
		doc.addOnKeyPress(&WatchKey);
		doc.addOnKeyRelease(&WatchKey);
	}

	bool WatchKey(Event event, Widget me)
	{
		if(!mWindow.isVisible)return false;
		uint keyval;
		ModifierType state;

		event.getKeyval(keyval);
		event.getState(state);

		switch (keyval)
		{
			//case GdkKeysyms.GDK_parenright  : 	if(event.type == EventType.KEY_PRESS) if(mState == TIP) Kill();
			//									return false;

			case GdkKeysyms.GDK_ISO_Left_Tab:
			case GdkKeysyms.GDK_KP_Up		:
			case GdkKeysyms.GDK_Up	 		: 	if(event.type == EventType.KEY_PRESS)  MoveSelectionUp(); return true;

			case GdkKeysyms.GDK_Tab         :
			case GdkKeysyms.GDK_KP_Down		:
			case GdkKeysyms.GDK_Down 		:	if(event.type == EventType.KEY_PRESS)  MoveSelectionDown(); return true;//Main.propagateEvent(mList, event); return true;//mList.onKeyReleaseEvent(event.key); return true;

			case GdkKeysyms.GDK_Escape		:	KillAll(); return true;

			case GdkKeysyms.GDK_BackSpace	:	if(mState == COMPLETION)
												{
													PopComplete();
													return false;
												}
												else return false;

			case GdkKeysyms.GDK_Return		:
			case GdkKeysyms.GDK_KP_Enter	: 	if(mState == COMPLETION)
												{
													InsertCompletion();
													PopComplete();
													return true;
												}
												else return false;

			default 	:	return false;
												//if(mState == COMPLETION) Kill();


		}

		//return false;
	}

	void WatchTreeActivated(TreePath tp, TreeViewColumn tvc, TreeView tv)
	{
		InsertCompletion();
		PopComplete();
	}


	void Present()
	{
		if(mList.getParent() is mScrollBox)
		{
			mWindow.remove(mScrollBox);
			mScrollBox.remove(mList);
			mWindow.add(mList);
		}

		int cursorX, cursorY, cursorXlen, cursorYlen;

		if(mState == OFF) return;

		if(mState == COMPLETION)
		{
			mList.setModel(mPossibleCompletes.GetModel());
			cursorX = mPossibleCompletes.mXpos;
			cursorY = mPossibleCompletes.mYpos;
			cursorXlen = mPossibleCompletes.mXlen;
			cursorYlen = mPossibleCompletes.mYlen;
		}
		if(mState == TIP)
		{
			mList.setModel(mPossibleTips[mTipsDepth].GetModel());
			cursorX = mPossibleTips[mTipsDepth].mXpos;
			cursorY = mPossibleTips[mTipsDepth].mYpos;
			cursorXlen = mPossibleTips[mTipsDepth].mXlen;
			cursorYlen = mPossibleTips[mTipsDepth].mYlen;
		}
		mList.setCursor(new TreePath(true), null, false);

		mWindow.present();
		mList.queueResize();

		PositionWindow(cursorX, cursorY, cursorXlen, cursorYlen);


	}

	void ResizeWindow()
	{
		int minYlen, natYlen;
		int minXlen, natXlen;

		mList.getPreferredHeight(minYlen, natYlen);
		mList.getPreferredWidth(minXlen, natXlen);

		if(natYlen > mMaxWindowHeight)
		{
			mList.reparent(mScrollBox);
			mWindow.add(mScrollBox);
		}


	}


	void PositionWindow(int X, int Y, int Xlen, int Ylen)
	{
		int Yfinal;
		auto doc = cast(DOCUMENT)DocMan.Current();
		auto docwindow = doc.getWindow(GtkTextWindowType.WIDGET);
		int DocXorig, DocYorig, DocXlen, DocYlen;
		docwindow.getRootOrigin(DocXorig, DocYorig);
		DocXlen = docwindow.getWidth();
		DocYlen = docwindow.getHeight();

		if( (Y + mWindow.getWindow.getHeight()) > (DocYorig + DocYlen)) Yfinal = Y - mWindow.getWindow.getHeight();
		else Yfinal = Y + Ylen;
		mWindow.move(X, Yfinal);
	}

	void Hide()
	{
		mWindow.hide();
	}


//------------------------------------------------------------------------------------------------------------

	public:


	void Engage()
	{
		mState = OFF;
		auto builder = new Builder;
		builder.addFromFile(SystemPath(Config.GetValue("ui_completion", "glade_file", "glade/ui_complete.glade")));

		mTipsDepth = INVALID_DEPTH;

		mWindow = cast(Window)builder.getObject("window1");
		mList = cast(TreeView)builder.getObject("treeview1");

		mScrollBox = cast(ScrolledWindow)builder.getObject("scrolledwindow1");

		SetUpCompletion();


		DocMan.Event.connect(&WatchForNewDocuments);

		mList.showAll();

		Log.Entry("Engaged");
	}
	void PostEngage()
	{
		Log.Entry("PostEngaged");
	}
	void Disengage()
	{
		Log.Entry("Disengaged");
	}

	void PushComplete(T)(T[] Possibles, RECTANGLE where)
	{
		mState = COMPLETION;
		mPossibleCompletes.Set(Possibles, where);
		Present();
	}

	void PopComplete()
	{
		if(mState != COMPLETION) return;
		if(mTipsDepth > INVALID_DEPTH)
		{
			mState = TIP;
			Present();
			return;
		}
		mState = OFF;
		Hide();
	}


	void PushTip(T)(T[] Possibles, RECTANGLE where)
	{
		if(mTipsDepth >= MAX_DEPTH-1) return;
		mState = TIP;
		mTipsDepth++;
		mPossibleTips[mTipsDepth].Set(Possibles, where, true);
		Present();
	}

	void PopTip()
	{
		if(mState != TIP) return;
		mTipsDepth--;
		if(mTipsDepth > INVALID_DEPTH)
		{
			Present();
			return;
		}
		mState = OFF;
		Hide();
	}

	void Kill()
	{
		if(mState == COMPLETION) PopComplete();
		if(mState == TIP) PopTip();
	}

	void KillAll()
	{
		if(mState == COMPLETION) PopComplete();
		if(mState == TIP) mTipsDepth = 0;
		mState = OFF;
		Hide();
	}

}
