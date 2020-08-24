# GNUmakefile: makefile for the VHFShared subproject of Cenon
#
# Copyright (C) 2000-2013 by vhf interservice GmbH
# Author:   Georg Fleischmann
#
# modified: 2009-06-19
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the vhf Public License as
# published by vhf interservice GmbH. Among other things, the
# License requires that the copyright notices and this notice
# be preserved on all copies.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the vhf Public License for more details.
#
# You should have received a copy of the vhf Public License along
# with this program; see the file LICENSE. If not, write to vhf.
#
# vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
# eMail: info@vhf.de
# http://www.vhf.de

include $(GNUSTEP_MAKEFILES)/common.make

OBJCFLAGS += -Wall

#
# We are creating a subproject
#
SUBPROJECT_NAME = VHFShared

#
# Header files
#

VHFShared_HEADERS= \
types.h \
vhf2DFunctions.h \
vhfCFGFunctions.h \
vhfCompatibility.h \
vhfCommonFunctions.h \
vhfMath.h \
vhfSoundFunctions.h \
VHFArrayAdditions.h \
VHFDictionaryAdditions.h \
VHFPopUpButtonAdditions.h \
VHFScannerAdditions.h \
VHFStringAdditions.h \
VHFSystemAdditions.h

#
# Class files
#

VHFShared_OBJC_FILES= \
vhf2DFunctions.m \
vhfCFGFunctions.m \
vhfCommonFunctions.m \
vhfMath.m \
vhfSoundFunctions.m \
VHFArrayAdditions.m \
VHFDictionaryAdditions.m \
VHFPopUpButtonAdditions.m \
VHFScannerAdditions.m \
VHFStringAdditions.m \
VHFSystemAdditions.m

VHFImport_C_FILES = 

#
# Resource files
#

VHFShared_RESOURCE_FILES=

VHFShared_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
