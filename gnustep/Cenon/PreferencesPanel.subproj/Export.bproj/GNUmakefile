# GNUmakefile: makefile for the Export Preferences bundle
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

BUNDLE_NAME = Export
BUNDLE_EXTENSION = .prefs

BUNDLE_INSTALL_DIR = none
Export_HAS_RESOURCE_BUNDLE = yes
Export_STANDARD_INSTALL= no

Export_LANGUAGES = English German

Export_RESOURCE_FILES = prefsExport.tiff

Export_LOCALIZED_RESOURCE_FILES = \
	Export.nib Localizable.strings

Export_OBJC_FILES = \
	ExportController.m

Export_HEADERS = \
	ExportController.h

Export_PRINCIPAL_CLASS = \
	ExportController

ADDITIONAL_OBJCFLAGS = -Wall
ADDITIONAL_INCLUDE_DIRS += 

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
