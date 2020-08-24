/*
 * vhfCommonFunctions.h
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:  Georg Fleischmann
 *
 * created:  1996-01-25
 * modified: 2012-06-22 (pathForNameInPaths() added, vhfBundleLibrary() added)
 *           2012-02-06 (vhfUserDocuments())
 *           2005-12-21 (sortPopup() declaration)
 *
 * This file is part of the vhf Shared Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_COMMONFUNCTIONS
#define VHF_H_COMMONFUNCTIONS

#include <AppKit/AppKit.h>	// sortPopup()
#include "types.h"

/* Timers used to automatically scroll when the mouse is
 * outside the drawing view and not moving.
 */
#define StartTimer(inTimerLoop) if (!inTimerLoop) { [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.01]; inTimerLoop=YES; }
#define StopTimer(inTimerLoop)  if ( inTimerLoop) { [NSEvent stopPeriodicEvents]; inTimerLoop=NO; }

void		sortPopup(NSPopUpButton *popupButton, int startIx);

NSString	*stringWithConvertedChars(NSString *string, NSDictionary *conversionDict);

void		checkPoint(NSPoint p);

NSString 	*vhfLocalLibrary (NSString *append);    // "/Library/append"
NSString 	*vhfUserLibrary  (NSString *append);    // "$HOME/Library/append"
NSString 	*vhfUserDocuments(NSString *append);    // "$HOME/Documents/append"
NSString    *vhfBundleLibrary(NSBundle *bundle, NSString* append);   // BUNDLE/...Resources/Library/append
NSString	*vhfHomeDirectory(void);	// deprecated !
NSString	*vhfPathWithPathComponents(NSString *seg1, ...);
NSString    *vhfFilePathForNamesInPaths(id name, NSString *path1, ...);

NSString	*buildDecimalString(float value, VHFLimits limits, int digits);
NSString	*buildRoundedString(float value, float limitL, float limitH);
NSString	*vhfStringWithFloat(float value);
NSString	*vhfStringWithDouble(double value);
double      vhfModulo(double v, double denom);
void		sortValues(double *array, int cnt);
void		vhfExchangeValues(void *v1, void *v2, char type);

#if 0
/* this one works with width/height == 0 */
static __inline__ NSRect VHFUnionRect(NSRect r1, NSRect r2)
{   NSRect	r;

    r.origin.x = Min(r1.origin.x, r2.origin.x);
    r.origin.y = Min(r1.origin.y, r2.origin.y);
    r.size.width  = Max(r1.origin.x+r1.size.width,  r2.origin.x+r2.size.width)  - r.origin.x;
    r.size.height = Max(r1.origin.y+r1.size.height, r2.origin.y+r2.size.height) - r.origin.y;
    return r;
}
#endif

#endif	// VHF_H_COMMONFUNCTIONS
