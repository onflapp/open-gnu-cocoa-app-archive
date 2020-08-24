//  PXEraserTool.m
//  Pixen
//
//  Created by Joe Osborn on Tue Oct 07 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXEraserTool.h"


@implementation PXEraserTool

- (NSString *)name
{
	return NSLocalizedString(@"ERASER_NAME", @"Eraser Tool");
}

- actionName
{
    return NSLocalizedString(@"ERASER_ACTION", @"Erasure");
}

- color
{
    return [NSColor clearColor];
}

@end
