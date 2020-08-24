# GNUmakefile: makefile for Cenon
#
# Copyright (C) 2000-2013 by vhf interservice GmbH
# Author:   Georg Fleischmann
#
# modified: 2013-02-13 (Vectorizer.m added)
#           2011-12-03 (ICUTImportSub.m, h added)
#           2011-04-06 (Vectorizer.xib added)
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

GNUSTEP_INSTALLATION_DOMAIN=LOCAL
#GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_LOCAL_ROOT)
#GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Makefiles

include $(GNUSTEP_MAKEFILES)/common.make

# packages (RPM)
PACKAGE_NAME = Cenon
VERSION = 4.0.2


APP_NAME = Cenon

SUBPROJECTS =

Cenon_LANGUAGES = English German

Cenon_SUBPROJECTS = \
    GraphicObjects.subproj \
    graphicsUndo.subproj undo.subproj InspectorPanel.subproj \
    PreferencesPanel.subproj ProjectSettingsPanel.subproj \
    TransformPanel.subproj \
    VHFImport VHFExport VHFShared

Cenon_OBJC_FILES = \
    Cenon_main.m apContour.m App.m \
    GridPanel.m WorkingAreaPanel.m IntersectionPanel.m \
    TilePanel.m TileObject.m \
    DocView.m dvDrag.m dvGrid.m dvHiddenArea.m \
    dvPasteboard.m dvTile.m dvUndo.m \
    Document.m DocWindow.m FlippedView.m TileScrollView.m \
    LayerObject.m LayerDetailsController.m \
    MoveCell.m MoveMatrix.m MyPageLayout.m propertyList.m \
    ProgressIndicator.m \
    DXFImportSub.m GerberImportSub.m HPGLImportSub.m PSImportSub.m DINImportSub.m \
    ICUTImportSub.m SVGImportSub.m \
    Type1Import.m Type1ImportSub.m Type1Font.m type1Funs.m \
    DXFExportSub.m GerberExportSub.m HPGLExportSub.m EPSExport.m \
    Vectorizer.m \
    functions.m \
    gdb_support.m

Cenon_PRINCIPAL_CLASS = App

Cenon_C_FILES = 

Cenon_HEADER_FILES = App.h \
    Inspectors.h Graphics.h PreferencePanels.h \
    Document.h DocView.h DocWindow.h \
    fastMath.h debug.h FlippedView.h \
    DXFImportSub.h GerberImportSub.h HPGLImportSub.h PSImportSub.h DINImportSub.h \
    ICUTImportSub.h SVGImportSub.h \
    Type1Import.h Type1ImportSub.h Type1Font.h type1Funs.h standardEncoding.h \
    EPSExport.h \
    LayerObject.h LayerDetailsController.h locations.h messages.h MoveCell.h\
    WorkingAreaPanel.h GridPanel.h IntersectionPanel.h \
    MoveMatrix.h MyPageLayout.h propertyList.h \
    ProgressIndicator.h \
    TileObject.h TileScrollView.h \
    functions.h

Cenon_RESOURCE_FILES = Icons/*.tiff \
    VHFImport/*.prolog VHFImport/*.trailer \
    CharConversion CropMarks \
    SinkingMetrics.plist \
    ToolPanel.xib Info.xib \
    InspectorPanel.subproj/button*.tiff InspectorPanel.subproj/ip*.tiff \
    PreferencesPanel.subproj/General.bproj/General.prefs \
    PreferencesPanel.subproj/Import.bproj/Import.prefs \
    PreferencesPanel.subproj/Export.bproj/Export.prefs

Cenon_LOCALIZED_RESOURCE_FILES = \
    Contour.nib Document.nib Main.xib \
    PrintPanelAccessory.nib \
    TilePanel.nib WorkingAreaPanel.nib \
    IntersectionPanel.nib GridPanel.nib LayerDetails.nib \
    Localizable.strings Operations.strings \
    Vectorizer.xib

include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
