/* IPImage.h
 * Image inspector
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1998-03-23
 * modified: 2002-07-20
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

#ifndef VHF_H_IPIMAGE
#define VHF_H_IPIMAGE

#include <AppKit/AppKit.h>
#include "IPBasicLevel.h"

@interface IPImage:IPBasicLevel
{
    id	xField;
    id	yField;
    id	widthField;
    id	heightField;
    //id	reliefSwitch;
    //id	reliefPopUp;
    id	thumbSwitch;
    id	nameField;
    id	factorField;
    id	compPopUp;

    VGraphic	*graphic;	// the loaded graphic or the first of them if multiple
}

- (void)update:sender;

- (void)setX:sender;
- (void)setY:sender;
- (void)setWidth:sender;
- (void)setHeight:sender;
//- (void)setRelief:sender;
//- (void)setReliefType:sender;
- (void)setThumbnail:sender;
- (void)setName:sender;
- (void)setCompressionFactor:sender;
- (void)setCompressionType:sender;

- (void)displayWillEnd;

@end

#endif // VHF_H_IPIMAGE
