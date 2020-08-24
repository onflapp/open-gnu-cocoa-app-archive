/* App.h
 * Application class of the Cenon project
 *
 * Copyright (C) 1995-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1995-08-10
 * modified: 2011-03-06 (TOOL2D_WEB and TOOL2D_Mark exchanged)
 *           2010-05-19 (-showWebPage:)
 *           2010-01-12 (-takeSnapshot:/-restoreSnapshot:)
 *           2008-07-30 (-projectSettingsPanel)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_APP
#define VHF_H_APP

#include <AppKit/AppKit.h>
#include <VHFShared/types.h>
//#include "MyPageLayout.h"   // FIXME
#include "Document.h"

/* 2D tools */
#define TOOL_ARROW       0
#define TOOL2D_ROTATE    1
#define TOOL2D_SCISSOR   2
#define TOOL2D_ADDPOINT  3
#define TOOL2D_SINKING   4  // CAM
#define TOOL2D_THREAD    5  // CAM
#define TOOL2D_WEB       6  // CAM
#define TOOL2D_LINE      7
#define TOOL2D_POLYLINE  8
#define TOOL2D_ARC       9
#define TOOL2D_RECT     10
#define TOOL2D_CURVE    11
#define TOOL2D_TEXT     12
#define TOOL2D_MARK     13
#define TOOL2D_PATH     14

/* Menu tags / index+1 (used to add menu items) */
typedef enum
{
    MENU_INFO     = 1,  // Info / Cenon
    MENU_DOCUMENT = 2,  // Document / File
    MENU_EDIT     = 3,
    MENU_FORMAT   = 4,
    MENU_TOOLS    = 5,
    MENU_DISPLAY  = 6,
    MENU_WINDOW   = 7,
    MENU_HELP     = 8,
    MENU_PRINT    = 8,  // OpenStep and GNUstep only
    MENU_HIDE     = 9,  // OpenStep and GNUstep only
    MENU_QUIT     = 10  // OpenStep and GNUstep only
} CenonMenuItems;
/*#define	MENU_INFO        1
#define	MENU_DOCUMENT    2
#define	MENU_EDIT        3
#define	MENU_FORMAT      4
#define	MENU_TOOLS       5
#define	MENU_DISPLAY     6
#define	MENU_WINDOW      7
#define	MENU_HELP        8
#define	MENU_PRINT       8
#define	MENU_HIDE        9
#define	MENU_QUIT       10*/

#define InfoPanelWillDisplay	@"InfoPanelWillDisplay"
#define ToolPanelWillDisplay	@"ToolPanelWillDisplay"

@interface App : NSApplication
{
    /* info panel */
    NSPanel	*infoPanel;
    id		infoVersionNo;          // version number "3.9.0"
    id		kindOfVersion;          // "Free Software", "Demo", "Licensed"
    id		serialNumber;           // "020001"

    id		helpPanel;
    id		inspectorPanel;
    id		transformPanel;
    id		preferencesPanel;
    id		projectSettingsPanel;	// the project settings panel
    id		toolPanel;              // the tool panel
    id		tilePanel;
    id		gridPanel;
    id		workingAreaPanel;
    id		intersectionPanel;

    Document        *document;          // last opened document
    int             activeWindowNum;    // active document window set by -setActiveDocWindow:
    Document        *fixedDocument;     // used from -setCurrentDocument
    NSMutableArray	*modules;           // list of our loaded modules
    int             current2DTool;      // the tag of the current 2D tool

    /* accessories (Open-Panel, Save-Panel, Print-Panel) */
    id          openPanelAccessory; // the Open Panel Accessory PS/HPGL/Gerber view
    id          opaMatrix;
    id          savePanelAccessory; // Save Panel Accessory
    id          spaFormatPopUp;
    id          printPanelAccessory;
    id          ppaRadio;

    int		appIsRunning;
    BOOL	haveOpenedDocument;	// whether we have opened a document

    BOOL	command;
    BOOL	control;
    BOOL	alternate;
    BOOL	shift;

    /* import accessories */
    id          importASCIIAccessory;   // deprecated, ready to be removed
    id          iaaRadio;               // deprecated, ready to be removed
    id          iaaPopup;               // deprecated, ready to be removed
    id          importAccessory;
    id          iaPopup;

    /* contour panel */
    int		contourUnit;
    id		contourPanel;
    id		contourField;
    id		contourSlider;
    id		contourUnitPopup;
    id		contourSwitchMatrix;
}

void getAppDirectory(char *appDirectory);

- init;

- (NSArray*)modules;
- (NSString *)currentDirectory;
- (void)setCurrentDocument:(Document*)docu;
- (void)setActiveDocWindow:(DocWindow*)win;
- (Document*)currentDocument;	// document from main window
- (Document*)openedDocument;	// last opened document
- (Document*)documentInWindow:(NSWindow*)window;

- (NSOpenPanel*)openPanel;
- (NSSavePanel*)saveAsPanel;
- (NSSavePanel*)saveAsPanelWithSaveType:(NSString*)ext;

- (NSView*)printPanelAccessory;
- (id)ppaRadio;

/* Snapshots */
- (void)takeSnapshot:sender;
- (void)restoreSnapshot:sender;

/* info panel */
- (void)displayInfo;
- (void)showInfo:sender;
- (NSString*)version;       // 3.9.2
- (NSString*)compileDate;   // 2010-06-28
- (id)infoVersionText;
- (id)infoSerialText;

- (void)checkForUpdate:sender;

- (void)showPrefsPanel:sender;
- (id)preferencesPanel;
- (void)showWebPage:(id)sender;
//- (void)showHelp:sender;
- (void)showInspectorPanel:sender;
- (id)inspectorPanel;
- (void)showTransformPanel:sender;
- (void)showVectorizer:sender;
- (void)showProjectSettingsPanel:sender;
- (id)projectSettingsPanel;
- (void)showTilePanel:sender;
- (id)tilePanel;
- (void)runGridPanel:sender;
- (id)gridPanel;
- (void)showWorkingAreaPanel:sender;
- (void)showIntersectionPanel:sender;

//- (FontPageLayout *)pageLayout;

- (NSString *)appDirectory;

- (void)new:sender;
- (id)listFromFile:(NSString*)fileName;
- (NSArray*)listFromPSFile:(NSString*)fileName;
- (BOOL)openFile:(NSString *)fileName;
- (void)import:sender;
//- (void)importASCII:sender;   // moved to CAM module
- (void)openDocument:sender;
- (void)changeOpenLocation:(id)sender;
- (void)save:sender;
- (void)saveAs:sender;
- (void)changeSaveType:sender;
- (void)revertToSaved:sender;

- (int)application:app openFile:(NSString *)path;

/* Tool Panel */
- (NSPanel*)toolPanel;                  // return tool panel
- (void)showToolPanel:sender;
- (void)displayToolPanel:(BOOL)flag;
- (void)setCurrent2DTool:sender;
- (int)current2DTool;

- (void)terminate:(id)sender;

- (BOOL)command;
- (BOOL)control;
- (BOOL)alternate;

- (void)sendEvent:(NSEvent *)event;
- (BOOL)windowShouldClose:(id)sender;

@end


/* Contour
 */
@interface App(Contour)
- showContourPanel:sender;
- contourPanel;
- (void)updateContourPanel:sender;
- (void)doContourPanel:sender;
- (void)okContourPanel:sender;
- (float)contour;
- (BOOL)contourUseRaster;
- (BOOL)contourRemoveSource;
@end

#endif // VHF_H_APP
