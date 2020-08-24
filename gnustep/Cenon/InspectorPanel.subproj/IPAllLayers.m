/* IPAllLayers.m
 * Layer management Inspector for all objects
 *
 * Copyright (C) 2002-2011 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann, Georg Fleischmann
 *
 * created:  2002-06-27
 * modified: 2011-01-10 (click on layer ends editing of text)
 *           2006-01-13
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

#include "../App.h"
#include "../DocView.h"
#include "../LayerObject.h"
#include "../LayerDetailsController.h"
#include "../Graphics.h"
#include "../messages.h"
#include "InspectorPanel.h"
#include "IPAllLayers.h"
#include "IPLayerCell.h"

@implementation IPAllLayers

- init
{   NSNotificationCenter	*notificationCenter = [NSNotificationCenter defaultCenter];

    [moveMatrix initCellClass:[IPLayerCell class]];
    [moveMatrix setDelegate:self];
    [moveMatrix setTarget:self];
    [moveMatrix setAction:@selector(clickLayer:)];
    [moveMatrix setDoubleAction:@selector(doubleClickLayer:)];

    /* notification: layerList has changed and needs a reload */
    [notificationCenter addObserver:self
                           selector:@selector(layerListHasChanged:)
                               name:DocLayerListHasChanged
                             object:nil];

    return [super init];
}

/* created:  1993-07-22
 * modified: 2006-01-13
 * purpose:  set layer list for layer matrix (moveMatrix)
 *           this may be called from self or from the document
 */
- (void)setLayerList:(NSMutableArray*)theLayerList
{   int		i, cnt;
    LayerObject	*layerObject;

    /* if layer of selected cell is in layerList */
    if ( lastLayerList == theLayerList && moveCellCount == (int)[theLayerList count] )
    {
        layerObject = [[moveMatrix selectedCell] layerObject];
        if ([theLayerList containsObject:layerObject])
        {   [nameField setStringValue:[layerObject string]];
            [[moveMatrix superview] display];	// states may still have changed
            return;
        }
    }
    lastLayerList = theLayerList;
    moveCellCount = [theLayerList count];

    [moveMatrix setAllowsEmptySelection:YES];	// GNUstep: allows selectedRow = -1
    //[moveMatrix selectCellAtRow:0 column:0];	// GNUstep
    [moveMatrix renewRows:0 columns:0];
    for (i=0, cnt=[theLayerList count]; i<cnt && (layerObject=[theLayerList objectAtIndex:i]); i++)
    {	[moveMatrix addRow];
        [[moveMatrix cellAtRow:i column:0] setLayerObject:layerObject];
    }
    [moveMatrix calcCellSize];
    [moveMatrix sizeToCells];
    if ([moveMatrix numberOfRows])
        [moveMatrix selectCellAtRow:[docView indexOfSelectedLayer] column:0];
    [moveMatrix setAllowsEmptySelection:NO];	// GNUstep
    [[moveMatrix superview] display];	// redraw clipView to be sure to overdraw removed cells

    if ((layerObject = [[moveMatrix selectedCell] layerObject]))
        [nameField setStringValue:[layerObject string]];
}

- (NSMutableArray*)currentLayerList
{
    return [[[(App*)NSApp currentDocument] documentView] layerList];
}
- (LayerObject*)currentLayerObject
{
    return [[moveMatrix selectedCell] layerObject];
}
- (int)indexOfSelectedLayer
{
    return [moveMatrix selectedRow];
}

/* sender = selected graphic object
 */
- (void)update:sender
{
    docView = [window docView];

    /* fill the layer matrix (moveMatrix) */
    [self setLayerList:(docView) ? [docView layerList] : [self currentLayerList]];

    [window flushWindow];
}


- (void)setName:sender
{   IPLayerCell	*cell = [moveMatrix selectedCell];

    [cell setStringValue:[nameField stringValue]];
    [[cell layerObject] setString:[nameField stringValue]];
    [moveMatrix display];
}

