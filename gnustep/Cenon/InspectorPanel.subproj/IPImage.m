/* IPImage.m
 * Image inspector
 *
 * Copyright (C) 1995-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-11-14
 * modified: 2011-06-30 (-update:, -setCompressionType: display name without extension (label))
 *           2005-07-20 (document units, more file types)
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
#include "../Graphics.h"
#include "../LayerObject.h"
#include "../messages.h"
#include <VHFShared/VHFPopUpButtonAdditions.h>
#include "InspectorPanel.h"
#include "IPImage.h"

@implementation IPImage

- init
{   int	i;

    [super init];

    //[reliefPopUp setTarget:self];
    //[reliefPopUp setAction:@selector(setReliefType:)];
    [compPopUp setTarget: self];
    [compPopUp setAction: @selector(setCompressionType:)];

    /* deactivate unsupported file types */
    for (i=0; i<[compPopUp numberOfItems]; i++)
    {   NSMenuItem  *item = [compPopUp itemAtIndex:i];

        if (![VImage isAcceptedFileType:[item tag]])
            [item setEnabled:NO];
    }

    return self;
}

- (void)update:sender
{   Document    *doc = [[self view] document];
    DocView     *view = [self view];
    VImage      *g = sender;
    NSPoint     p, p1;
    int         type = [g fileType];

    graphic = sender;

    [super update:sender];
    p = [view pointRelativeOrigin:[g pointWithNum:PT_LL]];
    [xField setStringValue:buildRoundedString([doc convertToUnit:p.x], LARGENEG_COORD, LARGE_COORD)];
    [yField setStringValue:buildRoundedString([doc convertToUnit:p.y], LARGENEG_COORD, LARGE_COORD)];
    p1 = [view pointRelativeOrigin:[g pointWithNum:PT_UR]];
    [widthField  setStringValue:buildRoundedString([doc convertToUnit:p1.x-p.x], 0.0, LARGE_COORD)];
    [heightField setStringValue:buildRoundedString([doc convertToUnit:p1.y-p.y], 0.0, LARGE_COORD)];
    if ( [g label] )
        [nameField setStringValue:[g label]];   // no extension
    else
        [nameField setStringValue:[g name]];
    [(NSButton*)thumbSwitch setState:[g thumbnail]];
    [[thumbSwitch controlView] display];    // the state in the NSButtonCells in the NSMatrix will be updated

    [(NSPopUpButton*)compPopUp selectItemWithTag:type];
    [factorField setEnabled:(type == VImageJPEG) ? YES : NO];
    [factorField setStringValue:buildRoundedString((1.0-[g compressionFactor])*100, 0.0, 100.0)];
}

- (void)setX:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [xField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    [xField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:PT_LL to:[[self view] pointAbsolute:NSMakePoint(v, 0.0)] x:YES y:NO all:YES];
}

- (void)setY:sender
{   Document    *doc = [[self view] document];
    float       min = LARGENEG_COORD, max = LARGE_COORD;
    float       v = [yField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    [yField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] movePoint:PT_LL to:[[self view] pointAbsolute:NSMakePoint(0.0, v)] x:NO y:YES all:YES];
}

- (void)setWidth:sender
{   Document    *doc = [[self view] document];
    //int		i, l, cnt;
    // id		slayList = [[self view] slayList];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [widthField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    [widthField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] takeWidth:v height:0.0];

#if 0
    /* set width of all objects */
    cnt = [slayList count];
    for (l=0; l<cnt; l++)
    {	NSMutableArray *slist = [slayList objectAtIndex:l];

        if (![[[[self view] layerList] objectAtIndex:l] editable])
            continue;
        for (i=[slist count]-1; i>=0; i--)
        {   id		g = [slist objectAtIndex:i];

            if ([g respondsToSelector:@selector(setSize:)])
            {	NSSize	s = [g size];

                s.width = v;
                [(VImage*)g setSize:s];
            }
        }
    }

    [[self view] drawAndDisplay];
#endif
}

- (void)setHeight:sender
{   Document    *doc = [[self view] document];
    float       min = 0.0, max = LARGE_COORD;
    float       v = [heightField floatValue];
    BOOL        control = [(App*)NSApp control];

    if ([sender isKindOfClass:[NSButton class]])
    {
        switch ([(NSButton*)sender tag])
        {
            case BUTTONLEFT:	v -= ((control) ? 10.0 : 1.0); break;
            case BUTTONRIGHT:	v += ((control) ? 10.0 : 1.0);
        }
    }

    if (v < min)	v = min;
    if (v > max)	v = max;
    [heightField setStringValue:vhfStringWithFloat(v)];

    v = [doc convertFrUnit:v];
    [[self view] takeWidth:0.0 height:v];
}

