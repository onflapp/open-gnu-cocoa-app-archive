# GNUmakefile: makefile for the graphics undo subproject
#
# Copyright (C) 2000-2011 by vhf interservice GmbH
# Author:   Georg Fleischmann
#
# modified: 2011-05-30 (NameGraphicsChange.m, h -> LabelGraphicsChange.m, h)
#           2011-05-28 (ExcludeGraphicsChange.m, h added)
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
SUBPROJECT_NAME = graphicsUndo

graphicsUndo_HEADERS = \
    AddPointGraphicsChange.h \
    AlignGraphicsChange.h AngleGraphicsChange.h \
    BringToFrontGraphicsChange.h ChangeDetail.h \
    ColorGraphicsChange.h ContourGraphicsChange.h \
    CreateGraphicsChange.h CutGraphicsChange.h \
    DeleteGraphicsChange.h DimensionsGraphicsChange.h \
    DragPointGraphicsChange.h drawundo.h EndEditingGraphicsChange.h \
    FillGraphicsChange.h GraphicsChange.h GroupGraphicsChange.h \
    JoinGraphicsChange.h LengthGraphicsChange.h \
    LocalizableStringsForGraphicsUndo.h \
    ExcludeGraphicsChange.h LockGraphicsChange.h \
    MirrorGraphicsChange.h MixGraphicsChange.h \
    MoveGraphicsChange.h MoveLayerGraphicsChange.h MovePointGraphicsChange.h \
    LabelGraphicsChange.h \
    PasteGraphicsChange.h PunchGraphicsChange.h \
    RadialCenterGraphicsChange.h RadiusGraphicsChange.h \
    RemovePointGraphicsChange.h ReorderGraphicsChange.h \
    RotateGraphicsChange.h ScaleGraphicsChange.h \
    SendToBackGraphicsChange.h SimpleGraphicsChange.h \
    SplitGraphicsChange.h StepWidthGraphicsChange.h \
    UngroupGraphicsChange.h WidthGraphicsChange.h

graphicsUndo_OBJC_FILES = \
    AddPointGraphicsChange.m \
    AlignGraphicsChange.m AngleGraphicsChange.m\
    BringToFrontGraphicsChange.m ChangeDetail.m\
    ColorGraphicsChange.m ContourGraphicsChange.m\
    CreateGraphicsChange.m CutGraphicsChange.m\
    DeleteGraphicsChange.m DimensionsGraphicsChange.m\
    DragPointGraphicsChange.m EndEditingGraphicsChange.m\
    FillGraphicsChange.m GraphicsChange.m GroupGraphicsChange.m\
    JoinGraphicsChange.m LengthGraphicsChange.m \
    ExcludeGraphicsChange.m LockGraphicsChange.m \
    MirrorGraphicsChange.m MixGraphicsChange.m \
    MoveGraphicsChange.m MoveLayerGraphicsChange.m MovePointGraphicsChange.m \
    LabelGraphicsChange.m \
    PasteGraphicsChange.m PunchGraphicsChange.m \
    RadialCenterGraphicsChange.m RadiusGraphicsChange.m \
    RemovePointGraphicsChange.m ReorderGraphicsChange.m \
    RotateGraphicsChange.m ScaleGraphicsChange.m \
    SendToBackGraphicsChange.m SimpleGraphicsChange.m \
    SplitGraphicsChange.m  StepWidthGraphicsChange.m \
    UngroupGraphicsChange.m WidthGraphicsChange.m

graphicsUndo_C_FILES = 

graphicsUndo_RESOURCE_FILES = 

graphicsUndo_PRINCIPAL_CLASS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble

