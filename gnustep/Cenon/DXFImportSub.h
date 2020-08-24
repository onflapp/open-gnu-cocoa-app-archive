/* DXFImportSub.h
 * Subclass of DXF import for creation of graphic objects
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-02-09
 * modified: 2002-10-26
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

#ifndef VHF_H_DXFIMPORTSUB
#define VHF_H_DXFIMPORTSUB

#include <AppKit/AppKit.h>
#include	<VHFImport/DXFImport.h>

@interface DXFImportSub: DXFImport
{
    NSMutableArray	*layerList;
}

/* subclassed from super class
 */
- (id)allocateList:(NSArray*)layers;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:(NSMutableArray*)aList;
- (void)addLine:(NSPoint)beg :(NSPoint)end toLayer:(NSString*)layerName;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:(NSMutableArray*)aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toLayer:(NSString*)layerName;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:(NSMutableArray*)aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toLayer:(NSString*)layerName;
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar :(int)alignment at:(NSPoint)p toLayer:(NSString*)layerName;
- (void)addStrokeList:aList toLayer:(NSString*)layerName;
- (void)addFillList:aList toLayer:(NSString*)layerName;
- (void)setBounds:(NSRect)bounds;

@end

#endif // VHF_H_DXFIMPORTSUB
