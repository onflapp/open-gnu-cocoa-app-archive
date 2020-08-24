/* SenFormControllerConnectInspector.m created by ja on Tue 24-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenFormControllerConnectInspector.h"
#ifndef RHAPSODY
#ifdef PANTHER
#import <SenFormControllerConnector.h>
#else /* Not PANTHER */
#import <SenPanels.subproj/SenFormControllerConnector.h>
#endif /* End PANTHER */
#else /* Not MACOSX */
#import <SenPanels/SenFormControllerConnector.h>
#endif /* End MACOSX */
#import <InterfaceBuilder/IBInspectorManager.h>

@implementation SenFormControllerConnectInspector
- (id)init
{
    if ( (self=[super init]) ) {
        [NSBundle loadNibNamed:@"SenFormControllerConnectInspector" owner:self];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

- (void)awakeFromNib
{
    [tableView setDataSource:self];
    [tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0];
    //    [super awakeFromNib];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    [cachedConnectors autorelease];
    cachedConnectors = [[[NSApp activeDocument] connectorsForSource:[self object] ofClass:[SenFormControllerConnector class]] retain];
    return [cachedConnectors count];
}

- (void)revert:(id)sender
{
    [super revert:sender];
    [tableView reloadData];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    SenFormControllerConnector *connector;

    connector=[cachedConnectors objectAtIndex:rowIndex];
    if (aTableColumn==editorColumn) {
        NSString *objectName;

        objectName=[[NSApp activeDocument] nameForObject:[connector destination]];
        if ((!objectName) || ([objectName isEqual:@""])) {
            objectName=[[[connector destination] class] description];
        }
        return objectName;
    }
    if (aTableColumn==labelColumn) {
        return [connector label];
    }
    return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    SenFormControllerConnector *connector;

    connector=[cachedConnectors objectAtIndex:rowIndex];
    if (aTableColumn==labelColumn) {
        [connector setLabel:anObject];
    }
}

- (BOOL)wantsButtons
{
    return NO;
}

- (void)connect:(id)sender
{
    SenFormControllerConnector *connector;

    connector=[[SenFormControllerConnector alloc] init];
    [connector setSource:[NSApp connectSource]];
    [connector setDestination:[NSApp connectDestination]];
    [connector setLabel:@"key"];

    [[NSApp activeDocument] addConnector:connector];

    [tableView reloadData];
    [connector release];
}

- (void)disconnect:(id)sender
{
    int rowIndex=[tableView selectedRow];
    if (rowIndex!=-1) {
        SenFormControllerConnector *connector;

        connector=[cachedConnectors objectAtIndex:rowIndex];
        [[NSApp activeDocument] removeConnector:connector];
        [NSApp stopConnecting];
        [tableView reloadData];
    }
}

- (void)showConnection:(id)sender
{
    int rowIndex=[tableView selectedRow];
    if (rowIndex!=-1) {
        SenFormControllerConnector *connector;

        connector=[cachedConnectors objectAtIndex:rowIndex];
        [NSApp displayConnectionBetween:[connector source] and:[connector destination]];
    }
}
@end
