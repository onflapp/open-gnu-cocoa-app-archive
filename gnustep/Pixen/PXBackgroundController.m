//
//  PXBackgroundController.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Oct 26 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXBackgroundController.h"
#import "PXSlashyBackground.h"
#import "PXMonotoneBackground.h"
#import "PXCheckeredBackground.h"
#import "PXImageBackground.h"
#import "PXBackground.h"
#import "PXNamePrompter.h"
#import "PXCanvas.h"

#ifdef __COCOA__
static NSString *BACKGROUNDPRESET = @"Application Support/Pixen/Backgrounds/Presets";
#else
static NSString *BACKGROUNDPRESET = @"Pixen/Backgrounds/Presets";
#endif

#define SAVEASPOPUPITEMTAG 1
#define DELETEPOPUPITEMTAG 2

static NSArray *defaultBackgrounds (void) 
{
	static NSArray *backgrounds = nil;
	if (! backgrounds )
    {
		backgrounds = [[NSArray alloc] initWithObjects:[[PXSlashyBackground alloc] init],
			[[PXMonotoneBackground alloc] init], 
			[[PXCheckeredBackground alloc] init], 
			[[PXImageBackground alloc] init] ,
			nil];
    }
	return backgrounds;
}



@interface PXBackgroundController ( Private) 
- (void) _populatePopup: (NSPopUpButton *) aPopup withDefaultBackgroundsUsingSelectionAction: (SEL)aSelector;
- (void) _populatePopup: (NSPopUpButton *) aPopup withUserBackgroundsUsingSelectionAction: (SEL)aSelector;
- (void) _populateMenu:  (NSPopUpButton *) aPopup selectionAction: (SEL)aSelector;
- (void) _populateMenus;
- (void) _setUsesAlternateBackground:(BOOL)newUsesAlternateBackground;
- (void)_setDefaultBackgroundsFor:(id) aCanvas;
- (void) _setMainBackground:(id) aBackground;
- (void) _setAlternateBackground:(id) aBackground;
@end


@implementation PXBackgroundController ( Private )

#define PXBackgroundControllerSetBackground(bg, menu, configView, newBg)\
{\
	[[bg configurator] removeFromSuperview];\
		[newBg retain];\
			[bg release];\
				bg = newBg;\
					[menu selectItemWithTitle:[bg name]];\
						[configView addSubview:[bg configurator]];\
}


//Defaults backgrounds create by hand
- (void) _populatePopup:(NSPopUpButton *) aPopup withDefaultBackgroundsUsingSelectionAction:(SEL)aSelector
{
	NSEnumerator  *enumerator =  [defaultBackgrounds() objectEnumerator];
	id current;
	
	while( ( current = [enumerator nextObject] ) )
    {
		
		id item = [[[NSMenuItem alloc] initWithTitle:[current name]
											  action: aSelector
									   keyEquivalent: @""]  autorelease];
#ifndef __COCOA__
		[item setTarget: self];
#endif
		
		[item setRepresentedObject:[[current copy] autorelease]];
		[[aPopup menu] addItem:item];
    }   
}

//Users backgrounds  saved by the user usally in ~/Library/Application Support/Pixen/Backgrounds/Presets ( OSX ) 
// and  $GNUSTEP_USER_HOME/Library/Pixen/Backgrounds/Presets for GNUstep
- (void) _populatePopup:(NSPopUpButton*) aPopup withUserBackgroundsUsingSelectionAction:(SEL)aSelector
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
	if ( [paths count] > 0) 
    {
		NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent: BACKGROUNDPRESET];
		//TODO check if exists ??? 
		id enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
		id current;
		
		while( ( current = [enumerator nextObject] ) )
		{
			if ( [[current pathExtension] isEqualToString:@"pxbgnd"] )
			{
				id item = [[[NSMenuItem alloc] initWithTitle:[current stringByDeletingPathExtension]
													  action: aSelector
											   keyEquivalent: @""]
					autorelease];
#ifndef __COCOA__
				[item setTarget :self];
#endif
				
				
				[item setRepresentedObject:[NSKeyedUnarchiver unarchiveObjectWithFile:
					[path stringByAppendingPathComponent:current]]];
				[[aPopup menu] addItem:item];
			}
		}
    }
}

