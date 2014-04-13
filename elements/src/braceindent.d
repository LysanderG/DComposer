module braceindent;

import elements;
import dcore;
import ui;
import document;
import ui_preferences;

import gtk.TextIter;
import gtk.TextMark;
import gtk.TextBuffer;


import std.string;
import std.range;
import std.uni;


extern (C) string GetClassName()
{
	return "braceindent.BRACE_INDENT";
}


class BRACE_INDENT : ELEMENT
{
	private :

	int mIndentationSize;
	char[] mIndentationSpaces;


	void WatchForNewDocuments(string EventName, DOC_IF NuDoc)
	{
		if(!((EventName == "Create") || (EventName == "Open"))) return;

		DOCUMENT docX = cast(DOCUMENT)NuDoc;
		if(docX is null) return;

		docX.getBuffer().addOnInsertText(&WatchForText, cast(ConnectFlags)1);
	}

	void old_WatchForText(TextIter ti, string text, int dunno, TextBuffer self)
	{
		if(text == "\n")
		{
			auto tiLineStart = ti.copy();
			tiLineStart.backwardLine();
			string x = stripRight(tiLineStart.getText(ti));
			if(x.length < 1) return;
			if(x[$-1] == '{')
			{
				//self.insert(ti, mIndentationSpaces.idup);
				foreach(i;0..mIndentationSize)self.insert(ti, " ");
				return;
			}
		}
		if(text == "}")
		{
			auto marklocation = new TextMark("location", 1);
			self.addMark(marklocation, ti);
			auto tiprevchar = ti.copy();
			tiprevchar.backwardChar();
			auto tiLineStart = ti.copy();
			tiLineStart.setLineOffset(0);
			string x = tiLineStart.getText(ti);
			string stripped = x.stripLeft();
			x = x.detab(Config.GetValue("document", "tab_width", 4));
			//x = x.stripLeft();
			if(stripped[0] != '}') return; //only lines starting with }

			auto timatch = ti.copy();
			int bracecount = 0;
			do
			{
				auto moved = timatch.backwardChar();
				if(moved == 0) return;
				if(timatch.getChar == '}') bracecount++;
				if(timatch.getChar == '{') bracecount--;
			}while(bracecount > 0);
			auto tiMatchlineStart = timatch.copy();
			tiMatchlineStart.setLineOffset(0);
			auto tiMatchLineEnd = timatch.copy();
			tiMatchLineEnd.forwardToLineEnd ();
			string matchline = tiMatchlineStart.getText(tiMatchLineEnd);

			int indentctr;
			foreach(Char; matchline)
			{
				if(Char == ' ')
				{
					indentctr++;
					continue;
				}
				if(Char == '\t')
				{
					auto twidth = Config.GetValue("document", "tab_width", 4);
					indentctr = ((indentctr/twidth) * twidth) + twidth;
					continue;
				}
				break;
			}


			if(x.length > indentctr)
			{
				 tiLineStart.setLineOffset(indentctr);
				 self.delet(tiLineStart, tiprevchar);
			}
			else
			{
				self.delet(tiLineStart, tiprevchar);
				self.insert(tiLineStart, matchline[0..indentctr].idup);
			}
			self.getIterAtMark(ti, marklocation);
			self.deleteMark(marklocation);
			return;
		}
	}