- (void)setThumbnail:sender;
{   int		i, l, cnt;
    id		view = [self view];
    NSArray *slayList = [view slayList];
    BOOL	flag = [(NSButton*)thumbSwitch state];
    //id		change;

    /* set lock for all objects */
    //change = [[LockGraphicsChange alloc] initGraphicView:view];
    //[change startChange];
        cnt = [slayList count];
        for ( l=0; l<cnt; l++ )
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if ( ![[[view layerList] objectAtIndex:l] editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   VImage	*g = [slist objectAtIndex:i];

                if ( [g respondsToSelector:@selector(setThumbnail:)] )
                    [g setThumbnail:flag];
            }
        }
    //[change endChange];

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
}

- (void)setName:sender;
{   int         i, l;
    id          view = [self view];
    NSArray     *layerList = [view layerList], *lList;
    LayerObject *layerObject;
    NSString    *str = [nameField stringValue];

    /* set file name extension */
    /*{   int         type = [[compPopUp selectedItem] tag];
        NSString    *ext = [VImage fileExtensionForFileType:type];

        if ( ! [[str pathExtension] isEqual:ext] )
            str = [[str stringByDeletingPathExtension] stringByAppendingPathExtension:ext];
    }*/

    /* check if name is already in use (skip graphic)
     */
    if (!layerList)
        return;
    for (l=0; l<(int)[layerList count]; l++)
    {	layerObject = [layerList objectAtIndex:l];
        lList = [layerObject list];

        for (i=0; i<(int)[lList count]; i++)
        {   VGraphic    *g = [lList objectAtIndex:i];

            if ( [g respondsToSelector:@selector(setName:)] )
            {
                if ( g != graphic && [[(VImage*)g label] isEqualToString:str] )	// name allready in use!
                {
                    NSRunAlertPanel(@"", NAMEINUSE_STRING, OK_STRING, nil, nil, str);
                    [self update:graphic];
                    return;
                }
            }
        }
    }
    //change = [[LabelGraphicsChange alloc] initGraphicView:view];  // TODO
    //[change startChange];
    str = [(VImage*)graphic setName:str];
    //[change endChange];
    [nameField setStringValue:[graphic label]];

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
}

- (void)setCompressionFactor:sender;
{   float	min = 0.0, max = 100.0;
    float	v = [factorField floatValue];
    id		view = [self view];
    NSArray *slayList = [view slayList];
    int		i, l, cnt;
    //id		change;

    v = (int)v;
    if (v < min) v = min;
    if (v > max) v = max;
    [factorField setStringValue:vhfStringWithFloat(v)];
    v = 1.0 - v/100;    // compression factor of 1.0 results in no compression

    /* set lock for all objects */
    //change = [[LockGraphicsChange alloc] initGraphicView:view];
    //[change startChange];
        cnt = [slayList count];
        for ( l=0; l<cnt; l++ )
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if ( ![[[view layerList] objectAtIndex:l] editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   VImage	*g = [slist objectAtIndex:i];

                if ( [g respondsToSelector:@selector(setCompressionFactor:)] )
                    [g setCompressionFactor:v];
            }
        }
    //[change endChange];

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
}

/* set image format
 */
- (void)setCompressionType:sender;
{   int		i, l, cnt;
    id		view = [self view];
    NSArray *slayList = [view slayList];
    int		type = [[compPopUp selectedItem] tag];
    //id		change;

    [factorField setEnabled:(type == VImageJPEG) ? YES : NO];
    if (type != VImageJPEG)
        [factorField setStringValue:@"0"];

    /* set lock for all objects */
    //change = [[LockGraphicsChange alloc] initGraphicView:view];
    //[change startChange];
        cnt = [slayList count];
        for ( l=0; l<cnt; l++ )
        {   NSMutableArray *slist = [slayList objectAtIndex:l];

            if ( ![[[view layerList] objectAtIndex:l] editable] )
                continue;
            for ( i=[slist count]-1; i>=0; i-- )
            {   VImage	*g = [slist objectAtIndex:i];

                if ( [g respondsToSelector:@selector(setFileType:)] )
                {   [g setFileType:type];
                    if (type != VImageJPEG)
                        [g setCompressionFactor:0.0];
                }
            }
        }
    //[change endChange];

    [nameField setStringValue:[graphic label]];

    [[(App*)NSApp currentDocument] setDirty:YES];
    [view drawAndDisplay];
}

- (void)displayWillEnd
{ 
}

@end
