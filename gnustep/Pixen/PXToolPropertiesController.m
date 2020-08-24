//
//  PXToolPropertiesController.m
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
// Fri Mar 12 2004.


// This is now a real singleton.
// It just manage the panel with its position and  add/remove propertyView(s)
// Fabien


#import "PXToolPropertiesController.h"
#import "PXToolPropertiesView.h"
#import "PXToolSwitcher.h"
#import "PXToolPaletteController.h"
#import "PXTool.h"

#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSUserDefaults.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSPanel.h>

static PXToolPropertiesController *leftInstance = nil;
static PXToolPropertiesController *rightInstance = nil;

@interface PXToolPropertiesController (Private)
-(void) _toolDidChange:(NSNotification *) notification;
@end

@implementation PXToolPropertiesController (Private)
- (void) _toolDidChange:aNotification
{
	NSMutableString *title = [NSMutableString string];
	
	[title appendString:[[[aNotification userInfo] objectForKey:@"newTool"] name]];
	[title appendString:@" ("];
	if (self == leftInstance) { // Kind of a HACK
		[title appendString:NSLocalizedString(@"LEFT", @"Left")];
	} else {
		[title appendString:NSLocalizedString(@"RIGHT", @"Right")];
	}
	[title appendString:@") "];
	[title appendString:NSLocalizedString(@"PROPERTIES", @"Properties")];
	[panel setTitle:title];
	if (! [[[aNotification userInfo] objectForKey:@"newTool"] propertiesView] )
		[self setPropertiesView:[[PXToolPropertiesView alloc] init]];
	else
    {
		[self setPropertiesView:[[[aNotification userInfo] objectForKey:@"newTool"] propertiesView]];
    }
}

@end


@implementation PXToolPropertiesController

-(void) awakeFromNib
{
	[panel setBecomesKeyOnlyIfNeeded:YES];
	
	if (self == leftInstance) { // Kind of a HACK
		[panel setFrameAutosaveName:@"PXLeftToolPropertiesFrame"];
	} else {
		[panel setFrameAutosaveName:@"PXRightToolPropertiesFrame"];
	}
	
	//propbably not here to do that ??? 
	
	// I think it's the right place... where else would it go?
	//
	// Oh, and this whole series of Tool Properties classes is just about the worst
	// design EVER.  Andy, YOU FAIL IT.  They're all NSViews which are acting as both
	// models and controllers. >_<
	//
	//      -Ian
	
	[self setPropertiesView: [[PXToolPropertiesView alloc] init]];
	
}						 

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

+ (id)_toolPropertiesPanelWithSide:(BOOL)leftRight
{
	PXToolPropertiesController **instance = leftRight ? &leftInstance : &rightInstance; // I heart pointers.  No, seriously, I do.

	if (!*instance) {
		
		if (! (*instance = [[self alloc] init]) )
			return nil;
		
		if ( ! [NSBundle loadNibNamed:@"PXToolProperties" owner:*instance] )
		{
			// The user is, unfortunately, quite cold at this point.
			//NSLog(@"warm the user here !?? !!");
			[*instance dealloc];
			return nil;
		}
	}
	
	return *instance;
}

+ (id)leftToolPropertiesController
{
	id object = [self _toolPropertiesPanelWithSide:YES];
	[[NSNotificationCenter defaultCenter] addObserver:object
											 selector:@selector(_toolDidChange:) 
												 name:PXToolDidChangeNotificationName 
											   object:[[PXToolPaletteController sharedToolPaletteController] leftSwitcher]];
	[[[PXToolPaletteController sharedToolPaletteController] leftSwitcher] requestToolChangeNotification];
	return object;
}

+ (id)rightToolPropertiesController
{
	id object = [self _toolPropertiesPanelWithSide:NO];
	[[NSNotificationCenter defaultCenter] addObserver:object
											 selector:@selector(_toolDidChange:) 
												 name:PXToolDidChangeNotificationName 
											   object:[[PXToolPaletteController sharedToolPaletteController] rightSwitcher]];
	[[[PXToolPaletteController sharedToolPaletteController] rightSwitcher] requestToolChangeNotification];
	return object;
}


//Accessor
-(NSPanel *) propertiesPanel
{
	return panel;
}

- (void)setPropertiesView:(id)propertiesView
{
	NSRect newPropertiesFrame = [propertiesView    frame] ;
	//NSRect newViewFrame = NSMakeRect(0, 0, newPropertiesFrame.size.width, newPropertiesFrame.size.height);
	
	NSRect newPanelFrame = [NSPanel frameRectForContentRect:NSMakeRect([panel frame].origin.x, [panel frame].origin.y, newPropertiesFrame.size.width, newPropertiesFrame.size.height)
												  styleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask];								 
	//Waring chek mem leaks  !!!
	[[propertiesView view] retain]; // What?!  (I know this isn't actually going to leak, because there is a finite, very small number of these things, but seriously!  HACK ALERT)
	[panel setContentView: [propertiesView view]];	
	[panel setFrame:newPanelFrame display:YES animate:YES];
}


@end



