/* CenonModuleMethods.h
 * Common methods used in preferences bundles
 *
 * Copyright (C) 2003-2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  2003-04-09
 * Modified: 2010-07-16
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

#ifndef VHF_H_CENONMODULEMETHODS
#define VHF_H_CENONMODULEMETHODS

#include <AppKit/AppKit.h>

@protocol CenonModuleMethods

+ (id)instance;
- (id)init;

- (NSString*)version;
- (NSString*)compileDate;   // compile date or nil
- (NSString*)serialNo;      // serial number or nil
- (NSString*)netId;         // origin

@end

#endif	// VHF_H_CENONMODULEMETHODS
