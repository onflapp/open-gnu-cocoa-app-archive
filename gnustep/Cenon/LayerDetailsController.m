/* LayerDetailsController.m
 *
 * Copyright (C) 2005-2007 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  2005-08-31
 * Modified: 2007-08-08 (batch switch)
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
#include <VHFShared/types.h>
#include <VHFShared/VHFPopUpButtonAdditions.h>		// -selectItemWithTag:
#include "App.h"		// inspectorPanel
#include "LayerObject.h"
#include "InspectorPanel.subproj/InspectorPanel.h"
#include "InspectorPanel.subproj/IPAllLayers.h"
#include "LayerDetailsController.h"

static LayerDetailsController	*sharedInstance = nil;	// default object


/* Private methods
 */
@interface LayerDetailsController(PrivateMethods)
@end

@implementation LayerDetailsController

+ (LayerDetailsController*)sharedInstance
{
    if (!sharedInstance)
        sharedInstance = [self new];
    return sharedInstance;
}

/* open panel
 * sender should be the layer object
 */
- (void)showPanel:(id)sender
{   LayerObject	*layerObject = sender;
    NSArray	*layerList = [[[(App*)NSApp currentDocument] documentView] layerList];
    int		l;

    if (!panel)
    {
        /* load panel, this establishes connections to interface outputs */
        if ( ![NSBundle loadNibNamed:@"LayerDetails" owner:self] )
        {   NSLog(@"Cannot load Layer Details Panel interface file");
            return;
        }
        [panel setDelegate:self];
        [panel setFrameUsingName:@"LayerDetailsPanel"];
        [panel setFrameAutosaveName:@"LayerDetailsPanel"];
    }
    if ( ![sender isKindOfClass:[LayerObject class]] )
        return;
    switch ([layerObject type])
    {
        case LAYER_STANDARD:
        case LAYER_PAGE:
            break;
        case LAYER_TEMPLATE:
        case LAYER_TEMPLATE_1:
        case LAYER_TEMPLATE_2:
            //[[typePopup itemWithTag:[layerObject type]] setEnabled:YES];
            break;
        default:	// unsupported layer type -> don't allow changes
            return;
    }

    /* disable template type, if this type is already in layer list */
    [typePopup setAutoenablesItems:NO]; // Apple changed the defaults!
    [[typePopup itemWithTag:-1]               setEnabled:NO];   // disable separating layers
    [[typePopup itemWithTag:LAYER_TEMPLATE]   setEnabled:YES];
    [[typePopup itemWithTag:LAYER_TEMPLATE_1] setEnabled:YES];
    [[typePopup itemWithTag:LAYER_TEMPLATE_2] setEnabled:YES];
    for (l=0; l<(int)[layerList count]; l++)
    {   LayerType	type = [(LayerObject*)[layerList objectAtIndex:l] type];

        if (layerObject == [layerList objectAtIndex:l])	// skip ourself
            continue;
        switch ( type )
        {
            case LAYER_TEMPLATE:
            case LAYER_TEMPLATE_1:
            case LAYER_TEMPLATE_2:
                [[typePopup itemWithTag:type] setEnabled:NO];
                break;
            default:
                continue;
        }
    }

    [typePopup selectItemWithTag:[layerObject type]];           // type
    [nameField setStringValue:[layerObject string]];            // name
    [(NSButton*)batchSwitch setState:[layerObject useForTile]];	// batch production

    [NSApp runModalForWindow:panel];
}

/* set parameters for selected layer
 */
- (void)set:(id)sender
{   LayerType		type = [[typePopup selectedItem] tag];
    InspectorPanel	*inspector = [(App*)NSApp inspectorPanel];
    IPAllLayers		*layerInspector = [inspector windowAt:IP_LAYERS];
    LayerObject		*layerObject = [layerInspector currentLayerObject];

    [layerObject setType:type];
    if ([[nameField stringValue] length])
        [layerObject setString:[nameField stringValue]];
    [panel orderOut:self];
    [NSApp stopModalWithCode:YES];

    [layerObject setUseForTile:[(NSButton*)batchSwitch state]];

    [layerInspector update:self];
}


- (BOOL)windowShouldClose:(id)sender
{
    [NSApp stopModalWithCode:YES];
    return YES;
}

- (void)dealloc
{
    if (self == sharedInstance)
        sharedInstance = nil;
    [super dealloc];
}

@end
