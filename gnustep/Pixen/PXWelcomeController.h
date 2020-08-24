//
//  PXWelcomeController.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sat Jun 12 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

// Based upon UKPrefsPanel by M. Uli Kusterer

#import <AppKit/AppKit.h>


@interface PXWelcomeController : NSWindowController
{
	IBOutlet NSTabView*		tabView;			// The tabless tab-view that we're a switcher for.
	IBOutlet id image;
	IBOutlet id next, prev;
	
	NSMutableDictionary*	itemsList;			// Auto-generated from tab view's items.
	NSString*				baseWindowName;		// Auto-fetched at awakeFromNib time. We append a colon and the name of the current page to the actual window title.
	NSString*				autosaveName;		// Identifier used for saving toolbar state and current selected page of prefs window.
}

// Accessors for specifying the tab view: (you should just hook these up in IB)
-(void)			setTabView: (NSTabView*)tv;
-(NSTabView*)   tabView;

-(void)			setAutosaveName: (NSString*)name;
-(NSString*)	autosaveName;

// Action for hooking up this object and the menu item:
-(IBAction)		orderFrontPrefsPanel: (id)sender;

// You don't have to care about these:
-(void)	mapTabsToToolbar;
-(IBAction)	changePanes: (id)sender;

-(IBAction)next:sender;
-(IBAction)prev:sender;


@end
