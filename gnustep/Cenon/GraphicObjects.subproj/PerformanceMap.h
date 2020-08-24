/* PerformanceMap.h
 * Map of graphic objects for optimized access
 *
 * Copyright (C) 1993-2012 by vhf interservice GmbH
 * Authors:  T+T Hennerich (1993), Georg Fleischmann (2001)
 *
 * created:  1993, 2001-08-17
 * modified: 2006-02-06
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

#ifndef VHF_H_PERFORMANCEMAP
#define VHF_H_PERFORMANCEMAP

#include <VHFShared/types.h>
#include "VGraphic.h"

@interface PerformanceMap: NSObject
{
    NSRect		bounds;			// bounds of segment
    NSMutableArray	*segmentList;		// if segmented: holds the list of segments
    NSMutableArray	*graphicList;		// if not segmented: holds the list of graphic objects
    int			capacity;		// maximum number of elements in this segment
    int			borderObjectCnt;	// objects which are on the border of the bounds of pm
}

- (id)initWithFrame:(NSRect)frameRect;
- (void)resizeFrame:(NSRect)newFrame initWithList:(NSArray*)glist;
- (void)sortNewInFrame:(NSRect)newFrame initWithList:(NSArray*)glist;
- (void)initList:(NSArray*)glist;

- (BOOL)isObjectInside:(VGraphic*)g;
- (void)addObject:(VGraphic*)anObject;
- (void)addObjectList:(NSArray*)aList withReferenceList:(NSArray*)referenceList;
- (void)addObject:anObject inTryNumber:(int)try1 withReferenceList:(NSArray*)referenceList; 
- (void)updateObject:(VGraphic*)anObject withReferenceList:(NSArray*)refList;
- (void)removeObject:(VGraphic*)anObject;
//- (void)shuffleObject:(id)anObject toPosition:(int)newPosition;
- (void)splitSegmentInTryNumber:(int)try1 withReferenceList:(NSArray*)referenceList;

- (VGraphic*)controlHitAtPoint:(NSPoint)point gotCornerNumber:(int*)corner :(float)controlsize;
- (VGraphic*)objectAtPoint:(NSPoint)point fuzz:(float)fuzz;
- (VGraphic*)selectedObjectAtPoint:(NSPoint)point andObjectBelow:(id*)belowObject;
- (VGraphic*)unselectedObjectAtPoint:(NSPoint)point;
- (VGraphic*)objectAtPoint:(NSPoint)point ofKind:(Class)kind fuzz:(float)fuzz;

- (void)addObjectsInContentsRect:(NSRect)rect inList:(NSMutableArray*)aList;
- (void)addObjectsInIntersectionRect:(NSRect)rect inList:(NSMutableArray*)aList;

- (void)drawInRect:(NSRect)rect principal:(id)view;
- (void)drawSegmentBoundaries;

- (NSRect)bounds;

- (void)removeAllObjects;
- (void)dealloc;

@end

#endif // VHF_H_PERFORMANCEMAP
