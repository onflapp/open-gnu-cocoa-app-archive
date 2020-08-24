/* TilePanel.h
 * Panel for batch production
 *
 * Copyright (C) 1996-2005 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-08-08
 * modified: 2005-10-15
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

#ifndef VHF_H_TILEPANEL
#define VHF_H_TILEPANEL

#include <AppKit/AppKit.h>

@interface TilePanel: NSPanel
{
    id	distPopup;
    id	distanceMatrix;
    id	limitsPopUp;
    id	limitsMatrix;
    id	originSwitch;
}

- (BOOL)useAbsoluteDistance;
- (NSPoint)distance;		// distance values in panel fields (either relative or absolute)
- (NSPoint)relativeDistance;	// relative distance (between parts)
- (BOOL)limitSize;
- (NSPoint)limits;
- (BOOL)mustMoveMasterToOrigin;

- (void)updatePanel:sender;
- (void)setDistancePopup:sender;
- (void)set:sender;
- (void)buildCopies:sender;
- (void)removeTiles:sender;

@end

#endif // VHF_H_TILEPANEL
