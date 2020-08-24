/* HiddenArea.h
 * Object for calculation of hidden areas
 *
 * Copyright (C) 1999-2006 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  1998-03-26
 * modified: 2006-02-06
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

#ifndef VHF_H_HIDDENAREA
#define VHF_H_HIDDENAREA

@interface HiddenArea:NSObject

/* HiddenArea methods
 */
- (void)removeHiddenAreas:(NSMutableArray*)list;
- (void)uniteAreas:(NSMutableArray*)list;
- (void)removeSingleGraphicsInList:(NSMutableArray*)list :(NSRect)rect;
- (BOOL)removeGraphics:(NSMutableArray*)list inside:(id)graphic;
- (BOOL)removeGraphics:(NSMutableArray*)list outside:(id)graphic;
- (BOOL)removePartsOf:(VGraphic**)curG hiddenBy:(id)og;

@end

#endif // VHF_H_HIDDENAREA
