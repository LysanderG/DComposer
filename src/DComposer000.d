ntry("Disengaged DEBUGGER");
    }


    void Load(string AppName, string SourceDirectories)
    {
        size_t BytesWritten;
        
        mRunning = true;

        mGdbProcess = new Spawn(["gdb","--interpreter=mi", AppName]);

        //mGdbProcess.execAsyncWithPipes(null, &ReadGdbOutput, &ReadGdbError);
        mGdbProcess.execAsyncWithPipes();

        mReadFromGdb = IOChannel.unixNew(mGdbProcess.stdOut);
        mReadFromGdb.gIoAddWatch(GIOCondition.IN | GIOCondition.HUP, &C_WatchKidOutput, cast(void*) this);
        mWriteToGdb = IOChannel.unixNew(mGdbProcess.stdIn);
        mWriteToGdb.writeChars("-break-insert _Dmain\n", -1, BytesWritten);

    }
        
    
    void Unload()
    {
        if(mRunning)
        {
            size_t BytesWritten;
            mWriteToGdb.writeChars("-exec-abort\n", -1, BytesWritten);
            mWriteToGdb.flush();
            mWriteToGdb.writeChars("-gdb-exit\n", -1, BytesWritten);
            mWriteToGdb.flush();
            
            ntry("Disengaged DEBUGGER");
    }


    void Load(string AppName, string SourceDirectories)
    {
        size_t BytesWritten;
        
        mRunning = true;

        mGdbProcess = new Spawn(["gdb","--interpreter=mi", AppName]);

        //mGdbProcess.execAsyncWithPipes(null, &ReadGdbOutput, &ReadGdbError);
        mGdbProcess.execAsyncWithPipes();

        mReadFromGdb = IOChannel.unixNew(mGdbProcess.stdOut);
        mReadFromGdb.gIoAddWatch(GIOCondition.IN | GIOCondition.HUP, &C_WatchKidOutput, cast(void*) this);
        mWriteToGdb = IOChannel.unixNew(mGdbProcess.stdIn);
        mWriteToGdb.writeChars("-break-insert _Dmain\n", -1, BytesWritten);

    }
        
    
    void Unload()
    {
        if(mRunning)
        {
            size_t BytesWritten;
            mWriteToGdb.writeChars("-exec-abort\n", -1, BytesWritten);
            mWriteToGdb.flush();
            mWriteToGdb.writeChars("-gdb-exit\n", -1, BytesWritten);
            mWriteToGdb.flush();
            
            ntry("Disengaged DEBUGGER");
    }


    void Load(string AppName, string SourceDirectories)
    {
        size_t BytesWritten;
        
        mRunning = true;

        mGdbProcess = new Spawn(["gdb","--interpreter=mi", AppName]);

        //mGdbProcess.execAsyncWithPipes(null, &ReadGdbOutput, &ReadGdbError);
        mGdbProcess.execAsyncWithPipes();

        mReadFromGdb = IOChannel.unixNew(mGdbProcess.stdOut);
        mReadFromGdb.gIoAddWatch(GIOCondition.IN | GIOCondition.HUP, &C_WatchKidOutput, cast(void*) this);
        mWriteToGdb = IOChannel.unixNew(mGdbProcess.stdIn);
        mWriteToGdb.writeChars("-break-insert _Dmain\n", -1, BytesWritten);

    }
        
    
    void Unload()
    {
        if(mRunning)
        {
            size_t BytesWritten;
            mWriteToGdb.writeChars("-exec-abort\n", -1, BytesWritten);
            mWriteToGdb.flush();
            mWriteToGdb.writeChars("-gdb-exit\n", -1, BytesWritten);
            mWriteToGdb.flush();
            
            