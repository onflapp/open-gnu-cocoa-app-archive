//
//  PXLineTool.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Dec 10 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXLineTool.h"
#import "PXCanvas.h"

@implementation PXLineTool

- (NSString *)name
{
	return NSLocalizedString(@"LINE_NAME", @"Line Tool");
}

- actionName
{
    return NSLocalizedString(@"LINE_ACTION", @"Drawing Line");
}

// Line tool doesn't need center locking, just gets in the way...

- (BOOL)optionKeyDown
{
	return NO;
}

- (BOOL)optionKeyUp
{
	return NO;
}

- (BOOL)supportsAdditionalLocking
{
    return YES;
}

- (void)drawFromPoint:(NSPoint)origin toPoint:(NSPoint)finalPoint inCanvas:canvas
{
    [self drawPixelAtPoint:origin inCanvas:canvas];
    [self drawLineFrom:origin to:finalPoint inCanvas:canvas];
}

@end
