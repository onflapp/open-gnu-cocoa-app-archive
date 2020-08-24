/* Document.h
 * Cenon document class
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1996-02-09
 * Modified: 2012-08-13 (-scale: uses NSSize)
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

#ifndef VHF_H_DOCUMENT
#define VHF_H_DOCUMENT

#include <AppKit/AppKit.h>
#include "TileScrollView.h"
#include "DocWindow.h"
#include "DocView.h"
#include "undo.subproj/undochange.h"
#include "Type1Font.h"
#include "functions.h"	// CenonUnits

/* notifications */
#define DocumentHasBeenSaved    @"DocumentHasBeenSaved" // objects should save their stuff
#define DocumentDidOpen         @"DocumentDidOpen"      // all additional init should be done

@interface Document:ChangeManager
{
    TileScrollView  *scrollView;        // the scroll view inside the window
    DocWindow       *window;            // the window
    int             magazineIndex;      // the index of the magazine we use, FIXME: move to CAM module

    id              printInfo;
    NSString        *name;              // the name of the document
    NSString        *directory;         // the directory it is in
    BOOL            dirty;              // document needs to be saved
    BOOL            haveSavedDocument;  // whether document has associated disk file
    BOOL            exportLock;         // protected documented that shouldn't be exported

    Type1Font       *fontObject;        // to allow editing Fonts

    /* project info */
    NSString        *docVersion;
    NSString        *docAuthor;
    NSString        *docCopyright;
    NSString        *docComment;

    /* project settings */
    NSMutableDictionary *docSettingsDict;   // settings
    CenonUnit           baseUnit;           // document unit of measure (mm, inch, point)
    //int               unitNum, unitDen;   // factor of base unit num/denom
}


/* class methods */

+ new;
+ newFromFile:(NSString *)fileName;
+ (NSMutableArray*)listFromFile:(NSString*)fileName;
+ newFromList:(NSMutableArray*)list;

//- (void)sizeWindow:(NSSize)size;
- (void)scale:(NSSize)scaleSize withCenter:(NSPoint)center;

- window;
- (void)resetScrollers;
- (TileScrollView*)scrollView;  // returns the scroll view
- (DocView*)documentView;       // returns the docView of the scroll view

- (void)setDirty:(BOOL)flag;
- (BOOL)dirty;                  // whether document needs to be saved
- (void)setExportLock:(BOOL)flag;
- (BOOL)exportLock;             // are we allowed to export this document ?

/* Services menu methods */
- (void)registerForServicesMenu;
- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType;
- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;

/* Document info */
- (void)setDocVersion:(NSString*)newVersion;
- (NSString*)docVersion;
- (void)setDocAuthor:(NSString*)newAuthor;
- (NSString*)docAuthor;
- (void)setDocCopyright:(NSString*)newCopy;
- (NSString*)docCopyright;
- (void)setDocComment:(NSString*)newComment;
- (NSString*)docComment;

/* Document setting */
- (NSMutableDictionary*)docSettingsDict;
- (void)setBaseUnit:(CenonUnit)unit;    // set to -1 for Preferences responsibility
- (CenonUnit)baseUnit;                  // returns unit, uses unit from Preferences (if baseUnit == -1)
- (CenonUnit)baseUnitFlat;              // returns document units or -1 for preferences responsibility
- (float)convertToUnit:(float)iValue;
- (float)convertFrUnit:(float)uValue;
- (float)convertMMToUnit:(float)mmValue;
- (float)convertUnitToMM:(float)uValue;
/* FUTURE: functions using base unit from parameter */
//+ (float)convertToUnit:(float)iValue unit:(CenonUnit)unit;
//+ (float)convertFrUnit:(float)iValue unit:(CenonUnit)unit;
/* FUTURE: return factor for base unit * num/denom */
//+ (float)factorToUnit:(CenonUnit)unit num:(int)num denom:(int)denom;
//+ (float)factorFrUnit:(CenonUnit)unit num:(int)num denom:(int)denom;

/* Document name and file handling methods */
- (NSString *)filename;     // path + name = absolute path to document
- (NSString *)directory;    // path only
- (NSString *)name;         // name only
- (void)setName:(NSString *)name andDirectory:(NSString *)directory;
- (BOOL)setName:(NSString *)name;
- (void)setTemporaryTitle:(NSString *)title;
- (BOOL)save;
- (BOOL)save:(id <NSMenuItem>)invokingMenuItem;
- (BOOL)saveAs:(id <NSMenuItem>)invokingMenuItem;

- (void)setFontObject:(Type1Font*)fontObj;

- (void)printDocument:sender;
- (void)changeLayout:sender;

/* CAM, FIXME: move to CAM category of Document */
- (void)setMagazineIndex:(int)i;
- (int)magazineIndex;

@end

#endif // VHF_H_DOCUMENT
