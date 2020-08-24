/* PathContour.h
 * Object to build contour of paths using a raster algorithm (scan)
 *
 * Copyright (C) 2000-2006 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2000-02-23
 * modified: 2006-02-21
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

#ifndef VHF_H_PATHCONTOUR
#define VHF_H_PATHCONTOUR

#include "VPath.h"
#include "VImage.h"

@interface PathContour:NSObject

/* PathContour methods
 */
-(VPath*)contourPath:(VPath*)oPath width:(float)width;
-(VPath*)contourImage:(VImage*)image width:(float)width;
-(VPath*)contourList:(NSArray*)oList width:(float)width;

@end

#endif // VHF_H_PATHCONTOUR
