# GNUmakefile: makefile for the Graphic Objects subproject
#
# Copyright (C) 2000-2011 by vhf interservice GmbH
# Author:   Georg Fleischmann
#
# modified: 2011-04-05 (VCurveFit.m, h added)
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
SUBPROJECT_NAME = GraphicObjects

GraphicObjects_HEADERS = \
    VArc.h ClipRectangle.h VCrosshairs.h \
    VCurve.h VCurveFit.h VGraphic.h VGroup.h \
    VImage.h VLine.h VLine3D.h VPolyLine.h VMark.h \
    VPath.h HiddenArea.h PathContour.h VRectangle.h \
    VText.h VTextPath.h \
    VWeb.h VSinking.h VThread.h \
    PerformanceMap.h

GraphicObjects_OBJC_FILES = \
    VArc.m ClipRectangle.m VCrosshairs.m \
    VCurve.m VCurveFit.m VGraphic.m \
    VGroup.m VImage.m VLine.m VLine3D.m VPolyLine.m VMark.m \
    VPath.m HiddenArea.m PathContour.m VRectangle.m \
    VText.m VTextPath.m \
    VWeb.m VSinking.m VThread.m \
    PerformanceMap.m

GraphicObjects_C_FILES = 
GraphicObjects_RESOURCE_FILES = 
GraphicObjects_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble

