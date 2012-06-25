#Hopefully this Makefile will build DComposer.
#Wish me luck

# ok whats th diff := and =?
DC = dmd


TARGET    = dcomposer
DSOURCES  = $(shell echo src/*.d)

INC_PATHS = -I/usr/include/d
LIBRARIES = -L-lgtkdsv -L-lgtkd -L-lvte -L-lutil

DFLAGS = -of$(TARGET) -D -Dddocs -odobjdir -J.
RELEASEFLAGS = -release
DEBUGFLAGS = -debug -gc

ifeq ("Linux", uname)
	LIBRARIES = $(LIBRARIES) -L-ldl
endif

PREFIX = $(DESTDIR)/usr/local
BINDIR = $(PREFIX)/bin




all: $(TARGET) 

$(TARGET): bindir  systemdir $(DSOURCES)
	@echo Building $(TARGET) debug
	$(DC) $(DFLAGS) $(DEBUGFLAGS) $(INC_PATHS) $(LIBRARIES) $(DSOURCES)
	
	


release: bindir systemdir
	@echo Building $(TARGET) release 
	$(DC) $(DFLAGS) $(RELEASEFLAGS) $(INC_PATHS) $(LIBRARIES) $(DSOURCES)	

install: release
	install -D -s $(TARGET) $(BINDIR)/$(TARGET)
	mkdir -p $(PREFIX)/share/dcomposer/glade/ 
	install -D  glade/*    $(PREFIX)/share/dcomposer/glade/
	mkdir -p $(PREFIX)/share/dcomposer/docs/  
	install -D   docs/*    $(PREFIX)/share/dcomposer/docs/
	mkdir -p $(PREFIX)/share/dcomposer/flags/ 
	install -D  flags/*    $(PREFIX)/share/dcomposer/flags/
	mkdir -p $(PREFIX)/share/dcomposer/styles/
	install -D styles/*    $(PREFIX)/share/dcomposer/styles/
	mkdir -p $(PREFIX)/share/dcomposer/tags/	
	install -D   tags/*    $(PREFIX)/share/dcomposer/tags/
	install -D elementlist $(PREFIX)/share/dcomposer/

uninstall:
	rm  -f $(BINDIR)/$(TARGET)
	rm -Rf $(PREFIX)/share/dcomposer/

clean:
	rm -f objdir/*
	rm -f bindir
	rm -f systemdir

distclean: clean
	rm -f $(TARGET)



.PHONY: all release install uninstall clean distclean

bindir:
	echo -n $(BINDIR) > bindir


systemdir:
	echo -n $(PREFIX) > systemdir
