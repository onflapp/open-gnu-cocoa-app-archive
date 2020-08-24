# GNUmakefile: makefile for the ProjectSettingsPanel subproject
#
# Copyright (C) 2000-2009 by vhf interservice GmbH
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
ADDITIONAL_INCLUDE_DIRS += -I..

#
# We are creating a subproject
#
SUBPROJECT_NAME = ProjectSettingsPanel
ProjectSettingsPanel_HAS_RESOURCE_BUNDLE = yes

ProjectSettingsPanel_LANGUAGES = English German

ProjectSettingsPanel_HEADERS = \
    ProjectSettings.h PSInfo.h PSFontInfo.h PSSettings.h

ProjectSettingsPanel_OBJC_FILES = \
    ProjectSettings.m PSInfo.m PSFontInfo.m PSSettings.m

ProjectSettingsPanel_C_FILES = 

ProjectSettingsPanel_RESOURCE_FILES = 

ProjectSettingsPanel_LOCALIZED_RESOURCE_FILES = \
    ProjectSettingsPanel.nib PSInfo.nib PSFontInfo.nib PSSettings.nib

ProjectSettingsPanel_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
