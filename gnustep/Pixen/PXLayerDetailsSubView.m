//
//  PXLayerDetailsSubView.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Thu Aug 05 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXLayerDetailsSubView.h"
#import "PXLayer.h"
#import "PXSelectionLayer.h"


@implementation PXLayerDetailsSubView

- (void)setLayer:aLayer
{
	layer = aLayer;
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"Layer"] autorelease];
	NSMenuItem *item;
	if ([layer isKindOfClass:[PXSelectionLayer class]]) {
		item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:@"Promote to Layer"];
		[item setAction:@selector(promote:)];
		[item setTarget:layer];
		[menu addItem:item];
	} else {
		item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:@"Delete"];
		[item setAction:@selector(delete:)];
		[item setTarget:layer];
		[menu addItem:item];
		item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:@"Duplicate"];
		[item setAction:@selector(duplicate:)];
		[item setTarget:layer];
		[menu addItem:item];
		item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:@"Merge Down"];
		[item setAction:@selector(mergeDown:)];
		[item setTarget:layer];
		[menu addItem:item];
	}
	
	[self setMenu:menu];
}

@end
