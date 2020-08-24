/* IPAllFilling.h
 * Fill Inspector for all objects
 *
 * Copyright (C) 2002 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2002-06-27
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

#ifndef VHF_H_IPALLFILLING
#define VHF_H_IPALLFILLING

#include <AppKit/AppKit.h>
#include "IPBasicLevel.h"

@interface IPAllFilling:IPBasicLevel
{
    id angleField;
    id angleSlider;
    id stepForm;
    id colorWell;
    id colorWellGraduated;
    id fillPopup;
    id sliderBox;
    id radialCenterText;
    id angleButtonLeft;
    id angleButtonRight;
    id stepButtonLeft;
    id stepButtonRight;

    VGraphic	*graphic;	// the loaded graphic or the first of them if multiple
}

- (void)update:sender;

- (void)setAngle:(id)sender;
- (void)setStepWidth:sender;
- (void)setFillColor:(id)sender;
- (void)setEndColor:(id)sender;
- (void)setFillState:(id)sender;
- (void)setRadialCenter:(id)sender;

- (void)displayWillEnd;

@end

#endif // VHF_H_IPALLFILLING