- (void) _populateMenu: (NSPopUpButton *) aPopup selectionAction: (SEL)aSelector
{
	id selected = [[[aPopup titleOfSelectedItem] retain] autorelease];
	id menu = [aPopup menu];
	
	//remove all items 
	[aPopup removeAllItems];
	
	//add defaults backgrounds
	[self _populatePopup:aPopup withDefaultBackgroundsUsingSelectionAction:aSelector];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	//Add user backgrounds
	[self _populatePopup:aPopup withUserBackgroundsUsingSelectionAction:aSelector];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	//add "Save As" item
	id item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"BACKGROUNDS_SAVE_AS", @"Backgrounds Save As")
										  action:@selector(saveCurrentConfiguration:)
								   keyEquivalent:@""]
		autorelease];
#ifndef __COCOA__
	[item setTarget: self];
#endif
	
	
	[[aPopup menu] addItem:item];
	
	//Add "Delete item" 
	item = [[[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"BACKGROUNDS_DELETE", @"Backgrounds Delete")
									   action:@selector(deleteCurrentConfiguration:)
								keyEquivalent:@""]
		autorelease];
	
#ifndef __COCOA__
	[item setTarget: self];
#endif
	
	[[aPopup menu] addItem:item];
	
	
	//Display the first item if none is selected or id "Delete current configurator" item is selected
	//display the selected item if not 
	if( ( ! [[aPopup itemTitles] containsObject:selected] )
		|| ( [[aPopup selectedItem] tag] == DELETEPOPUPITEMTAG ) )
    {
		[aPopup selectItemAtIndex:0];
    }
	else 
    { 
		[aPopup selectItemWithTitle:selected];
    }
}


- (void) _populateMenus
{
	[self _populateMenu:mainMenu selectionAction:@selector(selectMainBackground:)];
	[self _populateMenu:alternateMenu selectionAction:@selector(selectAlternateBackground:)];
}


- (void) _setUsesAlternateBackground:(BOOL)newUsesAlternateBackground
{
	usesAlternateBackground = newUsesAlternateBackground;
	[alternateMenu setEnabled:usesAlternateBackground];
	[alternateBackground setConfiguratorEnabled:usesAlternateBackground];
	[delegate setAlternateBackground:(usesAlternateBackground ? alternateBackground : nil)];	
	[alternateCheckbox setState:usesAlternateBackground];
}

//Display the default Background 
//If there is no defaults select : slashed_background for the main background
// and flat_background for the alternate background
- (void)_setDefaultBackgroundsFor:(id) aCanvas
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id mainBackgroundName = [defaults objectForKey:@"mainBackgroundName"];
	id alternateBackgroundName = [defaults objectForKey:@"alternateBackgroundName"];
	
	if( ! mainBackgroundName ) 
    { 
		mainBackgroundName = NSLocalizedString(@"SLASHED_BACKGROUND", @"Slashed Background"); 
    }
	if(! alternateBackgroundName )
    { 
		alternateBackgroundName = NSLocalizedString(@"FLAT_BACKGROUND", @"Flat Background"); 
    }
	
	[aCanvas setMainBackgroundName:mainBackgroundName];
	[aCanvas setAlternateBackgroundName:alternateBackgroundName];
	[self _setMainBackground:[[self class] backgroundNamed:mainBackgroundName]];
	[self _setAlternateBackground:[[self class] backgroundNamed:alternateBackgroundName]];
	[self _setUsesAlternateBackground:[defaults boolForKey:@"usesAlternateBackground"]];	
}


//  #define PXBackgroundControllerSetBackground(bg, menu, configView, newBg)\
//  {\
//      [[bg configurator] removeFromSuperview];\
//      [newBg retain];\
//      [bg release];\
//      bg = newBg;\
//      [menu selectItemWithTitle:[bg name]];\
//      [configView addSubview:[bg configurator]];\
//  }


- (void) _setMainBackground:(id) aBackground
{
	PXBackgroundControllerSetBackground(mainBackground, mainMenu, mainConfigurator, aBackground);
	[delegate setMainBackground:mainBackground];
}


- (void) _setAlternateBackground:(id) aBackground
{
	PXBackgroundControllerSetBackground(alternateBackground, alternateMenu, alternateConfigurator, aBackground);
	[delegate setAlternateBackground:alternateBackground];
}

