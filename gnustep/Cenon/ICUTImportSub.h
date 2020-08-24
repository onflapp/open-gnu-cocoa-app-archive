/* ICUTImportSub.m
 * Subclass of icut import
 *
 * Copyright (C) 2011-2012 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2011-09-16
 * modified: 2012-06-22 (shape added, any layer with names possible)
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

#ifndef VHF_H_ICUTIMPORTSUB
#define VHF_H_ICUTIMPORTSUB

#include <AppKit/AppKit.h>
#include <VHFImport/ICUTImport.h>

@interface ICUTImportSub:ICUTImport
{
    NSMutableArray  *layerList;
}

/* subclassed from super class
 */
- allocateList;
- (NSMutableArray*)layerArrayWithName:(NSString*)name;
- (void)addFillList:aList toLayer:(NSString*)layerName;
- (void)addFillList:aList toList:(NSMutableArray*)bList;
- (void)addStrokeList:(NSArray*)aList toLayer:(NSString*)layerName;
- (void)addStrokeList:(NSArray*)aList toList:(NSMutableArray*)bList;
- (void)addLine:(NSPoint)beg :(NSPoint)end toLayer:(NSString*)layerName;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:(NSMutableArray*)aList;
 - (void)addMark:(NSPoint)origin toLayer:(NSString*)layerName;
- (void)addMark:(NSPoint)origin toList:(NSMutableArray*)aList;
- (void)addRect:(NSPoint)origin :(NSPoint)rsize toLayer:(NSString*)layerName;
- (void)addRect:(NSPoint)origin :(NSPoint)rsize toList:(NSMutableArray*)aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toLayer:(NSString*)layerName;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:(NSMutableArray*)aList;
- (void)setBounds:(NSRect)bounds;

@end

#endif // VHF_H_ICUTIMPORTSUB
