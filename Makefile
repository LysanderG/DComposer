#Hopefully this Makefile will build DComposer.
#Wish me luck

# ok whats th diff := and =?
DC = dmd

TARGET    = dcomposer
DSOURCES  = $(shell echo src/*.d)

INC_PATHS = -I/usr/include/d
LIBRARIES = -L-lgtkdsv -L-lgtkd -L-lvte -L-lutil -L-lwebkitgtk-1.0

DFLAGS = -of$(TARGET) -D -Dddocs -odobjdir -J. 
RELEASEFLAGS = -release
DEBUGFLAGS = -gc

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

install: $(TARGET)
	mkdir -p $(BINDIR)
	install  -s $(TARGET) $(BINDIR)/$(TARGET)
	mkdir -p $(PREFIX)/share/dcomposer/glade/ 
	install -m644  glade/*    $(PREFIX)/share/dcomposer/glade/
	mkdir -p $(PREFIX)/share/dcomposer/docs/  
	install -m644  docs/*    $(PREFIX)/share/dcomposer/docs/
	mkdir -p $(PREFIX)/share/dcomposer/flags/ 
	install -m644  flags/*    $(PREFIX)/share/dcomposer/flags/
	mkdir -p $(PREFIX)/share/dcomposer/styles/
	install -m644  styles/*    $(PREFIX)/share/dcomposer/styles/
	mkdir -p $(PREFIX)/share/dcomposer/tags/	
	install -m644  tags/*    $(PREFIX)/share/dcomposer/tags/
	install -m644  elementlist $(PREFIX)/share/dcomposer/
	install -m755  childrunner.sh $(PREFIX)/share/dcomposer/
    
	xdg-icon-resource install --size 128 glade/stolen2.png dcomposer-Icon
	xdg-desktop-menu install --novendor dcomposer.desktop 
	su $(SUDO_USER) -p -c "xdg-desktop-icon install --novendor dcomposer.desktop"
	
uninstall:
	rm  -f $(BINDIR)/$(TARGET)
	rm -Rf $(PREFIX)/share/$(TARGET)/
	rm -rf ~/.config/$(TARGET)/
	
	xdg-icon-resource uninstall --size 128 dcomposer-Icon
	xdg-desktop-menu uninstall dcomposer.desktop
	xdg-desktop-icon uninstall dcomposer.desktop

clean:
	rm -f objdir/*
	rm -f docs/*
	rm -f bindir
	rm -f systemdir
	rm -f $(TARGET)



.PHONY:  all  release install uninstall clean 

bindir:
	echo -n $(BINDIR) > bindir


systemdir:
	echo -n $(PREFIX) > systemdir
