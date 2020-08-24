# GNUmakefile: makefile for PreferencesPanel
#
# Copyright (C) 2000-2013 by vhf interservice GmbH
# Author:   Georg Fleischmann
#
# modified: 2013-04-11 (nib -> xib)
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
ADDITIONAL_INCLUDE_DIRS += -I..

#
# We are creating a subproject
#
SUBPROJECT_NAME = PreferencesPanel

SUBPROJECTS = \
    General.bproj Import.bproj Export.bproj

PreferencesPanel_HAS_RESOURCE_BUNDLE = yes

PreferencesPanel_LANGUAGES = English German

PreferencesPanel_HEADERS = PreferencesPanel.h
	       
PreferencesPanel_OBJC_FILES = PreferencesPanel.m

PreferencesPanel_C_FILES = 

PreferencesPanel_RESOURCE_FILES = 

PreferencesPanel_LOCALIZED_RESOURCE_FILES = \
    PreferencesPanel.xib

PreferencesPanel_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
