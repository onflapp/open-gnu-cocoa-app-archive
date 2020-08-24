//
//  PXToolPaletteController.m
//  Pixen-XCode
//
// Copyright (c) 2004 Open Sword Group

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, 
//copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
// to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//  Author : Andy Matuschak 


#import "PXToolPaletteController.h"
#import "PXToolSwitcher.h"
#import "PXPanelManager.h"


#import <Foundation/NSNotification.h>
#import <Foundation/NSUserDefaults.h>

#import <AppKit/NSButton.h>
#import <AppKit/NSColorPanel.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSPanel.h>


static PXToolPaletteController *singleInstance = nil;

@interface PXToolPaletteController (Private)
- (void)_openRightToolSwitcher;
- (void)_closeRightToolSwitcher;
- (void)_paletteControllerChoseLeftColor:(NSNotification*) aNotification;
- (void)_paletteControllerChoseRightColor:(NSNotification *)aNotification;
@end 


//
// PXToolPalette : Private categories
//

@implementation PXToolPaletteController (Private)

- (void)_openRightToolSwitcher
{
	[minimalView setFrameOrigin:NSMakePoint(0, [rightSwitchView frame].size.height)];
	[rightSwitchView setFrameOrigin:NSMakePoint(0, 0)];
	[panel setFrame:NSMakeRect([panel frame].origin.x, [panel frame].origin.y-[rightSwitchView frame].size.height, [panel frame].size.width, [panel frame].size.height+[rightSwitchView frame].size.height) 
			display:YES
			animate:NO];
	[triangle setState:NSOnState];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PXRightToolSwitcherIsOpen"];
}

- (void)_closeRightToolSwitcher
{
	[minimalView setFrameOrigin:NSMakePoint(0, 0)];
	[rightSwitchView setFrameOrigin:NSMakePoint(0, 0-[rightSwitchView frame].size.height)];
	[panel setFrame:NSMakeRect([panel frame].origin.x, [panel frame].origin.y+[rightSwitchView frame].size.height, [panel frame].size.width, [panel frame].size.height-[rightSwitchView frame].size.height) 
			display:YES 
			animate:NO];
	
	[triangle setState:NSOffState];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PXRightToolSwitcherIsOpen"];
}

- (void)_paletteControllerChoseLeftColor:(NSNotification*) aNotification
{
	[leftSwitcher setColor:[[aNotification userInfo] objectForKey:@"color"]];
}

- (void)_paletteControllerChoseRightColor:(NSNotification *)aNotification
{
	[rightSwitcher setColor:[[aNotification userInfo] objectForKey:@"color"]];
}

@end


//
// PXToolPaletteController implementation
//

@implementation PXToolPaletteController


-(id) init
{
	if ( singleInstance ) 
    {
		[self dealloc];
		return singleInstance;
    }
	
	if ( ! (self = [super init] ) ) 
		return nil;
	
	if ( ! [NSBundle loadNibNamed:@"PXToolPalette" owner:self] ) 
    {
		//NSLog(@"warm the user here ?? ");
		[self dealloc];
		return nil;
    }
	
	singleInstance = self;
	return singleInstance;
}


- (void)dealloc
{
    [leftSwitcher release];
    [rightSwitcher release];
    [super dealloc];
}

+(id) sharedToolPaletteController
{
	if(! singleInstance ) 
		singleInstance = [[self alloc] init];
	
	return singleInstance;
}

- (void)leftToolDoubleClicked:notification
{
	[[PXPanelManager sharedManager] toggleLeftToolProperties:nil];
}

- (void)rightToolDoubleClicked:notification
{
	[[PXPanelManager sharedManager] toggleRightToolProperties:nil];
}

-(void) awakeFromNib
{
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];  
	[panel setBecomesKeyOnlyIfNeeded:YES];
	
	[leftSwitcher useToolTagged:PXPencilToolTag];
	[rightSwitcher useToolTagged:PXEraserToolTag];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(_paletteControllerChoseLeftColor:)
												 name:@"PXPaletteLeftColorChosen" 
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(_paletteControllerChoseRightColor:) 
												 name:@"PXPaletteRightColorChosen" 
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(leftToolDoubleClicked:)
												 name:@"PXToolDoubleClicked" 
											   object:leftSwitcher];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(rightToolDoubleClicked:) 
												 name:@"PXToolDoubleClicked" 
											   object:rightSwitcher];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"PXRightToolSwitcherIsOpen"]) 
		[self _openRightToolSwitcher]; 
	
	[panel setFrameAutosaveName:@"PXToolPaletteFrame"];
	keyMask = 0x0;
}


//Action method
- (IBAction)disclosureClicked:sender
{
	if([sender state] == NSOnState) 
		[self _openRightToolSwitcher]; 
	else 
		[self _closeRightToolSwitcher]; 
}


//Events methods
- (void)keyDown:(NSEvent *)event
{
	if([event modifierFlags] & NSControlKeyMask)
		[rightSwitcher keyDown:event];
	else
		[leftSwitcher keyDown:event];
}

- (BOOL)keyWasDown:(unsigned int)mask
{
    return (keyMask & mask) == mask;
}

- (BOOL)isMask:(unsigned int)newMask upEventForModifierMask:(unsigned int)mask
{
    return [self keyWasDown:mask] && ((newMask & mask) == 0x0000);
}

- (BOOL)isMask:(unsigned int)newMask downEventForModifierMask:(unsigned int)mask
{
    return ![self keyWasDown:mask] && ((newMask & mask) == mask);
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	if([self isMask:[theEvent modifierFlags] downEventForModifierMask:NSAlternateKeyMask])
    {
		[leftSwitcher optionKeyDown];
		[rightSwitcher optionKeyDown];
		keyMask |= NSAlternateKeyMask;
    }
	else if([self isMask:[theEvent modifierFlags] upEventForModifierMask:NSAlternateKeyMask])
    {
		[leftSwitcher optionKeyUp];
		[rightSwitcher optionKeyUp];
		keyMask ^= NSAlternateKeyMask;
    }
    
	if([self isMask:[theEvent modifierFlags] downEventForModifierMask:NSShiftKeyMask])
    {
		[leftSwitcher shiftKeyDown];
		[rightSwitcher shiftKeyDown];
		keyMask |= NSShiftKeyMask;
    }
	else if([self isMask:[theEvent modifierFlags] upEventForModifierMask:NSShiftKeyMask])
    {
		[leftSwitcher shiftKeyUp];
		[rightSwitcher shiftKeyUp];
		keyMask ^= NSShiftKeyMask;
    }
}

//
//Accessors methods
//
-(id) leftTool
{
	return [leftSwitcher tool];
}

-(id)rightTool
{
	return [rightSwitcher tool];
}

- (PXToolSwitcher *) leftSwitcher
{
	return leftSwitcher;
}

- (PXToolSwitcher *) rightSwitcher
{
	return rightSwitcher;
}

-(NSPanel *) toolPanel
{
	return panel;
}


@end
