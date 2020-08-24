/* GerberImportSub.m
 * Subclass of Gerber import
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-03
 * modified: 2002-07-15
 *
 * This file is part of the vhf Import Library.
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

#ifndef VHF_H_GERBERIMPORTSUB
#define VHF_H_GERBERIMPORTSUB

#include <AppKit/AppKit.h>
#include <VHFImport/GerberImport.h>

@interface GerberImportSub:GerberImport
{
}

/* subclassed from super class
 */
- allocateList; /* allocate a list */

- (void)removeClearLayers:bList;
- (void)changeListPolarity:bList bounds:(NSRect)bounds;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList;    // add a line to a list
- (void)addRect:(NSPoint)origin :(NSSize)size filled:(BOOL)fill toList:aList;       // add a rectangle to a list
- (void)addCircle:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList;    // add an circle to a list
- (void)addOctagon:(NSPoint)center :(float)radius filled:(BOOL)fill toList:aList;   // add an octagon to a list
- (void)addObround:(NSPoint)center :(float)width :(float)height filled:(BOOL)fill toList:aList;
- (void)addPolygon:(NSPoint)center :(float)width :(int)sides filled:(BOOL)fill toList:aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList; // add an arc to a list
- (void)addStrokeList:(NSArray*)aList toList:(NSMutableArray*)bList;         // receive a stroked path (group)
- (void)addFillList:(NSArray*)aList toList:(NSMutableArray*)bList; // receive a filled path (group)
- (void)addFillPath:(NSArray*)aList toList:(NSMutableArray*)bList;
- (void)moveListBy:(NSPoint)pt :aList;
- (void)setBounds:(NSRect)bounds;       // the bounds of the graphic

@end

#endif // VHF_H_GERBERIMPORTSUB
