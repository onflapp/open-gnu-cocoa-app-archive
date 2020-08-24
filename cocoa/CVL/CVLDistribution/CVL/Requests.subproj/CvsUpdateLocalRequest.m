//
//  CvsUpdateLocalRequest.m
//  CVL
//
//  Created by William Swats on 10/27/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//

#import "CvsUpdateLocalRequest.h"


@implementation CvsUpdateLocalRequest


- (NSArray *)cvsCommandOptions
{
	NSArray *supersOptions = nil;
	NSMutableArray *options = nil;

	supersOptions = [super cvsCommandOptions];
	options = [NSMutableArray arrayWithArray:supersOptions];
	[options addObject:@"-l"]; // For local non-recursive update

	return options;
}


@end
