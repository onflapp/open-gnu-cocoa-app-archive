/* VGroup.h
 * Group of graphic objects
 *
 * Copyright (C) 1996-2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2010-07-08
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

#ifndef VHF_H_VGROUP
#define VHF_H_VGROUP

#include "VGraphic.h"

@interface VGroup:VGraphic
{
    NSMutableArray	*list;
    int			selectedObject;
    NSRect		coordBounds;    // our coord bounding box
    NSRect		bounds;         // our bounding box

    BOOL		uniColoring;    // YES = all graphics in Group have the same colors
    int			filled;         // 1 = fill, 2 = graduated filled
    NSColor		*fillColor;     // fillColor if we are filled
    NSColor		*endColor;      // endColor if we are graduated/radial filled
    float		graduateAngle;  // angle of graduate filling
    float		stepWidth;      // stepWidth the color will change by graduate/radial filling
    NSPoint		radialCenter;   // the center position for radial filling in percent to the bounds
}

+ (VGroup*)group;

/* group methods
 */
- initWithList:(NSArray*)list;
- initWithFile:(NSString*)file;
- (void)deselectAll;
- (void)setColorNew;
- (BOOL)uniColored;
- (void)setFilled:(BOOL)flag;
- (NSColor*)fillColor;
- (void)setFillColor:(NSColor*)col;
- (NSColor*)endColor;
- (void)setEndColor:(NSColor*)col;
- (float)graduateAngle;
- (void)setGraduateAngle:(float)a;
- (void)setStepWidth:(float)sw;
- (float)stepWidth;
- (void)setRadialCenter:(NSPoint)rc;
- (NSPoint)radialCenter;
- (void)setList:(NSArray*)aList;
- (void)addObject:(VGraphic*)g;
- (void)add:(NSArray*)addList;
- (NSMutableArray*)list;
- (unsigned)countRecursive;
- (id)recursiveObjectAtIndex:(int)ix;
- (void)recursiveRemoveObjectAtIndex:(int)ix;
- (void)recursiveInsertObject:(id)obj atIndex:(int)ix;
- (void)ungroupTo:ulist;
- (void)ungroupRecursiveTo:ulist;
/*- (void)transferSubGraphicsTo:(NSMutableArray *)array at:(int)position;*/
- (void)setSize:(NSSize)size;
- (NSSize)size;
/*- getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt;*/
- (BOOL)isPointInside:(NSPoint)p;
/*- (int)getIntersections:(NSPoint**)ppArray with:g;*/
/*- uniteWith:(VGraphic*)ug;*/

- (void)movePoint:(int)pt_num to:(NSPoint)p control:(BOOL)control;

@end

#endif // VHF_H_VGROUP
