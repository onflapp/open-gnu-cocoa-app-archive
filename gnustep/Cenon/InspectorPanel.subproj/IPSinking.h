/* IPSinking.h
 * Sinking Inspector
 *
 * Copyright (C) 2000-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-09-18
 * modified: 2003-06-24
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

#ifndef VHF_H_IPSINKING
#define VHF_H_IPSINKING

#include <AppKit/AppKit.h>
#include "IPBasicLevel.h"

/* name of the sinking metrics file */
#define	SINKINGMETRICS_NAME	@"SinkingMetrics.plist"

/* type matrix indeces of switches */
#define	TYPE_MEDIUM	0
#define	TYPE_FINE	1

/* metrics matrix indeces of switches */
#define	METRICS_D1	0
#define	METRICS_D2	1
#define	METRICS_T1	2
#define	METRICS_T2	3
#define METRICS_ST	4

/* keys in metrics file */
#define KEY_MEDIUM	@"medium"
#define KEY_FINE	@"fine"
#define KEY_NAME	@"name"
#define KEY_D1		@"d1"
#define KEY_D2		@"d2"
#define KEY_T1		@"t1"
#define KEY_T2		@"t2"
#define KEY_ST		@"st"

@interface IPSinking:IPBasicLevel
{
    id	positionXField;
    id	positionYField;
    id	typeMatrix;
    id	unitPopUp;
    id	diameterPopUp;
    id	metricsMatrix;

    NSDictionary	*sinkingMetrics;
}

- (void)setPositionX:sender;
- (void)setPositionY:sender;
- (void)setType:sender;
- (void)setUnit:sender;
- (void)setDiameter:sender;
- (void)setMetrics:sender;

@end

#endif // VHF_H_IPSINKING
