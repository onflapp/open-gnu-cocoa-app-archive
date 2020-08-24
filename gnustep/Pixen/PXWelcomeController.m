//
//  PXWelcomeController.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sat Jun 12 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXWelcomeController.h"

@implementation PXWelcomeController

/* -----------------------------------------------------------------------------
	Constructor:
   -------------------------------------------------------------------------- */

-(id) init
{
	if( self = [super initWithWindowNibName:@"PXDiscoverPixen"] )
	{
		tabView = nil;
		itemsList = [[NSMutableDictionary alloc] init];
		baseWindowName = [@"Welcome" retain];
		autosaveName = [@"org.opensword" retain];
	}
	
	return self;
}


/* -----------------------------------------------------------------------------
	Destructor:
   -------------------------------------------------------------------------- */

-(void)	dealloc
{
	[itemsList release];
	[baseWindowName release];
	[autosaveName release];
	[super dealloc];
}


/* -----------------------------------------------------------------------------
	awakeFromNib:
		This object and all others in the NIB have been created and hooked up.
		Fetch the window name so we can modify it to indicate the current
		page, and add our toolbar to the window.
		
		This method is the great obstacle to making UKPrefsPanel an NSTabView
		subclass. When the tab view's awakeFromNib method is called, the
		individual tabs aren't set up yet, meaning mapTabsToToolbar gives us an
		empty toolbar. ... bummer.
		
		If anybody knows how to fix this, you're welcome to tell me.
   -------------------------------------------------------------------------- */

-(void)	awakeFromNib
{
	NSString*		key;
	
	[prev setEnabled:NO];
	
	// Generate a string containing the window's title so we can display the original window title plus the selected pane:
	/*wndTitle = [[tabView window] title];
	if( [wndTitle length] > 0 )
	{
		[baseWindowName release];
		baseWindowName = [[NSString stringWithFormat: @"%@ : ", wndTitle] retain];
	}*/
	
	// Make sure our autosave-name is based on the one of our prefs window:
	[self setAutosaveName: [[tabView window] frameAutosaveName]];
	
	// Select the preferences page the user last had selected when this window was opened:
	key = [NSString stringWithFormat: @"%@.prefspanel.recentpage", autosaveName];
	[tabView selectTabViewItemAtIndex: 0];
	[tabView setTabViewType:NSNoTabsNoBorder];
	
	// Actually hook up our toolbar and the tabs:
	//[self mapTabsToToolbar];
	
	/*id enumerator = [[[[tabView tabViewItemAtIndex:[tabView indexOfTabViewItem:[tabView selectedTabViewItem]]] view] subviews] objectEnumerator], current;
	while (current = [enumerator nextObject])
	{
		if ([current isKindOfClass:[NSBox class]])
		{
			[[self window] setContentSize:NSMakeSize([[[self window] contentView] frame].size.width, [current frame].size.height + 42)];
			[current setFrameOrigin:NSMakePoint([current frame].origin.x, 42)];
			[tabView setFrameOrigin:NSMakePoint([current frame].origin.x, 0)];
			[image setFrameOrigin:NSMakePoint([current frame].origin.x - 16, [[[self window] contentView] frame].size.height - [image frame].size.height)];
		}
	}*/
}


/* -----------------------------------------------------------------------------
	mapTabsToToolbar:
		Create a toolbar based on our tab control.
		
		Tab title		-   Name for toolbar item.
		Tab identifier  -	Image file name and toolbar item identifier.
   -------------------------------------------------------------------------- */

-(void) mapTabsToToolbar
{
    // Create a new toolbar instance, and attach it to our document window 
    NSToolbar		*toolbar =[[tabView window] toolbar];
	int				itemCount = 0,
					x = 0;
	NSTabViewItem	*currPage = nil;
	
	if( toolbar == nil )   // No toolbar yet? Create one!
		toolbar = [[[NSToolbar alloc] initWithIdentifier: [NSString stringWithFormat: @"%@.prefspanel.toolbar", autosaveName]] autorelease];
	
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    //[toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
	
	// Set up item list based on Tab View:
	itemCount = [tabView numberOfTabViewItems];
	
	[itemsList removeAllObjects];	// In case we already had a toolbar.
	
	for( x = 0; x < itemCount; x++ )
	{
		NSTabViewItem*		theItem = [tabView tabViewItemAtIndex:x];
		NSString*			theIdentifier = [theItem identifier];
		NSString*			theLabel = [theItem label];
		
		[itemsList setObject:theLabel forKey:theIdentifier];
	}
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Attach the toolbar to the document window 
    [[tabView window] setToolbar: toolbar];
	
	// Set up window title:
	currPage = [tabView selectedTabViewItem];
	if( currPage == nil )
		currPage = [tabView tabViewItemAtIndex:0];
	[[tabView window] setTitle: [baseWindowName stringByAppendingString: [currPage label]]];
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3
	if( [toolbar respondsToSelector: @selector(setSelectedItemIdentifier:)] )
		[toolbar setSelectedItemIdentifier: [currPage identifier]];
	#endif
}


