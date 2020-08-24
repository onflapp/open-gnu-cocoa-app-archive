//
//  PXUserWarmer.m
//  Pixen-XCode
//
//  Created by Ian Henderson on 09.12.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXUserWarmer.h"


@implementation PXUserWarmer

+ (void)warmTheUser:(NSString *)string
{
#ifdef __COCOA__
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"KABOOM"];
	[alert setInformativeText:string];
	[alert addButtonWithTitle:@"NOT OK"];
	[alert runModal];
	[alert release];
#else
	NSLog(string);
#endif
}

@end
