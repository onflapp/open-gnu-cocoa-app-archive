# GNUmakefile: makefile for the TransformPanel subproject
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
SUBPROJECT_NAME = TransformPanel
TransformPanel_HAS_RESOURCE_BUNDLE = yes

TransformPanel_LANGUAGES = English German

TransformPanel_HEADERS = \
    TPBasicLevel.h TPAlign.h TPMove.h TPMix.hTPScale.h TPRotate.h TransformPanel.h

TransformPanel_OBJC_FILES = \
    TPBasicLevel.m TPAlign.m TPMove.m TPMix.m TPScale.m TPRotate.m TransformPanel.m

TransformPanel_C_FILES = 

TransformPanel_RESOURCE_FILES = 

TransformPanel_LOCALIZED_RESOURCE_FILES = \
    TPAlign.nib TPMix.nib TPMove.nib TPRotate.nib TPScale.nib \
    TransformPanel.nib

TransformPanel_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