/* -----------------------------------------------------------------------------
	orderFrontPrefsPanel:
		IBAction to assign to "Preferences..." menu item.
   -------------------------------------------------------------------------- */

-(IBAction)		orderFrontPrefsPanel: (id)sender
{
	[[tabView window] makeKeyAndOrderFront:sender];
}


/* -----------------------------------------------------------------------------
	setTabView:
		Accessor for specifying the tab view to query.
   -------------------------------------------------------------------------- */

-(void)			setTabView: (NSTabView*)tv
{
	tabView = tv;
}


-(NSTabView*)   tabView
{
	return tabView;
}


/* -----------------------------------------------------------------------------
	setAutosaveName:
		Name used for saving state of prefs window.
   -------------------------------------------------------------------------- */

-(void)			setAutosaveName: (NSString*)name
{
	[name retain];
	[autosaveName release];
	autosaveName = name;
}


-(NSString*)	autosaveName
{
	return autosaveName;
}


/* -----------------------------------------------------------------------------
	toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
		Create an item with the proper image and name based on our list
		of tabs for the specified identifier.
   -------------------------------------------------------------------------- */

-(NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem   *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    NSString*		itemLabel;
	
    if( (itemLabel = [itemsList objectForKey:itemIdent]) != nil )
	{
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: itemLabel];
		[toolbarItem setPaletteLabel: itemLabel];
		[toolbarItem setTag:[tabView indexOfTabViewItemWithIdentifier:itemIdent]];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: itemLabel];
		[toolbarItem setImage: [NSImage imageNamed:itemIdent]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(changePanes:)];
    }
	else
	{
		// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
		// Returning nil will inform the toolbar this kind of item is not supported 
		toolbarItem = nil;
    }
	
    return toolbarItem;
}


/* -----------------------------------------------------------------------------
	toolbarSelectableItemIdentifiers:
		Make sure all our custom items can be selected. NSToolbar will
		automagically select the appropriate item when it is clicked.
   -------------------------------------------------------------------------- */

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3
-(NSArray*) toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{
	return [itemsList allKeys];
}
#endif


/* -----------------------------------------------------------------------------
	changePanes:
		Action for our custom toolbar items that causes the window title to
		reflect the current pane and the proper pane to be shown in response to
		a click.
   -------------------------------------------------------------------------- */

-(IBAction)	changePanes: (id)sender
{
	[[tabView window] setTitle: [baseWindowName stringByAppendingString: [sender label]]];
	
	//key = [NSString stringWithFormat: @"%@.prefspanel.recentpage", autosaveName];
	//[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:key];
	
	[tabView selectTabViewItemAtIndex: [sender tag]];
}


/* -----------------------------------------------------------------------------
	toolbarDefaultItemIdentifiers:
		Return the identifiers for all toolbar items that will be shown by
		default.
		This is simply a list of all tab view items in order.
   -------------------------------------------------------------------------- */

-(NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
	int					itemCount = [tabView numberOfTabViewItems],
						x;
	NSTabViewItem*		theItem = [tabView tabViewItemAtIndex:0];
	//NSMutableArray*	defaultItems = [NSMutableArray arrayWithObjects: [theItem identifier], NSToolbarSeparatorItemIdentifier, nil];
	NSMutableArray*	defaultItems = [NSMutableArray array];
	
	for( x = 0; x < itemCount; x++ )
	{
		theItem = [tabView tabViewItemAtIndex:x];
		
		[defaultItems addObject: [theItem identifier]];
	}
	
	return defaultItems;
}


/* -----------------------------------------------------------------------------
	toolbarAllowedItemIdentifiers:
		Return the identifiers for all toolbar items that *can* be put in this
		toolbar. We allow a couple more items (flexible space, separator lines
		etc.) in addition to our custom items.
   -------------------------------------------------------------------------- */

-(NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    NSMutableArray*		allowedItems = [[itemsList allKeys] mutableCopy];
	
	[allowedItems addObjectsFromArray: [NSArray arrayWithObjects: NSToolbarSeparatorItemIdentifier,
				NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
				NSToolbarCustomizeToolbarItemIdentifier, nil] ];
	
	return allowedItems;
}

- (IBAction)next:sender
{
	if ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0)
	{
		[prev setEnabled:YES];
	}
	
	if ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 6)
	{
		[next setTitle:NSLocalizedString(@"Close", @"Close")];
	}
	
	if ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 7)
	{
		[self close];
	}
	else
	{
		[tabView selectNextTabViewItem:sender];
	}
}

- (IBAction)prev:sender
{
	if ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1)
	{
		[prev setEnabled:NO];
	}
	
	if ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 7)
	{
		[next setTitle:@"Next"];
	}
	[tabView selectPreviousTabViewItem:sender];
}

@end
