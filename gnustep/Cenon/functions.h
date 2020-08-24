/* functions.h
 * Common Cenon functions
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-25
 * modified: 2012-01-05 (NSMenuItem)
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

#ifndef VHF_H_FUNCTIONS
#define VHF_H_FUNCTIONS

#include <AppKit/AppKit.h>

typedef enum
{
    UNIT_MM      = 0,	// millimeter       internal x 25.4 / 72
    UNIT_INCH    = 1,	// inch             internal x  1 / 72
    UNIT_POINT   = 2, 	// 1/72 inch        internal x  1
    UNIT_NONE    = -1   // use preferences
} CenonUnit;

NSString *localLibrary(void);
NSString *userLibrary(void);
NSString *localBundlePath(void);
NSString *systemBundlePath(void);
NSString *userBundlePath(void);

void fillPopup(NSPopUpButton *popupButton, NSString *folder, NSString *ext, int removeIx, BOOL searchSubFolders);
NSDictionary *dictionaryFromFolder(NSString *folder, NSString *name);

BOOL vhfUpdateMenuItem(NSMenuItem *menuItem, NSString *zeroItem, NSString *oneItem, BOOL state);

/* functions using base unit from 'unit' default */
float convertToUnit(float value);   // DEPRECATED: use [document convertToUnit:]
float convertFromUnit(float value); // DEPRECATED: use [document convertFrUnit:]
float convertMMToUnit(float value); // DEPRECATED: use [document convertMMToUnit:]
float convertUnitToMM(float value); // DEPRECATED: use [document convertUnitToMM:]

/* functions using base unit from parameter */
//float convertToUnit  (float value, CenonUnit unit);
//float convertFromUnit(float value, CenonUnit unit);
/* return factor for base unit * num/denom */
//float factorToUnit  (CenonUnit unit, int num, int denom);
//float factorFromUnit(CenonUnit unit, int num, int denom);

NSString *vhfStringFromRGBColor(NSColor *color);
NSColor  *vhfRGBColorFromString(NSString *string);

#endif	// VHF_H_FUNCTIONS
