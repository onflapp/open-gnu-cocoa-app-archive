include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=ColorTune
BUNDLE_NAME= ColorTune
BUNDLE_EXTENSION=.bundle

ColorTune_OBJC_FILES= ColorTuner.m TonePanelCtrl.m ColorToneView.m

ColorTune_C_FILES= colorEnhance.c

ColorTune_HEADER_FILES= ColorTuner.h TonePanelCtrl.h ColorTunerView.h colorEnhance.h

ColorTune_RESOURCE_FILES=ColorTune.gorm

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
