
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "ProgressPanelController.h"
#import <Request.h>
#import <TaskRequest.h>
#import <CVLOpendiffRequest.h>
#import <SenFoundation/SenFoundation.h>
#import <AppKit/AppKit.h>


static ProgressPanelController *theController = nil;
//-------------------------------------------------------------------------------------
@interface ProgressPanelController(Private)
- (void) requestStateChanged:(NSNotification *)notification;
- (void) delayedRemoveRequest:(Request *)theRequest;
- (void) removeRequest:(Request *)theRequest;
@end

//-------------------------------------------------------------------------------------

@implementation ProgressPanelController

+ (void) initialize
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"NO", @"ShowProgressPanel", nil]];
}

+ (id) sharedProgressPanelController
{
    if(!theController)
      theController = [[ProgressPanelController alloc] init];

    return theController;
}

- (id) init
{
    if ( (self = [self initWithWindowNibName:@"ProgressPanel"]) ) {
        requests = [[NSMutableArray allocWithZone:[self zone]] init];
#ifdef JA_PATCH
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(requestStateChanged:)
                                                     name:@"RequestStateDidChange"
                                                   object:nil];
#else
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(requestStateChanged:)
                                                     name:@"RequestStateChanged"
                                                   object:nil];
#endif
        [self setWindowFrameAutosaveName:@"ProgressPanel"];
    }

    return self;
}

- (void) dealloc
{
    RELEASE(requests);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"RequestStateChanged" object:nil];
    
    [super dealloc];
}

- (void) windowDidLoad
{
    [super windowDidLoad];

    [(NSTextFieldCell *)[[tableView tableColumnWithIdentifier:@"operation"] dataCell] setTextColor:[NSColor darkGrayColor]];
    [(NSTextFieldCell *)[[tableView tableColumnWithIdentifier:@"filename"] dataCell] setTextColor:[NSColor blackColor]];
    [(NSTextFieldCell *)[[tableView tableColumnWithIdentifier:@"state"] dataCell] setTextColor:[NSColor darkGrayColor]];
    //[tableView sizeLastColumnToFit];

    [tableView reloadData];
    [self tableViewSelectionDidChange:nil];
    [[tableView enclosingScrollView] setNeedsDisplay:YES]; // If we redisplay only the tableView, there is a small glitch due to remove of headerView
}

- (IBAction) showWindow:(id)sender;
{
    [super showWindow:sender];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ShowProgressPanel"];
}

- (void) updateRequest:(Request *)aRequest
{
    [tableView reloadData];
    [self tableViewSelectionDidChange:nil];
    [tableView setNeedsDisplay:YES];
}

- (void) requestStateChanged:(NSNotification *)notification
{
    Request	*request = [notification object];

    if(![requests containsObject:request])
        [requests addObject:request];

#ifdef JA_PATCH
    if([[request currentState] isTerminal])
#else
    if([request state] == STATE_ENDED)
#endif
        [self delayedRemoveRequest:request];

    [self updateRequest:request];
}

- (void) delayedRemoveRequest:(Request *)theRequest
{
    [self performSelector:@selector(removeRequest:) withObject:theRequest afterDelay:1.0 inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
}

- (void) removeRequest:(Request *)theRequest
{
    [theRequest retain];
    [requests removeObject:theRequest];
    [tableView reloadData];
    [self tableViewSelectionDidChange:nil];
    [tableView setNeedsDisplay:YES];
    [theRequest release];
    if ( isNilOrEmpty(requests) ) {
        SEN_LOG_CHECKPOINT();
    }
}

- (int) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [requests count];
}

- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if([[tableColumn identifier] isEqualToString:@"operation"])
        return [[requests objectAtIndex:row] cmdTitle];
    else if([[tableColumn identifier] isEqualToString:@"filename"])
        return [[requests objectAtIndex:row] summary];
    else if([[tableColumn identifier] isEqualToString:@"state"])
        return [[requests objectAtIndex:row] stateString];
    else
        return nil;
}

- (IBAction) interruptSelectedRequests:(id)sender
{
    NSEnumerator	*anEnum = [tableView selectedRowEnumerator];
    id				anObject;
    NSMutableArray	*selectedRequests = [NSMutableArray array];

    while ( (anObject = [anEnum nextObject]) )
        [selectedRequests addObject:[requests objectAtIndex:[anObject intValue]]];

    anEnum = [selectedRequests objectEnumerator];
    while ( (anObject = [anEnum nextObject]) )
        [anObject cancel];
}

- (BOOL) tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
    return [[requests objectAtIndex:rowIndex] canBeCancelled];
}

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSEnumerator	*anEnum = [tableView selectedRowEnumerator];
    NSNumber		*aRow;
    BOOL			canBeCancelled = NO;

    while ( (aRow = [anEnum nextObject]) ) {
        if([[requests objectAtIndex:[aRow intValue]] canBeCancelled]){
            canBeCancelled = YES;
            break;
        }
    }

    [killButton setEnabled:canBeCancelled];
    
    // If there is a selection then enable the "More Info" button.
    if ( [tableView selectedRow] >= 0 ) {
        [moreInfoButton setEnabled:YES];
    } else {
        [moreInfoButton setEnabled:NO];
    }
}

- (IBAction) moreInfo:(id)sender
    /*" This is an action method that displays in a sheet panel more information
        about the selected request. Mainly we are talking about the instance 
        variables some of which have been converted to informational strings. 
        This is mostly used for debugging purposes.
    "*/
{
    NSString *aMsg = nil;
    Request *aRequest = nil;
    int aRow = 0;
    
    aRow = [tableView selectedRow];
    if ( aRow >= 0 ) {
        SEN_ASSERT_CONDITION((aRow < (int)[requests count]));
        aRequest = [requests objectAtIndex:aRow];
        aMsg = [NSString stringWithFormat:@"%@",[aRequest moreInfoString]];
        NSBeginInformationalAlertSheet(@"More Info", nil, nil, nil, 
                                   [self window], nil, NULL, NULL, NULL, aMsg);        
    }
}


@end

//-------------------------------------------------------------------------------------

@implementation ProgressPanelController (WindowDelegate)

- (void) windowWillClose:(NSNotification *)notification
{
    if([[NSApplication sharedApplication] isRunning])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ShowProgressPanel"];
}

@end

//-------------------------------------------------------------------------------------