@end


/**********************************/
/* NamePrompterDelegate categories*/
/**********************************/

@implementation PXBackgroundController ( NamePrompterDelegate ) 

- (void)prompter:aPrompter didFinishWithName:name context:contextObject
{
	PXBackground * newConfig = [[contextObject copy] autorelease];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *path;
	if ( [paths count] == 0 ) 
    {
		NSLog(@"WARNING Use Library directory does not exists. Should never happens !!! WARM the user !!!");
		return;
    }
	path = [paths objectAtIndex:0];
	
	id menu = nil;
	
	if(contextObject == mainBackground)
    {
		menu = mainMenu;
    }
	else if( contextObject == alternateBackground)
    {
		menu = alternateMenu;
    }
	
	[newConfig setName:name];
#warning Put it in PXAppDelegate
	
	path = [[paths objectAtIndex:0] stringByAppendingPathComponent:BACKGROUNDPRESET];
	path = [path stringByAppendingPathComponent:name];
	path = [path  stringByAppendingPathExtension:@"pxbgnd"];
	NSLog(@"save FINISH path %@",path);
	
	[NSKeyedArchiver archiveRootObject:newConfig toFile:path];
	
	[self _populateMenus];
	
	[menu selectItemWithTitle:name];
	[self performSelector:[[menu itemWithTitle:name] action] withObject:[menu itemWithTitle:name]];
}


- (void)prompter:aPrompter didCancelWithContext:contextObject
{
	id config = contextObject;
	id menu = nil;
	
	if(config == mainBackground)
		menu = mainMenu;
	else if (config == alternateBackground)
		menu = alternateMenu;
	
	[menu selectItemWithTitle:[config name]];
}

@end





/*******************************************/
/*  PXBackgroundController implementation **/
/*******************************************/

@implementation PXBackgroundController

+ backgroundNamed:aName
{
	id enumerator = [defaultBackgrounds() objectEnumerator];
	id current;
	NSString *path;
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
	
	while( ( current = [enumerator nextObject] ) )
	{
		if([[current name] isEqualToString:aName])
		{
			return [[current copy] autorelease];
		}
	}
	
	if ( [paths count] > 0 ) 
	{
		path = [paths objectAtIndex:0];
		path = [path stringByAppendingPathComponent:BACKGROUNDPRESET];
	}
	
	
	enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
	
	while(current = [enumerator nextObject])
	{
		// .DS_Store not exists into GNUstep -- ok, so it'll do nothing!  why was this a #warning?
		if( ( ![current isEqualToString:@".DS_Store"] )
			&& ( [[current stringByDeletingPathExtension] isEqualToString:aName] ) ) 
		{
			return [NSKeyedUnarchiver unarchiveObjectWithFile:[path stringByAppendingPathComponent:current]];
		}
	}
	
	return [[[defaultBackgrounds() objectAtIndex:0] copy] autorelease];
}


-(id)  init
{
	if ( ! (self = [super init] ) )
		return nil;
	
	if ( ! [NSBundle loadNibNamed:@"PXBackgroundController" owner: self] ) 
    {
		NSLog(@"Warm user here");
    }
	
	return self;
}



- (void)dealloc
{
	if ( mainBackground ) 
		[mainBackground release];
	if ( alternateBackground ) 
		[alternateBackground release];
	//probably  mem leaks here
	[super dealloc];
}


- (void)awakeFromNib
{
	usesAlternateBackground = YES;
	namePrompter = [[PXNamePrompter alloc] init];
	[namePrompter setDelegate:self];
	
	[self _populateMenus];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(backgroundChanged:) 
												 name:@"PXBackgroundChanged" 
											   object:nil];
}


- (void)setDelegate:aDelegate
{
	delegate = aDelegate;
}



//
//Actions methods
//

//Call from PopUp item saveCurrentConfiguration
- (IBAction)saveCurrentConfiguration: (id) sender
{
	id context = nil;
	id menu = nil;
	if( [[mainMenu titleOfSelectedItem] isEqualToString:
		NSLocalizedString(@"BACKGROUNDS_SAVE_AS", @"Backgrounds Save As")])
    {
		context = mainBackground;
		menu = mainMenu;
    }
	else if( [[alternateMenu titleOfSelectedItem] isEqualToString:
						  NSLocalizedString(@"BACKGROUNDS_SAVE_AS", @"Backgrounds Save As")])
    {
		context = alternateBackground;   
		menu = alternateMenu;
    }
	
	[namePrompter promptInWindow:panel context:context];
}


