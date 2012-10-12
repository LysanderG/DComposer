DC = dmd

TARGET    = dcomposer
DSOURCES  = $(shell echo src/*.d)

INC_PATHS = -I/usr/include/d
LIBRARIES = -L-lgtkdsv -L-lgtkd -L-lvte -L-lutil

DFLAGS = -of$(TARGET) -odobjdir -J.
RELEASEFLAGS = -release
DEBUGFLAGS = -gc -debug

ifeq ("Linux", $(shell uname))
	LIBRARIES = $(LIBRARIES) -L-ldl
endif

prefix = $(DESTDIR)/usr/local
BINDIR = $(prefix)/bin

webkit: LIBRARIES := $(LIBRARIES) -L-lwebkitgtk-1.0
webkit: DFLAGS := $(DFLAGS) -version=WEBKIT

release: DFLAGS += -release
debug: DFLAGS += -g -debug



all: $(TARGET)

$(TARGET):  $(DSOURCES)
	$(
	$(DC) $(DFLAGS) $(INC_PATHS) $(LIBRARIES) $(DSOURCES)

install: $(TARGET)
	mkdir -p $(BINDIR)
	install  -s $(TARGET) $(BINDIR)/$(TARGET)
	mkdir -p $(prefix)/share/dcomposer/glade/
	install -m644  glade/*    $(prefix)/share/dcomposer/glade/
	mkdir -p $(prefix)/share/dcomposer/docs/
	install -m644  docs/*    $(prefix)/share/dcomposer/docs/
	mkdir -p $(prefix)/share/dcomposer/flags/
	install -m644  flags/*    $(prefix)/share/dcomposer/flags/
	mkdir -p $(prefix)/share/dcomposer/styles/
	install -m644  styles/*    $(prefix)/share/dcomposer/styles/
	mkdir -p $(prefix)/share/dcomposer/tags/
	install -m644  tags/*    $(prefix)/share/dcomposer/tags/
	install -m644  elementlist $(prefix)/share/dcomposer/
	install -m755  childrunner.sh $(prefix)/share/dcomposer/

	xdg-icon-resource install --size 128 glade/stolen2.png dcomposer-Icon
	xdg-desktop-menu install --novendor dcomposer.desktop
	su $(SUDO_USER) -p -c "xdg-desktop-icon install --novendor dcomposer.desktop"

uninstall:
	rm  -f $(BINDIR)/$(TARGET)
	rm -Rf $(prefix)/share/$(TARGET)/
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


.PHONY:  all install uninstall clean
