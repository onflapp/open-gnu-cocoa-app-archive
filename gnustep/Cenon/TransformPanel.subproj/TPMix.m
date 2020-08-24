/* TPMix.m
 * Transform panel for randomly mixing object positions on page
 *
 * Copyright (C) 1996-2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-30
 * Modified: 2002-07-15
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

#include <AppKit/AppKit.h>
#ifndef GNUSTEP_BASE_VERSION	// only needed for OpenStep for MACH
#ifndef __APPLE__
#    include <bsd/libc.h>	// random()
#endif
#endif
#include "TPMix.h"
#include "../App.h"
#include "../DocView.h"
#include "../locations.h"
#include "../messages.h"
#include "../Graphics.h"
#include "../graphicsUndo.subproj/undo.h"

#define MIX_DONTMIX		0
#define MIX_DONTMIXLAYER	1

@implementation TPMix

- init
{
    [super init];
    [self update:self];
    return self;
}

- (void)update:sender
{
}

#define Rand()	Min( 1.0, ((float)random() / 2147483647.0 + 0.05) )
/* mix positions
 */
- (void)mix:sender
{   id		view = [self view];
    NSArray *slayList = [view slayList];
    id		layerList = [view layerList];
    BOOL	mixLayers = [(NSButton*)mixLayersSwitch state];
    BOOL	mixLocked = ([lockRadio selectedRow]) ? YES : NO;
    int		l, l1, cnt, i, i1, j;
    id		change;

    change = [[MixGraphicsChange alloc] initGraphicView:view];
    [change startChange];
        for (l=0, cnt = [slayList count]; l<cnt; l++)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];
            LayerObject		*layer = [layerList objectAtIndex:l];

            if ( ![layer editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   id	g0 = [slist objectAtIndex:i], g1 = nil;
                NSPoint	p0, p1;
                NSRect	rect0, rect1;

                if ( [g0 isLocked] && !mixLocked )
                    continue;

                while ( 1 )
                {
                    l1 = (mixLayers && ![g0 isLocked]) ? ((int)((float)([slayList count]-1) * Rand())) : l;
                    if ( ![[layerList objectAtIndex:l1] editable] )
                        continue;
                    break;
                }

                for ( j=[(NSArray*)[slayList objectAtIndex:l1] count]*2; j>0; j-- )
                {
                    i1 = (int)((float)([(NSArray*)[slayList objectAtIndex:l1] count]-1) * Rand());
                    g1 = [[slayList objectAtIndex:l1] objectAtIndex:i1];
                    if ( g0==g1 || ([g1 isLocked] && l1!=l) || ([g1 isLocked] && !mixLocked) )
                        continue;
                    break;
                }
                if ( j<=0 )
                    continue;

                rect0 = [g0 coordBounds];
                rect1 = [g1 coordBounds];
                switch ( [(NSButton*)sender tag] )
                {
                    default:	/* mix center */
                        p0.x = (rect1.origin.x+rect1.size.width/2.0) - (rect0.origin.x+rect0.size.width/2.0); p0.y = (rect1.origin.y+rect1.size.height/2.0) - (rect0.origin.y+rect0.size.height/2.0);
                        p1.x = (rect0.origin.x+rect0.size.width/2.0) - (rect1.origin.x+rect1.size.width/2.0); p1.y = (rect0.origin.y+rect0.size.height/2.0) - (rect1.origin.y+rect1.size.height/2.0);
                //default:	/* mix lower left */
                //    p0.x = rect1.origin.x - rect0.origin.x; p0.y = rect1.origin.y - rect0.origin.y;
                //    p1.x = rect0.origin.x - rect1.origin.x; p1.y = rect0.origin.y - rect1.origin.y;
                }
                if ( [g0 respondsToSelector:@selector(moveBy:)] && [g1 respondsToSelector:@selector(moveBy:)])
                {   [(VGraphic*)g0 moveBy:p0];
                    [(VGraphic*)g1 moveBy:p1];
                    [layer updateObject:g0];
                    [layer updateObject:g1];

                    [layer setDirty:YES];
                    if ( l != l1 )
                    {
                        [layer addObject:g1];
                        [[slayList objectAtIndex:l] addObject:g1];
                        [[layerList objectAtIndex:l1] addObject:g0];
                        [[slayList objectAtIndex:l1] addObject:g0];

                        [layer removeObject:g0];
                        [[slayList objectAtIndex:l] removeObject:g0];
                        [[layerList objectAtIndex:l1] removeObject:g1];
                        [[slayList objectAtIndex:l1] removeObject:g1];
                        [[layerList objectAtIndex:l1] setDirty:YES];
                    }
                }
            }
        }
    [change endChange];

    [[self view] drawAndDisplay];
}

@end
