/* VHFPopUpButtonAdditions.h
 * vhf NSPopUpButton additions
 *
 * Copyright (C) 1997-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-10-24
 * modified: 2013-02-01
 *
 * This file is part of the vhf Shared Library.
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

#ifndef VHF_H_POPUPADDITIONS
#define VHF_H_POPUPADDITIONS

#include <AppKit/AppKit.h>
#include "vhfCompatibility.h"     // NSInteger for OS X 10.4

@interface NSPopUpButton(VHFPopUpButtonAdditions)
- (NSMenuItem*)itemWithTag:(NSInteger)tag;
- (BOOL)selectItemWithTag:(NSInteger)tag;   // method available since Mac OS X >= 10.4

- (void)replaceItemsFromArray:(NSArray*)items fromIndex:(NSInteger)removeIx;
@end

#endif // VHF_H_POPUPADDITIONS
