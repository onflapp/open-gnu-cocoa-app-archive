/* VGraphic.h
 * Graphic object - root class
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-01-29
 * modified: 2011-05-28 (isExclude, -isExcluded, -setExcluded:)
 *           2011-04-06 (-drawStartAtScale: added)
 *           2010-07-28 (label, -setLabel:, -label added)
 *           2008-12-01 (reliefFlatness)
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

#ifndef VHF_H_VGRAPHICS
#define VHF_H_VGRAPHICS

#include <math.h>
#include <VHFShared/types.h>
#include <VHFShared/vhf2DFunctions.h>
#include <VHFShared/vhfCompatibility.h>
#include <VHFShared/vhfCommonFunctions.h>
#include <VHFShared/VHFDictionaryAdditions.h>
#include <VHFShared/VHFStringAdditions.h>
#include <VHFShared/vhfSoundFunctions.h>
#include "../debug.h"
#include "../propertyList.h"

@interface VGraphic:NSObject
{
    NSMutableArray	*pmList;    // list of segments in performance map we are in

    NSString    *label;         // label of the object
    NSColor		*color;         // our color
    float		width;          // our width
    BOOL		isSelected;     // YES = object is selected
    BOOL		isDirectionCCW; // YES = direction is counter clock wise
    BOOL		isLocked;       // YES = our position is fix
    BOOL		isExcluded;     // YES = exclude from processing (ex. manufacturing)
    BOOL		dirty;          // whether we need a recalculation of the output

    id			outputStream;   // output stream (eg. CAM Module)
    BOOL		relief;         // Relief: wheather we create a relief during output
    int			reliefType;     // Relief: linear, logarithmic, arc
    int			reliefDirection;// Relief: horicontal vertical both
    float		reliefFlatness; // Relief: flattness in % to toolWidth
}

/* class methods
 */
+ (float)maxKnobSizeWithScale:(float)scaleFactor;
+ (void)showFastKnobFills;
+ (void)initialize;
+ (VGraphic*)graphic;
+ currentView;
+ currentWindow;

+ (NSArray*)objectsOfClass:(Class)cls inArray:(NSArray*)array;

/* methods
 */
- (id)init;
- (id)copy;
- (NSString *)title;

- (NSMutableArray*)pmList;			// segment list

- (BOOL)isSelected;
- (void)setSelected:(BOOL)flag;
- (int)selectedKnobIndex;

- (void)setLabel:(NSString*)newLabel;
- (NSString*)label;

- (NSColor*)color;
- (void)setColor:(NSColor *)col;
- (NSColor*)separationColor:(NSColor *)col;

- (float)width;
- (void)setWidth_ptr:(float*)w;
- (void)setWidth:(float)w;

- (float)length;
- (void)setLength:(float)l;

- (float)radius;
- (void)setRadius:(float)r;

- (void)setSize:(NSSize)size;
- (NSSize)size;

- (BOOL)isExcluded;
- (void)setExcluded:(BOOL)flag;

- (BOOL)isLocked;
- (void)setLocked:(BOOL)l;

- (float)angle;

- (BOOL)filled;
- (void)setFilled:(BOOL)flag;

- (NSPoint)gradientAt:(float)t;
- (NSPoint)center;

- (id)parallelObject:(NSPoint)begO :(NSPoint)endO :(NSPoint)beg :(NSPoint)end;

- (BOOL)create:(NSEvent *)event in:view;

- (float)rotAngle;
- (void)drawAtAngle:(float)angle in:view;
- (void)drawAtAngle:(float)angle withCenter:(NSPoint)cp in:view;
- (void)rotate:(float)angle;
- (void)setAngle:(float)angle withCenter:(NSPoint)cp;
- (void)transform:(NSAffineTransform*)matrix;
- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp;
- (void)mirror;
- (void)mirrorAround:(NSPoint)p;
- (void)changeDirection;

- (void)drawColorPale:(BOOL)drawPale;
- (void)drawWithPrincipal:principal;
- (void)drawControls:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor;   // knobs and control lines
- (void)drawKnobs:(NSRect)rect direct:(BOOL)direct scaleFactor:(float)scaleFactor;      // knobs only

- (BOOL)isDirectionCCW;
- (void)drawDirectionAtScale:(float)scaleFactor;
- (void)drawStartAtScale:(float)scaleFactor;

- (NSRect)coordBounds;                      // exact bounds of coordinates (no width)
- (NSRect)bounds;                           // bounds including width and vertices (never zero)
- (NSRect)extendedBoundsWithScale:(float)scaleFactor;		// bounds including width and knobs
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp;
- (NSRect)maximumBounds;                    // bounds including rotation

- (NSRect)scrollRect:(int)pt_num inView:(id)aView;
- (void)constrainPoint:(NSPoint*)aPt andNumber:(int)pt_num toView:aView;

- (void)movePoint:(int)pt_num to:(NSPoint)p;
- (void)movePoint:(int)pt_num by:(NSPoint)pt;
- (void)moveBy_ptr:(NSPoint*)pt;            // for use with perform object...
- (void)moveBy:(NSPoint)pt;
- (void)moveTo:(NSPoint)p;
- (NSPoint)pointAt:(float)t;
- (void)getPoint:(NSPoint*)p at:(float)t;   // old, don't use!
- (int)numPoints;
- (NSPoint)pointWithNum:(int)pt_num;
- (void)getPoint:(int)pt_num :(NSPoint*)pt; // old, don't use!

- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize;
- (BOOL)hitControl:(NSPoint)p :(int *)pt_num controlSize:(float)controlsize;
- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz;

- (id)contour:(float)w;
- (id)shape;
- (id)flattenedObject;
- (NSMutableArray*)getListOfObjectsSplittedFromGraphic:g;
- (NSMutableArray*)getListOfObjectsSplittedFrom:(NSPoint*)pArray :(int)iCnt;
- (NSMutableArray*)getListOfObjectsSplittedAtPoint:(NSPoint)pt;
- (BOOL)isPathObject;
- (BOOL)intersectsRect:(NSRect)rect;
- (int)intersectLine:(NSPoint*)pArray :(NSPoint)pl0 :(NSPoint)pl1;
- (int)getIntersections:(NSPoint**)ppArray with:g;

- (void)getPointBeside:(NSPoint*)point :(int)left :(float)dist;
- (id)uniteWith:(VGraphic*)ug;
- (BOOL)identicalWith:(VGraphic*)g;

- (float)sqrDistanceGraphic:g :(NSPoint*)pg1 :(NSPoint*)pg2;
- (float)sqrDistanceGraphic:g;
- (float)distanceGraphic:g;

- (id)clippedWithRect:(NSRect)rect;

- (void)writeFilesToDirectory:(NSString*)directory;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (id)propertyList;
- (id)initFromPropertyList:(id)plist inDirectory:(NSString*)directory;

/* graphics has changed */
- (BOOL)isDirty;
- (void)setDirty:(BOOL)flag;

/* output */
- (void)setOutputStream:(id)stream;
- (id)outputStream;

- (void)dealloc;

@end

#endif // VHF_H_VGRAPHICS
