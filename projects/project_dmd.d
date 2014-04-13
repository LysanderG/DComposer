module dproject;

import dcore;

class D : PROJECT
{
	string mCompiler;			//which compiler dmd, gdmd, ldmd (must have dmd interface)
	string mCompilerVersion;	//2.063.2? just info to show what project was developed for

	string[] ListKeys =
	[
		"srcfiles",
		"relfiles",
		"info",
		"versions",
		"debugs",
		"import_paths",
		"string_paths",
		"compiler",
		"libraries",
		"library_paths",
		"prebuild_scripts",
		"postbuild_scripts",
		"extra_compiler_options",
		"run_args"
	];


	this()
	{
		mInfo = "Generic project for the D programming language.  Supports compilers with the same interface as the DMD reference compiler.";
		mProjectType = "DMD Project";

		mBuildable = true;
		mOpenable = true;
		mRunable = true;
		mSaveable = true;
		Event.emit(ProEvent.Created);
	}

	void Open(JSON ProJson)
	{
		mDcomposerProjectVersion = ProJson["version"];
		mName = ProJson["name"];
		mChildFolder = ProJson["relative_path"];
		mTarget = ProJson["target_type"];
		mCompiler =ProJson["compiler"];
		mCompilerVersion = ProJson["compiler_version"];

		Lists.mLists.length = 0;
		foreach (key, list; ProJson["lists"].object)
		{
			Lists[key] = list;
		}

		mFlags.length = 0;
		foreach(key, item; ProJson["flags"])
		{
			mFlags[key] = FLAG(item["switch"], item["brief"], item["has_arg"], item["arg"]);
		}

		Event.emit(ProEvent.Opened);

	}

	void Save()
	{
		JSON x = jsonObject();

		x["version"] = mDcomposerProjectVersion;
		x["name"] = mName;
		x["relative_path"] = mChildFolder;
		x["target_type"] = mTarget;
		x["compiler"] = mCompiler;
		x["compiler_version"] = mCompilerVersion;

		x["lists"] = jsonObject();
		foreach(key, item; Lists)
		{
			x["lists"][key] = item;
		}
	}

	void Build()
	{
		Log.Entry("Pretending to build " ~ Name);
	}

	void Run()
	{
		Log.Entry("Pretending to run " ~ Name);
	}




}