- (void)changeLayer:sender
{
    [[[(App*)NSApp currentDocument] documentView] moveSelectionToLayer:[moveMatrix selectedRow]];
    [[(App*)NSApp currentDocument] setDirty:YES];
}

- (void)newLayer:sender
{   LayerObject		*layerObject;
    NSMutableArray	*layerList;
    int			l, ix, type = LAYER_STANDARD;
    NSString		*name = UNTITLED_STRING;
    id			view = nil;

    if ( !view )
        view = [[(App*)NSApp currentDocument] documentView];
    layerList = [view layerList];
    if (!layerList)
        return;

    /* use name from name field if usable */
    if ( [[nameField stringValue] length] )
    {
        name = [nameField stringValue];
        for (l=0; l<(int)[layerList count]; l++)
        {   layerObject = [layerList objectAtIndex:l];

            if ( [[layerObject string] isEqualToString:name] )	// field name in use
            {   name = UNTITLED_STRING;
                break;
            }
        }
    }

    /* check for conflicting layer name */
    for (l=0; l<(int)[layerList count]; l++)
    {   layerObject = [layerList objectAtIndex:l];

        if ( [[layerObject string] isEqualToString:name] )	// name allready in use!
        {
            NSRunAlertPanel(@"", NAMEINUSE_STRING, OK_STRING, nil, nil, name);
            return;
        }
    }

    /* update layer list */
    layerObject = [LayerObject layerObjectWithFrame:[view bounds]];
    [layerObject setString:name];
    [layerObject setType:type];
    if ( type == LAYER_CLIPPING || type == LAYER_LEVELING )
        [layerObject setState:0];	// don't display
    if ( [layerList count] &&
         [(LayerObject*)[layerList objectAtIndex:[layerList count]-1] type] == LAYER_CLIPPING )
    {   [layerList insertObject:layerObject atIndex:[layerList count]-1];
        ix = [layerList count]-2;
    }
    else
    {   [layerList addObject:layerObject];
        ix = [layerList count]-1;
    }

    /* update select list */
    [[view slayList] addObject:[NSMutableArray array]];

    /* update matrix */
    if ( ix < (int)[layerList count]-1 )
        [moveMatrix insertRow:ix];
    else
        [moveMatrix addRow];
    [[moveMatrix cellAtRow:ix column:0] setLayerObject:layerObject];
    [moveMatrix sizeToCells];
    [moveMatrix selectCellAtRow:ix column:0];
    [view selectLayerAtIndex:ix];
    [moveMatrix display];

    [nameField setStringValue:[layerObject string]];
    [[view document] setDirty:YES];
}

- (void)removeLayer:sender
{   int         row = [moveMatrix selectedRow];
    LayerObject *layerObject;

    //if ( [[[moveMatrix selectedCell] layerObject] type] == LAYER_CLIPPING )
    //    return;
    if ( row == -1 || [moveMatrix numberOfRows] <= 1 )
        return;

    if (! NSRunAlertPanel(@"", REALLYDELETELAYER_STRING, DELETE_STRING, CANCEL_STRING, nil,
                               [[moveMatrix selectedCell] stringValue]) == NSAlertDefaultReturn)
        return;

    [moveMatrix removeRow:row];
    /* remove possible passive layer */
    if ( row < [moveMatrix numberOfRows] && [[moveMatrix cellAtRow:row column:0] dependant] )
        [moveMatrix removeRow:row];

    [moveMatrix selectCellAtRow:row-1 column:0];
    [docView selectLayerAtIndex:row-1];
    [[self currentLayerList] removeObjectAtIndex:row];
    [[docView slayList] removeObjectAtIndex:row];
    moveCellCount --;

    [moveMatrix sizeToCells];
    [moveMatrix display];

    layerObject = [[moveMatrix selectedCell] layerObject];
    [nameField setStringValue:[layerObject string]];

    [[docView document] setDirty:YES];
    [docView drawAndDisplay];

    /* post notification, that layer xy has been removed, so other layer lists can update themselfes */
    [[NSNotificationCenter defaultCenter] postNotificationName:DocLayerListHasChanged
                                                        object:docView /*layerObject*/];
}


