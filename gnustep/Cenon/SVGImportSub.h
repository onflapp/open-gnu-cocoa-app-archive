/* SVGImportSub.m
 * Subclass of SVG import
 *
 * Copyright (C) 2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2010-07-04
 * modified: 2010-07-04
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

#ifndef VHF_H_SVGIMPORTSUB
#define VHF_H_SVGIMPORTSUB

#include <AppKit/AppKit.h>
#include <VHFImport/SVGImport.h>

@interface SVGImportSub:SVGImport
{
}

/* subclassed from super class
 */
/*- allocateList;
- (void)addLine:(NSPoint)beg :(NSPoint)end toList:aList;
- (void)addArc:(NSPoint)center :(NSPoint)start :(float)angle toList:aList;
- (void)addCurve:(NSPoint)p0 :(NSPoint)p1 :(NSPoint)p2 :(NSPoint)p3 toList:aList;
- (void)addText:(NSString*)text :(NSString*)font :(float)angle :(float)size :(float)ar at:(NSPoint)p toList:aList;
- (void)addGroupList:aList toList:bList;
- (void)addFillList:aList toList:bList;
- (void)setBounds:(NSRect)bounds;*/

@end

#endif // VHF_H_SVGIMPORTSUB
