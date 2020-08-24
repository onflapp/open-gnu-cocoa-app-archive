/* TPAlign.m
 * Transform panel - align
 *
 * Copyright (C) 1996-2005 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-11
 * Modified: 2005-04-25 (clean up)
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

#include "TransformPanel.h"
#include "TPAlign.h"
#include "../App.h"
#include "../DocView.h"
#include "../locations.h"
#include "../messages.h"
#include "../Graphics.h"
#include "../graphicsUndo.subproj/undo.h"

#define ALIGN_HRIGHT	0
#define ALIGN_HCENTER	1
#define ALIGN_HLEFT	2
#define ALIGN_VTOP	3
#define ALIGN_VCENTER	4
#define ALIGN_VBOTTOM	5

@interface TPAlign(PrivateMethods)
@end

@implementation TPAlign

- init
{
    [super init];
    [self update:self];
    return self;
}

- (void)update:sender
{
}

- (void)align:sender
{   id		view = [self view];
    NSArray *slayList = [view slayList];
    int		i, l, cnt;
    NSPoint	pa = NSMakePoint(0.0, 0.0);
    NSRect	rect;
    id		change;

    if ([(NSButton*)alignLayerSwitch state])
    {   [self alignLayer:sender];
        return;
    }

    for (l=0, cnt = [slayList count]; l<cnt; l++)
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];
        id		g;

        if ( ![[[view layerList] objectAtIndex:l] editable] || ![slist count] )
            continue;
        g = [slist objectAtIndex:0];
        rect = [g bounds];
        switch ( [(NSButton*)sender tag] )
        {
            case ALIGN_HRIGHT: pa.x = rect.origin.x+rect.size.width; break;
            case ALIGN_HCENTER: pa.x = rect.origin.x+rect.size.width/2.0; break;
            case ALIGN_HLEFT: pa.x = rect.origin.x; break;
            case ALIGN_VTOP: pa.y = rect.origin.y+rect.size.height; break;
            case ALIGN_VCENTER: pa.y = rect.origin.y+rect.size.height/2.0; break;
            case ALIGN_VBOTTOM: pa.y = rect.origin.y;break;
            default: NSLog(@"Unsupported align tag %d", [(NSButton*)sender tag]); return;
        }
        break;
    }

    change = [[AlignGraphicsChange alloc] initGraphicView:view];
    [change startChange];
        for (l=0, cnt = [slayList count]; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [[view layerList] objectAtIndex:l];

            if ( ![layer editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   id	g = [slist objectAtIndex:i];
                NSPoint	p = NSMakePoint(0.0, 0.0);

                rect = [g bounds];
                switch ( [(NSButton*)sender tag] )
                {
                    case ALIGN_HRIGHT: p.x = pa.x-(rect.origin.x+rect.size.width); break;
                    case ALIGN_HCENTER: p.x = pa.x-(rect.origin.x+rect.size.width/2.0); break;
                    case ALIGN_HLEFT: p.x = pa.x-rect.origin.x; break;
                    case ALIGN_VTOP: p.y = pa.y-(rect.origin.y+rect.size.height); break;
                    case ALIGN_VCENTER: p.y = pa.y-(rect.origin.y+rect.size.height/2.0); break;
                    case ALIGN_VBOTTOM: p.y = pa.y-rect.origin.y;
                }
                if ( [g respondsToSelector:@selector(moveBy:)] )
                {   [(VGraphic*)g moveBy:p];
                    [layer updateObject:g];
                }
            }
        }
    [change endChange];

    [view drawAndDisplay];
}

/* align layers using selected graphics as reference
 * we build the bounds of the selected graphics on each layer, and move the other layers to fit
 * we take the first non editable layer (or the last layer) as reference
 *
 * created:  2001-06-07
 * modified: 2001-08-21
 */
- (void)alignLayer:sender
{   id		view = [self view];
    NSArray *slayList = [view slayList];
    id		layerList = [view layerList];
    int		i, l, cnt, refLayer = -1, lastLayer = -1;
    NSPoint	pa = NSMakePoint(0.0, 0.0);	// reference point
    NSRect	rect;
    id		change;

    /* get reference layer
     * this is the first not editable layer, or the last layer
     */
    for (l=0, cnt = [slayList count]; l<cnt; l++)
    {	NSMutableArray	*slist = [slayList objectAtIndex:l];

        if ([slist count] && ![[layerList objectAtIndex:l] editable])
        {   refLayer = l;
            break;
        }
        if ([slist count])
            lastLayer = l;
    }
    if (refLayer < 0)
        refLayer = lastLayer;
    if (refLayer < 0)	// no reference
        return;

    /* determine destination point */
    rect = [view coordBoundsOfArray:[slayList objectAtIndex:refLayer]];
    switch ( [(NSButton*)sender tag] )
    {
        case ALIGN_HRIGHT:  pa.x = rect.origin.x+rect.size.width; break;
        case ALIGN_HCENTER: pa.x = rect.origin.x+rect.size.width/2.0; break;
        case ALIGN_HLEFT:   pa.x = rect.origin.x; break;
        case ALIGN_VTOP:    pa.y = rect.origin.y+rect.size.height; break;
        case ALIGN_VCENTER: pa.y = rect.origin.y+rect.size.height/2.0; break;
        case ALIGN_VBOTTOM: pa.y = rect.origin.y;break;
        default: NSLog(@"Unsupported align tag %d", [(NSButton*)sender tag]); return;
    }

    /* move layers */
    // es sollte d pro Lage gespeichert werden, bei undo sollte der moveBy röckgÙngig auf die gesamte Lage...
    change = [[MoveLayerGraphicsChange alloc] initGraphicView:view];
    [change startChange];
        for (l=0, cnt = [slayList count]; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];
            NSPoint		d = NSMakePoint(0.0, 0.0);

            if ( ![layer editable] || l == refLayer || ![slist count])
                continue;

            /* get delta */
            rect = [view coordBoundsOfArray:slist];
            switch ( [(NSButton*)sender tag] )
            {
                case ALIGN_HRIGHT:  d.x = pa.x - (rect.origin.x+rect.size.width); break;
                case ALIGN_HCENTER: d.x = pa.x-(rect.origin.x+rect.size.width/2.0); break;
                case ALIGN_HLEFT:   d.x = pa.x-rect.origin.x; break;
                case ALIGN_VTOP:    d.y = pa.y-(rect.origin.y+rect.size.height); break;
                case ALIGN_VCENTER: d.y = pa.y-(rect.origin.y+rect.size.height/2.0); break;
                case ALIGN_VBOTTOM: d.y = pa.y-rect.origin.y;
            }

            [change setOffset:d forLayerIndex:l];

            /* move objects */
            for ( i=[[layer list] count]-1; i>=0; i-- )
            {   id	g = [[layer list] objectAtIndex:i];

                if ( [g respondsToSelector:@selector(moveBy:)] )
                {   [(VGraphic*)g moveBy:d];
                    [layer updateObject:g];
                }
            }
        }
    [change endChange];

    [view drawAndDisplay];
}

@end