- (void)clickLayer:sender
{   LayerObject	*layerObject = [self currentLayerObject];

    /* set name of layer */
    [nameField setStringValue:[layerObject string]];

    /* update view */
    [[[(App*)NSApp currentDocument] documentView] selectLayerAtIndex:[self indexOfSelectedLayer]];

    [[[(App*)NSApp currentDocument] window] endEditingFor:nil]; // end editing of text
}

- (void)doubleClickLayer:sender
{   LayerObject	*layerObject = [self currentLayerObject];

    [[LayerDetailsController sharedInstance] showPanel:layerObject];
}

/* return YES, if at least one layer is displayed
 * called from IPLayerCell
 */
- (BOOL)updateLayerLists
{   int         i, cnt;
    LayerObject *layerObject;

    for ( i=0, cnt=0; (layerObject=[[moveMatrix cellAtRow:i column:0] layerObject]); i++ )
    {
        if ( [layerObject state] )
            cnt++;
    }

    return (cnt) ? YES : NO;
}

/* display new layers
 * called from IPLayerCell
 * modified: 2005-09-01
 */
- (void)displayChanged:sender
{   DocView         *view = [[(App*)NSApp currentDocument] documentView];
    int             l, i;
    NSMutableArray  *slayList = [view slayList], *layerList = [view layerList];
    LayerObject     *selectedLayer = [[moveMatrix selectedCell] layerObject];
    BOOL            layerStateChanged = NO;

    for ( l=0; l<(int)[layerList count]; l++ )
    {   LayerObject	*layerObject = [layerList objectAtIndex:l];

        if ( ![layerObject state] )
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            for (i=[slist count]-1; i>=0; i--)
                [[slist objectAtIndex:i] setSelected:NO];
            [slist removeAllObjects];
        }
        else if ([selectedLayer type] == LAYER_PAGE &&
                 selectedLayer != layerObject && [layerObject type] == LAYER_PAGE)
        {   NSMutableArray	*slist = [slayList objectAtIndex:l];

            for (i=[slist count]-1; i>=0; i--)
                [[slist objectAtIndex:i] setSelected:NO];
            [slist removeAllObjects];

            [layerObject setState:0];
            layerStateChanged = YES;
        }
    }
    if (layerStateChanged)	// redisplay layer list
        [moveMatrix display];
    [view drawAndDisplay]; 
}

/*
 * called from MoveMatrix to exchange two layers
 */
- (void)matrixDidShuffleCellFrom:(int)from to:(int)to
{   id              view = [[(App*)NSApp currentDocument] documentView];
    int             i, masterCnt = [[view layerList] count];
    id              obj;
    NSMutableArray  *list;
    NSArray         *array = [NSArray arrayWithObjects:[view layerList], [view slayList], nil];

    for ( i=0; i<(int)[array count]; i++ )
    {
        list = [array objectAtIndex:i];
        if ( (int)[list count] < masterCnt )
            continue;
        obj = [[list objectAtIndex:from] retain];		
        [list removeObjectAtIndex:from];
        [list insertObject:obj atIndex:to];
        [obj release];
    }

    [view selectLayerAtIndex:[self indexOfSelectedLayer]];

    [self update:self];
    [view drawAndDisplay];

    /* post notification, that layerlist has been modified, so other layer lists can update themselfes */
    [[NSNotificationCenter defaultCenter] postNotificationName:DocLayerListHasChanged
                                                        object:docView /*layerObject*/];
}

/* notification that the layer list of the view has changed
 */
- (void)layerListHasChanged:(NSNotification*)notification
{   DocView	*view = [notification object];

    if ([view isKindOfClass:[DocView class]])
        [self update:view];
    else
        NSLog(@"IPAllLayers, notification send from object not a DocView!");
}


- (void)displayWillEnd
{
}

@end
