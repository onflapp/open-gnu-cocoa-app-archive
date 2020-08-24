// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLConsoleController.h"
#import <SenFoundation/SenFoundation.h>

#import <TaskRequest.h>

static CVLConsoleController	*uniqueConsoleController = nil;

//-------------------------------------------------------------------------------------

@implementation CVLConsoleController

+ (void) initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"NO", @"ShowConsole", @"YES", @"AutoPopupConsole", nil]];
}

+ (CVLConsoleController *) sharedConsoleController
{
    if ( uniqueConsoleController == nil ) {
        uniqueConsoleController = [[self alloc] init];
    }
    return uniqueConsoleController;
}

- (id) init
{
    if ( (self = [self initWithWindowNibName:@"CVLConsole"]) ) {
        (void)[self window]; // Forces loading of window; we need this in order to record all logs, even if window is not yet visible
    }

    return self;
}

- (void) windowDidLoad
// Normally we shouldn't need to implement this; we could simply call [self setWindowFrameAutosaveName:@"ConsolePanel"] in init
// BUT... if we do it, superclass' implementation does reposition window if it is not fully visible on screen,
// which is VERY annoyable. (patch does not work on OSX...)
{
    NSUserDefaults *theUserDefaults = nil;
        
    theUserDefaults = [NSUserDefaults standardUserDefaults];
    
    [super windowDidLoad];
    [self setWindowFrameAutosaveName:@"ConsolePanel"];
    [[self window] setFrameUsingName:@"ConsolePanel"];
    [[self window] setExcludedFromWindowsMenu:YES];
    [autoPopupSwitch setState:[theUserDefaults boolForKey:@"AutoPopupConsole"]];
    [logRequestsSwitch setState:[theUserDefaults boolForKey:@"LogRequests"]];
    [TaskRequest setLogger:([logRequestsSwitch state] ? self:nil)];

    [popupTimeoutFormCell setFloatValue:[theUserDefaults floatForKey:@"ConsolePopupTimeout"]];
}

- (IBAction) clearText:(id)sender
{
    NSMutableAttributedString	*attributedString = [text textStorage];
    NSRange						all;

    all.location = 0;
    all.length = [attributedString length];
    [attributedString deleteCharactersInRange:all];
}

- (IBAction) toggleAutoPopup:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:[autoPopupSwitch state] forKey:@"AutoPopupConsole"];
    if(![autoPopupSwitch state])
        [NSRunLoop cancelPreviousPerformRequestsWithTarget:[self window] selector:@selector(orderOut:) object:nil];
    else{
        float	timeout = [popupTimeoutFormCell floatValue];

        if(timeout > 0.0)
            [[self window] performSelector:@selector(orderOut:) withObject:nil afterDelay:timeout];
    }
}

- (IBAction) showWindow:(id)sender
{
    [super showWindow:sender];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ShowConsole"];
    [NSRunLoop cancelPreviousPerformRequestsWithTarget:[self window] selector:@selector(orderOut:) object:nil];
}

- (void) output:(NSString *)aString
{
    [self output:aString bold:NO];
}

- (void) output:(NSString *)aString bold:(BOOL)flag
{
    [self output:aString bold:flag error:NO italic:NO];
}

- (void) outputError:(NSString *)aString
{
    [self output:aString bold:NO error:YES italic:NO];
}

