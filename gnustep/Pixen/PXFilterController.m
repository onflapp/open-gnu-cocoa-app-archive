//
//  PXFilterController.m
//  Pixen-XCode
//
//  Created by Ian Henderson on 20.09.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXFilterController.h"
#import "PXFilter.h"
#import "PXCanvas.h"

@implementation PXFilterController

- init
{
	[super init];
	filters = [[NSMutableDictionary alloc] init];
	filterBundles = [[NSMutableArray alloc] init];
	return self;
}

- (void)dealloc
{
	[filters release];
	[filterBundles release];
	[super dealloc];
}

- (void)loadFilterAtPath:(NSString *)filename
{
	BOOL isDirectory;
	if (![[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDirectory] || !isDirectory) {
		return;
	}
	
	NSBundle *filterBundle = [NSBundle bundleWithPath:filename];
	if (filterBundle == nil) {
		return;
	}
	
	NSString *className = [[[filename pathComponents] lastObject] stringByDeletingPathExtension];
	Class filterClass;
	if ((filterClass = [filterBundle classNamed:className]) == nil) {
#ifdef __COCOA__
		[NSAlert alertWithMessageText:@"Incomplete Filter" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The filter located at %@ does not have a class named \"%@\".  Please change the file name back to how it was originally, or make sure the filename and filter class name are the same.", filename, className];
#else
#warning GNUstep TODO
#endif
		return;
	}
	
	id filter = [[[filterClass alloc] init] autorelease];
	if (![filter respondsToSelector:@selector(name)]) {
#ifdef __COCOA__
		[NSAlert alertWithMessageText:@"Incomplete Filter" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The filter located at %@ does not know its name.  I can't load such a confused file.", filename];
#else
#warning GNUstep TODO
#endif
		return;
	}
	if (![filter respondsToSelector:@selector(applyToCanvas:)]) {
#ifdef __COCOA__
		[NSAlert alertWithMessageText:@"Incomplete Filter" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The filter located at %@ doesn't actually do anything.  Please implement -applyToCanvas:, or tell the author to.", filename];
#else
#warning GNUstep TODO
#endif
		return;
	}
	[filters setObject:filter forKey:[filter name]];
	[filterBundles addObject:filterBundle];
}

- (void)loadFiltersFromDirectory:(NSString *)dir
{
	BOOL isDirectory;
	if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDirectory] || !isDirectory) {
		return;
	}
	
	NSEnumerator *filenameEnumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:dir] objectEnumerator];
	NSString *filename;
	while (filename = [filenameEnumerator nextObject]) {
		[self loadFilterAtPath:[dir stringByAppendingPathComponent:filename]];
	}
}

- (void)updateFilterMenu
{
	NSEnumerator *titleEnumerator = [[filters allKeys] objectEnumerator];
	NSString *title;
	while ([filterMenu numberOfItems] > 0) {
		[filterMenu removeItemAtIndex:0];
	}
	while (title = [titleEnumerator nextObject]) {
		[[filterMenu addItemWithTitle:title action:@selector(doFilter:) keyEquivalent:@""] setTarget:self];
	}
}

- (void)awakeFromNib
{
	[self loadFiltersFromDirectory:[@"~/Library/Application Support/Pixen/Filters" stringByExpandingTildeInPath]];
	[self loadFiltersFromDirectory:[@"/Library/Application Support/Pixen/Filters" stringByExpandingTildeInPath]];
	if ([[filters allKeys] count] > 0) {
		[self updateFilterMenu];
	}
}

- (NSObject<PXFilter> *)filterNamed:(NSString *)name
{
	return [filters objectForKey:name];
}

- (IBAction)doFilter:sender
{
	PXCanvas *canvas = [[[NSDocumentController sharedDocumentController] currentDocument] canvas];
	[[self filterNamed:[sender title]] applyToCanvas:canvas];
	[canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
}

@end
