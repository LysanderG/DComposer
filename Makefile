#Hopefully this Makefile will build DComposer.
#Wish me luck

# ok whats th diff := and =?
DC := dmd


dsources = src/*.d

inc_paths = -I/usr/include/d
libs = -L-lgtkdsv -L-lgtkd -L-lvte -L-lutil

DFLAGS = -J. -D -Dddocs -gc -debug -w -ofdcomposer

ifeq ("Linux", uname)
	libs = $(libs) -L-ldl
endif


default : xdcomposer
	@echo hello


xdcomposer : 
	@echo Building dcomposer 
	@echo cmd : $(DC) $(DFLAGS) $(xdsources) $(inc_paths) $(lib_paths) $(libs) 
	@echo
	$(DC) $(DFLAGS) $(dsources) $(inc_paths) $(lib_paths) $(libs) 

$(sources):
