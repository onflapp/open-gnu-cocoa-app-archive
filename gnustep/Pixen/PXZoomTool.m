//  PXZoomTool.m
//  Pixen
//
//  Created by Joe Osborn on Mon Oct 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXZoomTool.h"
#import "PXCanvasController.h"
#import "PXToolSwitcher.h"

@implementation PXZoomTool

- (NSString *)name
{
	return NSLocalizedString(@"ZOOM_NAME", @"Zoom Tool");
}

- init
{
    [super init];
    zoomType = PXZoomIn;
    return self;
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
    if(zoomType == PXZoomIn)
    {
        [controller zoomInOnCanvasPoint:aPoint];
    }
    if(zoomType == PXZoomOut)
    {
        [controller zoomOutOnCanvasPoint:aPoint];
    }
}

- (BOOL)optionKeyUp
{
    zoomType = PXZoomIn;
    [switcher setIcon:[NSImage imageNamed:@"zoomIn"] forTool:self];
	return YES;
}

- (BOOL)optionKeyDown
{
    zoomType = PXZoomOut;
    [switcher setIcon:[NSImage imageNamed:@"zoomOut"] forTool:self];
	return YES;
}

@end
