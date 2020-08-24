//
//  PXAppDelegate.m
//  Pixen-XCode
//
// Copyright (c) 2003,2004 Open Sword Group

// Permission is hereby granted, free of charge, to any person obtaining a copy 
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights 
// to use,copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to 
// do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies
// or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
// BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM,  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//  Author : Andy Matuschak 
//  Created  on Tue Dec 09 2003.




//This class is the application delegate.
//it respond as delegate for  applicationShouldOpenUntitledFile: applicationDidFinishLaunching: applicationWillTerminate: 
//methods (see NSApplication documentation)
// it also responds to message from menu (only menu ??) 
// TODO : finish that 

#import "PXAppDelegate.h"

#import "PXAboutController.h"
#import "PXWelcomeController.h"
#import "PXPreferencesController.h"
#import "PXUserWarmer.h"

#import <Foundation/NSFileManager.h>
#import <AppKit/NSAlert.h>

extern BOOL isTiling;

/***********************************/
/******** Private method ***********/
/***********************************/

@interface PXAppDelegate (Private)
//Call from applicationDidFinishLaunching:
- (void) _checkForUncleanCrash;
- (void) _createApplicationSupportSubdirectories;
@end

@implementation PXAppDelegate (Private)

- (void) _checkForUncleanCrash
{
	NSArray *dirtyFiles = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"PXDirtyFiles"] copy] autorelease];
	
	if ( (! dirtyFiles )  || [dirtyFiles count] < 1) 
		return;
	else
    {
		[[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:@"PXDirtyFiles"];
		NSEnumerator *dirtyFileEnumerator = [dirtyFiles objectEnumerator];
		NSString *dirtyFile;
		
		while ( ( dirtyFile = [dirtyFileEnumerator nextObject] ) ) {
			if ([[NSFileManager defaultManager] fileExistsAtPath:dirtyFile]) {
				id document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:dirtyFile 
																									  display:YES];
				[document setFileName:nil];
				[[NSFileManager defaultManager] removeFileAtPath:dirtyFile handler:nil];
			}
		}
		
		[[NSAlert alertWithMessageText:NSLocalizedString(@"CRASH_RECOVERY", @"Crash Recover")
						 defaultButton:@"OK"
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(@"CRASH_TEXT", @"Crash Text")] runModal];
    }
}

//TODO Create Subdirectories for colors too

- (void) _createApplicationSupportSubdirectory:(NSString *)sub inDirectory:(NSString *)root
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir;
	NSString *path = [root stringByAppendingPathComponent:sub];
	if  ( ! [fileManager fileExistsAtPath:path isDirectory:&isDir] )
    {
		if ( ! [fileManager createDirectoryAtPath:path attributes:nil] ) 
		{
			[PXUserWarmer warmTheUser:@"I couldn't create a directory in your library or application support directory!  That's kind of... not good.  Please adjust permissions or something."]; // localize?
			return;
		}
    }
	else
    {
		if ( ! isDir ) 
		{
			[PXUserWarmer warmTheUser:[NSString stringWithFormat:@"Um, there's a file named %@ in %@... were you trying to make me crash, or what?", sub, root]]; // localize?
			return;
		}
    }	
}

- (void) _createApplicationSupportSubdirectories
{
	//Check the Library user path
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir;
	NSString *path; 
	
	if (  [paths count] == 0 ) 
    {
		[PXUserWarmer warmTheUser:@"The Library directory does not exist.  This is highly irregular.  Get thee to your nearest Apple retailer and demand a refund!"]; // localize?
		return;
    }
	path = [paths objectAtIndex:0];
	//Application Support
#ifdef __COCOA__
	path = [path stringByAppendingPathComponent: @"Application Support"];
	
	if ( ( ! [fileManager fileExistsAtPath:path isDirectory:&isDir] )
		 || ( ! isDir ) )
    {
		[PXUserWarmer warmTheUser:@"There's no Application Support directory!  That blows and sucks, at the same time!"]; // localize?
		return;
    }
#endif
	[self _createApplicationSupportSubdirectory:@"Pixen" inDirectory:path];                            // ./Pixen
	path = [path stringByAppendingPathComponent:@"Pixen"];
	[self _createApplicationSupportSubdirectory:@"Backgrounds" inDirectory:path];                      // ./Pixen/Backgrounds
	[self _createApplicationSupportSubdirectory:@"Presets"
									inDirectory:[path stringByAppendingPathComponent:@"Backgrounds"]]; // ./Pixen/Backgrounds/Presets
	[self _createApplicationSupportSubdirectory:@"Palettes" inDirectory:path];                         // ./Pixen/Palettes
	[self _createApplicationSupportSubdirectory:@"Presets"
									inDirectory:[path stringByAppendingPathComponent:@"Palettes"]];    // ./Pixen/Palettes/Presets
}
@end


