/* IntersectionPanel.m
 *
 * Copyright (C) 1997-2012 by vhf interservice GmbH
 * Author:  Georg Fleischmann
 *
 * created:  2000-10-31
 * modified: 2012-07-07 (-create: allow creation on top of single point objects)
 *           2012-07-06 (-create: check for isCnt > 0 before freeing pts)
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

#include "IntersectionPanel.h"
#include "App.h"
#include "Inspectors.h"
#include "Graphics.h"

@implementation IntersectionPanel

- (Class)targetClass
{   NSString	*className;

    switch ([(NSCell*)[objectRadio selectedCell] tag])
    {
        default:                className = @"VMark";    break;
        case IP_CREATE_THREAD:	className = @"VThread";  break;
        case IP_CREATE_SINKING: className = @"VSinking"; break;
        case IP_CREATE_ARC:     className = @"VArc";     break;
        case IP_CREATE_WEB:     className = @"VWeb";     break;
    }
    return NSClassFromString(className);
}

/* modified: 2012-07-07 (turn marks directly into target object)
 *           2012-07-06 (check for isCnt before freeing pts)
 */
- (void)create:(id)sender
{   DocView     *view = [[(App*)NSApp currentDocument] documentView];
    NSArray     *layerList = [view layerList];
    NSArray     *slayList = [view slayList];
    int         l, i, j, k, is, isCnt;
    LayerObject *targetLayer = nil;
    Class       targetClass = [self targetClass];
    NSPoint     *pts;

    for (l=[layerList count]-1; l>=0; l--)
    {
        if ([[layerList objectAtIndex:l] editable])
        {   targetLayer = [layerList objectAtIndex:l];
            break;
        }
    }
    if (!targetLayer)
        return;

    for (l=[layerList count]-1; l>=0; l--)      // all layers
    {   NSMutableArray	*slist = [slayList objectAtIndex:l];

        if (![(LayerObject*)[layerList objectAtIndex:l] state])
            continue;

        /* intersect objects on layer */
        for ( i=0; i<(int)[slist count]; i++ )  // all selected objects
        {   id	g = [slist objectAtIndex:i];

            if ( [g isKindOfClass:targetClass] )
                continue;
            /* Groups and Paths - recursions */
            if ( [g isKindOfClass:[VPath class]] || [g isKindOfClass:[VGroup class]] )
            {   NSMutableArray	*list = [g list];

                for ( j=0; j<(int)[list count]; j++ )
                {   id	g1 = [list objectAtIndex:j];

                    if ( [g1 isKindOfClass:targetClass] )
                        continue;
                    if ( [g1 respondsToSelector:@selector(getIntersections:with:)] )
                    {
                        for (k=j+1; k<(int)[list count]; k++)
                        {   id	g2 = [list objectAtIndex:k];

                            if ( [g2 isKindOfClass:targetClass] )
                                continue;
                            if ( [g2 respondsToSelector:@selector(getIntersections:with:)] )
                            {
                                isCnt = [g1 getIntersections:&pts with:g2];
                                for (is =0; is <isCnt; is ++)
                                {   id		tg = [targetClass graphic];
                                    NSPoint	p = pts[is];

                                    [tg moveTo:p];
                                    [targetLayer addObject:tg];
                                    [targetLayer setDirty:YES];
                                }
                                if (isCnt)
                                    free(pts);
                            }
                        }
                    }
                }
            }
            /* single point objects without intersections (Marks, ...) */
            else if ( [g isKindOfClass:[VMark   class]] || [g isKindOfClass:[VSinking class]] ||
                      [g isKindOfClass:[VThread class]] || [g isKindOfClass:[VWeb     class]] )
            {   id      tg = [targetClass graphic];
                NSPoint p = [g pointWithNum:0];

                [tg moveTo:p];
                [targetLayer addObject:tg];
                [targetLayer setDirty:YES];
            }
            /* Path objects */
            else
            {
                for ( j=i+1; j<(int)[slist count]; j++ )
                {   id	g1 = [slist objectAtIndex:j];

                    if ( [g respondsToSelector:@selector(getIntersections:with:)] )
                    {
                        isCnt = [g getIntersections:&pts with:g1];
                        for (is = 0; is < isCnt; is ++)
                        {   id		tg = [targetClass graphic];
                            NSPoint	p = pts[is];

                            [tg moveTo:p];
                            [targetLayer addObject:tg];
                            [targetLayer setDirty:YES];
                        }
                        if (isCnt)
                            free(pts);
                    }
                }
            }
        }
    }

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
    [[(App*)NSApp inspectorPanel] loadList:slayList];
}

@end