- (void) output:(NSString *)aString bold:(BOOL) flag error:(BOOL)flagE italic:(BOOL)flagI
{	
    NSMutableAttributedString	*attributedString;
    NSRange						all;
    int							length = 0;

    [NSRunLoop cancelPreviousPerformRequestsWithTarget:[self window] selector:@selector(orderOut:) object:nil];
    attributedString = [[NSMutableAttributedString alloc] initWithString:[[[NSCalendarDate calendarDate] descriptionWithCalendarFormat:@"%H:%M:%S: "] stringByAppendingString:aString]];
    all.location = 0;
    all.length = [attributedString length];

    if(flag)
        [attributedString applyFontTraits:NSBoldFontMask range:all];
    else
        [attributedString applyFontTraits:NSUnboldFontMask range:all];

    if(flagI)
        [attributedString applyFontTraits:NSItalicFontMask range:all];
    else
        [attributedString applyFontTraits:NSUnitalicFontMask range:all];

    if(flagE){
        static NSColor	*myRedColor = nil;

        if(!myRedColor)
            ASSIGN(myRedColor, [NSColor colorWithCalibratedRed:0.74 green:0.0 blue:0.0 alpha:1.0]);
        [attributedString addAttribute:NSForegroundColorAttributeName value:myRedColor range:all];
    }

    [[text textStorage] appendAttributedString:attributedString];
    [attributedString release];
    length = [[text textStorage] length];
    all.location = length - 1; // (length >= 2 ? length - 2 : length - 1);
    all.length = 1;
    [text scrollRangeToVisible:all];
    if([autoPopupSwitch state]){
        float	timeout = [popupTimeoutFormCell floatValue];

        if(![[self window] isVisible])
            [[self window] orderFront:nil]; // We don't want focus on it
        if(timeout > 0.0)
            [[self window] performSelector:@selector(orderOut:) withObject:nil afterDelay:timeout];
    }
}

- (IBAction) updatePopupTimeout:(id)sender
{
    float	timeout = [popupTimeoutFormCell floatValue];

    [NSRunLoop cancelPreviousPerformRequestsWithTarget:[self window] selector:@selector(orderOut:) object:nil];
    [[NSUserDefaults standardUserDefaults] setFloat:timeout forKey:@"ConsolePopupTimeout"];
    if([autoPopupSwitch state] && timeout > 0.0)
        [[self window] performSelector:@selector(orderOut:) withObject:nil afterDelay:timeout];
}

- (void) windowWillClose:(NSNotification *)notification
{
    [NSRunLoop cancelPreviousPerformRequestsWithTarget:[self window] selector:@selector(orderOut:) object:nil];
    if([[NSApplication sharedApplication] isRunning])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ShowConsole"];
}

- (float) splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedCoord ofSubviewAt:(int)offset
{
    return NSHeight([[[sender subviews] objectAtIndex:0] frame])/* + [sender dividerThickness]*/;
}

- (float) splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedCoord ofSubviewAt:(int)offset
{
    return NSHeight([[[sender subviews] objectAtIndex:0] frame])/* + [sender dividerThickness]*/;
}

- (BOOL) splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
    if([[sender subviews] indexOfObject:subview] == 0)
        return YES; // Only subview containing button can be collapsed
    return NO;
}

- (void) splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    if(![sender isSubviewCollapsed:[[sender subviews] objectAtIndex:0]])
	{
        float	fixedHeight = [self splitView:sender constrainMinCoordinate:0 ofSubviewAt:0];
        NSSize	newSize = [sender frame].size;

        [[[sender subviews] objectAtIndex:0] setFrameSize:NSMakeSize(newSize.width, fixedHeight)];
        [[[sender subviews] objectAtIndex:1] setFrameSize:NSMakeSize(newSize.width, newSize.height - fixedHeight - [sender dividerThickness])];
    }
	[sender adjustSubviews];
}

- (BOOL) showConsoleAtStartup
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowConsole"] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"AutoPopupConsole"];
}

- (IBAction) toggleRequestLogging:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:[logRequestsSwitch state] forKey:@"LogRequests"];
    [TaskRequest setLogger:([logRequestsSwitch state] ? self:nil)];
}

- (void) taskRequestWillLaunch:(TaskRequest *)request
{
    NSTask		*task = [request task];
    NSString	*cmdString = [NSString stringWithFormat:@"%@> %@ %@\n", [task currentDirectoryPath], [task launchPath], [[task arguments] componentsJoinedByString:@" "]];
    
    [self output:cmdString bold:YES error:NO italic:YES];
}

@end

//-------------------------------------------------------------------------------------
