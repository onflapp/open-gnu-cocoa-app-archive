/* IPLayerCell.h
 * part of IPAllLayers
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  2002-10-05 from LayerCell 1996-03-07
 * Modified: 2002-10-07
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

#ifndef VHF_H_IPLAYERCELL
#define VHF_H_IPLAYERCELL

#include "../LayerObject.h"
#include "../MoveCell.h"

@interface IPLayerCell: MoveCell
{
    LayerObject	*layerObject;
}

- init;
- (void)setLayerObject:(LayerObject*)theObject;
- (LayerObject*)layerObject;
- (BOOL)dependant;
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)aView untilMouseUp:(BOOL)_untilMouseUp;

/* methods implemented by the delegate (of the matrix)
 */
- (void)cellDidChangeSide:sender;

@end

#endif // VHF_H_IPLAYERCELL