	void WatchForText(TextIter ti, string text, int dunno, TextBuffer self)
	{
		//char InChar = ti.getChar();
		string OpenLineText;
		string CloseLineText;

		auto IndentWidth = Config.GetValue!int("document", "identation_width", 4);

		auto tiCloneForStarting = new TextIter;
		tiCloneForStarting = ti.copy();
		auto tiForEndings = new TextIter;

		if(text == "\n")
		{
			//get openlinetext
			tiCloneForStarting.backwardLine();
			tiForEndings = tiCloneForStarting.copy();
			tiForEndings.forwardToLineEnd();
			OpenLineText = self.getText(tiCloneForStarting, tiForEndings, false);
			//see if last non white space char is an open brace "{"
			string strippedRightOpenLineText = OpenLineText.stripRight();
			if(strippedRightOpenLineText.length < 1) return;
			if(strippedRightOpenLineText[$-1] != '{') return;
			//add some spaces
			if(Config.GetValue("document", "spaces_for_tabs", true))foreach(i; iota(IndentWidth)) self.insert(ti, " ");
			else self.insert(ti, "\t");
			return;
		}

		if(text == "}")
		{
			//save the current iter or things get really screwy
			auto saveTIMark = new TextMark("saveTI", 1);
			self.addMark(saveTIMark, ti);

			scope(exit)
			{
				self.getIterAtMark(ti, saveTIMark);
				self.deleteMark(saveTIMark);
			}

			//is this "}" first non whitespace on line
			tiCloneForStarting.backwardChar();
			while(tiCloneForStarting.getLineOffset() > 0)
			{
				tiCloneForStarting.backwardChar();
				if(tiCloneForStarting.getChar().isSpace() || tiCloneForStarting.getChar.isWhite())continue;

				//there are none whitespace characters between our } and line start so lets ignore indentation
				else return;
			}

			//now tiCloneForStarting should be at line offset zero
			//so lets set tiForEndings to the end
			tiForEndings = tiCloneForStarting.copy();
			tiForEndings.forwardToLineEnd();
			//and the actual text for the line with our }
			CloseLineText = self.getText(tiCloneForStarting, tiForEndings, false);


			//finding the matching open brace
			auto tiMatchOpenBrace = ti.copy();
			int braceCtr = 0;
			do
			{
				auto moved = tiMatchOpenBrace.backwardChar();
				if(moved == 0) return; //aint no match ... unbalanced braces (at least up to our }) so bail
				if(tiMatchOpenBrace.getChar == '}') braceCtr++;
				if(tiMatchOpenBrace.getChar == '{') braceCtr--;
			}while(braceCtr > 0);

			//still here? then tiMatchOpenBrace is on the matching brace :)

			//ok lets get the whole text of the line matching brace is on
			auto tiMatchEndLine = tiMatchOpenBrace.copy();
			tiMatchEndLine.forwardToLineEnd();
			tiMatchOpenBrace.setLineOffset(0);
			OpenLineText = self.getText(tiMatchOpenBrace, tiMatchEndLine, false);

			//here is the indentation (aka starting whitespace right?)
			string OpenLineTextIndentChars;
			foreach(ch; OpenLineText) if (ch.isWhite ||  ch.isSpace) OpenLineTextIndentChars ~= ch;
			auto IndentedColOpen = OpenLineTextIndentChars.column(IndentWidth); //should not this be tab_width ??

			string CloseLineTextIndentChars;
			foreach(ch; CloseLineText) if (ch.isWhite || ch.isSpace) CloseLineTextIndentChars ~= ch;
			auto IndentedColClose = CloseLineTextIndentChars.column(IndentWidth);

			ti.backwardChar();
			self.delet(tiCloneForStarting, ti);
			self.insert(tiCloneForStarting, OpenLineTextIndentChars);


		}
	}






	public :

	string Name(){return "Brace Indentation";}
	string Info(){return "Simply adds a level of indentation following a line ending with '{'.  And removes one level of indentation on a line beginning with '}'";}
	string Version() {return "00.01";}
	string CopyRight() {return "Anthony Goins © 2014";}
	string License() {return "New BSD license";}
	string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}


	void Configure()
	{
		mIndentationSize = Config.GetValue("document", "indention_width", 8);
		mIndentationSpaces.length = mIndentationSize;
		mIndentationSpaces[] = ' ';
	}


	void Engage()
	{
		Configure();
		DocMan.Event.connect(&WatchForNewDocuments);
		Log.Entry("Engaged");
	}



	void Disengage()
	{
		DocMan.Event.disconnect(&WatchForNewDocuments);
		Log.Entry("Disengaged");
	}

	PREFERENCE_PAGE PreferencePage() {return null;}
}
