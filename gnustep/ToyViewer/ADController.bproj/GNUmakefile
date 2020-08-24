include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=ADController
BUNDLE_NAME= ADController
BUNDLE_EXTENSION=.bundle

ADController_OBJC_FILES= ADController.m  ADSlave.m

ADController_HEADER_FILES= ADSlave.h

ADController_RESOURCE_FILES=AutoDisplay.gorm ToyViewerS.tiff\
			    images/pause.tiff images/pauseH.tiff  \
			    images/playH.tiff images/step.tiff images/stepH.tiff  \
			    images/stop.tiff images/stopH.tiff  \
			    images/righttriangle.tiff images/lefttriangle.tiff 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
