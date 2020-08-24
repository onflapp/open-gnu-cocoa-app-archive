/* VSinking.h
 * Sinking
 *
 * Copyright (C) 2000-2005 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-09-18
 * modified: 2005-10-13
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

#ifndef VHF_H_VSINKING
#define VHF_H_VSINKING

#include "VGraphic.h"

#define PTS_SINKING	1
#define	PT_ORIGIN	0
#define	SINKING_ANGLE	-360.0

/* unit */
#define SINKING_METRIC	0
#define SINKING_INCH	1

/* type */
#define SINKING_MEDIUM	0
#define SINKING_FINE	1

@interface VSinking: VGraphic
{
    NSPoint	origin;
    NSString	*name;		/* nominal diameter */
    float	d1;		/* diameter */
    float	d2;		/* head diameter */
    float	t1;		/* head height */
    float	t2;		/* head brim */
    float	stepSize;	/* size of steps for head */
    int		type;		/* medium or fine */
    int		unit;		/* metric or inch */
}

/* class methods */

/* sinking methods */
- (void)setName:(NSString*)newName;
- (NSString*)name;
- (void)setD1:(float)v;
- (float)d1;
- (void)setD2:(float)v;
- (float)d2;
- (void)setT1:(float)v;
- (float)t1;
- (void)setT2:(float)v;
- (float)t2;
- (void)setStepSize:(float)v;
- (float)stepSize;
- (void)setType:(int)newType;
- (int)type;
- (void)setUnit:(int)newUnit;
- (int)unit;

/* inherited from graphic
 */
- (id)initWithCoder:(NSCoder*)aDecoder;
- (void)encodeWithCoder:(NSCoder*)aCoder;
- (id)propertyList;
- (id)initFromPropertyList:(id)plist inDirectory:(NSString*)directory;

@end

#endif // VHF_H_VSINKING
