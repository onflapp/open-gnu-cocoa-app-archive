include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = Addresses
CVS_MODULE_NAME = Addresses
VERSION = 0.4.8

SUBPROJECTS =     \
   Frameworks     \
   AddressManager     

-include GNUMakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUMakefile.postamble

after-clean::
	$(MAKE) -C Goodies clean
after-distclean::
	$(MAKE) -C Goodies distclean
goodies:
	$(MAKE) -C Goodies
goodies-install:
	$(MAKE) -C Goodies install
