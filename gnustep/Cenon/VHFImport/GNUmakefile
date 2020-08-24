# GNUmakefile: makefile for the VHFImport subproject
#
# Copyright (C) 2002-2011 by vhf interservice GmbH
# Author:   Georg Fleischmann
#
# modified: 2011-12-03 (ICUTImport.m, h added)
#
# This file is part of the vhf Import/Export Library.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the vhf Public License as
# published by the vhf interservice GmbH. Among other things,
# the License requires that the copyright notices and this notice
# be preserved on all copies.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the vhf Public License for more details.
#
# You should have received a copy of the vhf Public License along
# with this library; see the file LICENSE. If not, write to vhf.
#
# If you want to link this library to your proprietary software,
# or for other uses which are not covered by the definitions
# laid down in the vhf Public License, vhf also offers a proprietary
# license scheme. See the vhf internet pages or ask for details.
#
# vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
# eMail: info@vhf.de
# http://www.vhf.de

include $(GNUSTEP_MAKEFILES)/common.make

OBJCFLAGS += -Wall
ADDITIONAL_INCLUDE_DIRS += -I..

#
# We are creating a subproject
#
SUBPROJECT_NAME = VHFImport

#
# Header files
#

VHFImport_HEADERS= \
PSImport.h \
DINImport.h \
DXFImport.h \
dxfColorTable.h \
GerberImport.h \
HPGLImport.h \
ICUTImport.h \
SVGImport.h
#types.h
#vhfCFGFunctions.h
#VHFDictionaryAdditions.h
#VHFScannerAdditions.h
#VHFStringAdditions.h
#vhf2DFunctions.h

#
# Class files
#

VHFImport_OBJC_FILES= \
PSImport.m \
DINImport.m \
DXFImport.m \
GerberImport.m \
HPGLImport.m \
ICUTImport.m \
SVGImport.m
#../Shared/vhfCFGFunctions.m
#VHFDictionaryAdditions.m
#VHFScannerAdditions.m
#VHFStringAdditions.m
#vhf2DFunctions.m

VHFImport_C_FILES = 

#
# Resource files
#

VHFImport_RESOURCE_FILES= \
psImport.prolog \
psImportAI3.prolog \
psImportAI3.trailer

VHFImport_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