//Call from PopUp item deleteCurrentConfiguration
- (IBAction)deleteCurrentConfiguration:(id) sender
{
	NSLog(@"deleteCurrentConfiguration");
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *path;
	id config = nil;
	id menu = nil;
	if([[mainMenu titleOfSelectedItem] isEqualToString:NSLocalizedString(@"BACKGROUNDS_DELETE", @"Backgrounds Delete")])
    {
		menu = mainMenu;
		config = mainBackground;
		[self _setMainBackground:[defaultBackgrounds() objectAtIndex:0]];
    }
	else if([[alternateMenu titleOfSelectedItem] isEqualToString:NSLocalizedString(@"BACKGROUNDS_DELETE", @"Backgrounds Delete")])
    {
		config = alternateBackground;
		menu = alternateMenu;
		[self _setAlternateBackground:[ defaultBackgrounds() objectAtIndex:1]];
    }
	
	if(![config isKindOfClass:[PXBackground class]]) 
    { 
		[menu selectItemAtIndex:0]; 
		return; 
    }
	
	if ( [paths count] == 0 ) 
    {
		NSLog(@"WARNING Use Library directory does not exists. Should never happens !!! WARM the user !!!");
    }
	
	
	path = [[paths objectAtIndex:0] stringByAppendingPathComponent:BACKGROUNDPRESET];
	path = [path stringByAppendingPathComponent:[config name]];
	path = [path  stringByAppendingPathExtension:@"pxbgnd"];
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]) 
    { 
#ifdef __COCOA__    
		NSBeep(); 
#endif
		[menu selectItemAtIndex:0]; return; 
    }
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	[self _populateMenus];
}


// checkBox  IBAction
- (IBAction)useAlternateBackgroundCheckboxClicked:(id) sender
{
	[self _setUsesAlternateBackground:([sender state] == NSOnState)];
}


- (IBAction)selectMainBackground: (id) sender
{
	
	[self _setMainBackground:[sender representedObject]];
#ifndef __COCOA__
	// [mainMenu selectItemAtIndex: 2];
#endif
}

- (IBAction)selectAlternateBackground: (id)sender
{
	[self _setAlternateBackground:[sender representedObject]];
}


//sender == NSButton "use these as defaults "
- (IBAction)useCurrentBackgroundsAsDefaults:(id) sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setObject:[mainBackground name] forKey:@"mainBackgroundName"];
	[defaults setObject:[alternateBackground name] forKey:@"alternateBackgroundName"];
	[defaults setBool:usesAlternateBackground forKey:@"usesAlternateBackground"];
	
	[defaults synchronize];
}


//Is it really need ? 
- (void)windowDidLoad
{
#warning is it really need 
	
	if ( mainBackground ) 
		[mainConfigurator addSubview:[mainBackground configurator]];
	
	if ( alternateBackground ) 
		[alternateConfigurator addSubview:[alternateBackground configurator]];
	
}

- (void)backgroundChanged:notification
{
    [delegate backgroundChanged:notification];
}


- (void)useBackgroundsOf:(id) aCanvas
{
	//???
	//   [self window];
	
	if( ! [aCanvas mainBackgroundName] ) 
    { 
		[self _setDefaultBackgroundsFor:aCanvas];
		return;
    }
	NSString * mainName = [[aCanvas mainBackgroundName] retain], * altName = [[aCanvas alternateBackgroundName] retain];
	[self _setMainBackground:[[self class] backgroundNamed:mainName]];
	if((altName == nil) || [altName isEqualToString:mainName])
    {
		[self _setAlternateBackground:nil];
		[self _setUsesAlternateBackground:NO];
    }
	else
    {
		[self _setAlternateBackground:[[self class] backgroundNamed:altName]];
		[self _setUsesAlternateBackground:YES];
    }
	[mainName release];
	[altName release];
}

//Accessor
-(NSPanel *) backgroundPanel
{
	return panel;
}

@end