@implementation PXAppDelegate

//
// Delegate methods
//
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	//Create some directories needs to store backgrounds and Colors 
	[self _createApplicationSupportSubdirectories];
	
	
	//init all palettes
	toolPaletteController = [PXToolPaletteController sharedToolPaletteController];
	colorPaletteController = [PXColorPaletteController sharedPaletteController];
	leftToolPropertiesController = [PXToolPropertiesController leftToolPropertiesController];
	rightToolPropertiesController = [PXToolPropertiesController rightToolPropertiesController];
	infoPanelController = [PXInfoPanelController sharedInfoPanelController];
	
	// Open some panels if the user have let them open the last time
	if ( [defaults boolForKey:@"PXLeftToolPropertiesIsOpen"] ) {
		[[leftToolPropertiesController propertiesPanel] makeKeyAndOrderFront:self];
	}
	if ( [defaults boolForKey:@"PXRightToolPropertiesIsOpen"] ) {
		[[rightToolPropertiesController propertiesPanel] makeKeyAndOrderFront:self];
	}
	
	if ( [defaults boolForKey:@"PXInfoPanelIsOpen"] )
		[[infoPanelController infoPanel] makeKeyAndOrderFront:self];
	
	if (  [defaults boolForKey:@"PXColorPaletteIsOpen"] )
		[[colorPaletteController palettePanel] makeKeyAndOrderFront:self];
	
	//Always display toolPanel
	[[toolPaletteController toolPanel] display];
	// Please keep this line AFTER the tool properties' creation, so everything will update properly.
	
	[self  _checkForUncleanCrash];
	
	//If it is the first time Pixen run launch the welcome Panel
	//TODO (could be cleaner) : Fabien
	if (! [defaults boolForKey:@"PXHasRunBefore"] )
    {
		id welcome = [[PXWelcomeController alloc] init];
		
		isTiling = NO;
		[defaults setBool:NO forKey:@"PXShouldTile"];
		[defaults setBool:YES forKey:@"UKUpdateCheckerCheckAtStartup"];
		[defaults setInteger:120 forKey:@"PXAutosaveInterval"];
		[defaults setBool:YES forKey:@"PXInfoPanelIsOpen"];
		[defaults setBool:YES forKey:@"PXHasRunBefore"];
		[welcome showWindow:self];
    }
	
	
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if ( [[leftToolPropertiesController propertiesPanel] isVisible] )
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PXLeftToolPropertiesIsOpen"];
	else
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PXLeftToolPropertiesIsOpen"];
	
	if ( [[rightToolPropertiesController propertiesPanel] isVisible] )
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PXRightToolPropertiesIsOpen"];
	else
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PXRightToolPropertiesIsOpen"];
	
	if ( [[infoPanelController infoPanel] isVisible] )
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PXInfoPanelIsOpen"];
	else 
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PXInfoPanelIsOpen"];
	
	if ( [[colorPaletteController palettePanel] isVisible] )
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PXColorPaletteIsOpen"];
	else
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PXColorPaletteIsOpen"];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
}


//
// Actions methods
//
- (void)showAboutPanel:(id) sender
{
	[[PXAboutController sharedAboutController] showPanel:self];
}

- (IBAction)donate:(id) sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.opensword.org/donate.php"]];
}

- (IBAction)showLeftToolProperties:(id) sender;
{
	[[leftToolPropertiesController  propertiesPanel] makeKeyAndOrderFront:self];
}

- (IBAction)showRightToolProperties:(id) sender;
{
	[[rightToolPropertiesController  propertiesPanel] makeKeyAndOrderFront:self];
}

- (IBAction)showColorPalette:(id) sender
{
	[[colorPaletteController palettePanel] makeKeyAndOrderFront:self];
}

- (IBAction)showPreferences:(id) sender
{
	[[PXPreferencesController sharedPreferencesController] showWindow:self];
}

- (IBAction)showInfoPanel:(id) sender
{
	[[[PXInfoPanelController sharedInfoPanelController] infoPanel] makeKeyAndOrderFront:self];
}

//BUG : Could be call twice ! Should be a singleton (Fabien)
- (IBAction)discoverPixen:(id) sender
{
	id welcome = [[PXWelcomeController alloc] init];
	[welcome showWindow:self];
}

@end

