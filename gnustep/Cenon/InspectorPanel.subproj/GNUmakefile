# GNUmakefile: makefile for the Inspector subproject
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

OBJCFLAGS += -Wall -I..
ADDITIONAL_INCLUDE_DIRS += -I..

#
# We are creating a subproject
#
SUBPROJECT_NAME = InspectorPanel
InspectorPanel_HAS_RESOURCE_BUNDLE = yes

InspectorPanel_LANGUAGES = English German

InspectorPanel_HEADERS = \
    IPAccText.h IPAllAcc.h \
    IPAllStrokeWidth.h IPAllFilling.h SliderBox.h \
    IPAllLayers.h IPLayerCell.h \
    InspectorPanel.h IPArc.h IPBasicLevel.h IPCrosshairs.h \
    IPCurve.h IPGroup.h IPImage.h IPLine.h IPLine3D.h IPPolyLine.m \
    IPMark.h IPPath.h \
    IPRectangle.h IPThread.h IPText.h IPWeb.h IPTextPath.h IPSinking.h

InspectorPanel_OBJC_FILES = \
    IPAccText.m IPAllAcc.m \
    IPAllStrokeWidth.m IPAllFilling.m SliderBox.m \
    IPAllLayers.m IPLayerCell.m \
    InspectorPanel.m IPArc.m IPBasicLevel.m IPCrosshairs.m \
    IPCurve.m IPGroup.m IPImage.m IPLine.m IPLine3D.m IPPolyLine.m \
    IPMark.m IPPath.m \
    IPRectangle.m IPThread.m IPText.m IPWeb.m IPTextPath.m IPSinking.m

InspectorPanel_C_FILES = 

InspectorPanel_RESOURCE_FILES = InspectorPanel.nib button*.tiff ip*.tiff

InspectorPanel_LOCALIZED_RESOURCE_FILES = \
    IPAllFilling.nib IPAllLayers.nib IPAllStrokeWidth.nib \
    IPAccText.nib IPAllAcc.nib \
    IPArc.nib IPCrosshairs.nib IPCurve.nib IPGroup.nib \
    IPImage.nib IPLine.nib IPLine3D.nib IPPolyLine.nib \
    IPMark.nib \
    IPPath.nib IPRectangle.nib  IPThread.nib IPText.nib \
    IPWeb.nib IPTextPath.nib IPSinking.nib

InspectorPanel_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
