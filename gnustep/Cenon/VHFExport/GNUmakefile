# GNUmakefile: makefile for the VHFExport subproject
#
# Copyright (C) 2002-2009 by vhf interservice GmbH
# Author:   Georg Fleischmann
#
# modified: 2009-06-19
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

#
# We are creating a subproject
#
SUBPROJECT_NAME = VHFExport

#
# Header files
#

VHFExport_HEADERS= \
DXFExport.h \
dxfColorTable.h \
GerberExport.h \
HPGLExport.h
#types.h
#VHFDictionaryAdditions.h
#VHFScannerAdditions.h
#VHFStringAdditions.h

#
# Class files
#

VHFExport_OBJC_FILES= \
DXFExport.m \
GerberExport.m \
HPGLExport.m
#VHFDictionaryAdditions.m
#VHFScannerAdditions.m
#VHFStringAdditions.m

VHFImport_C_FILES = 

#
# Resource files
#

VHFExport_RESOURCE_FILES= 

VHFExport_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
