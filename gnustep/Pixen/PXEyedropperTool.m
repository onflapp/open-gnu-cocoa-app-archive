//  PXEyedropperTool.m
//  Pixen
//
//  Created by Joe Osborn on Mon Oct 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXEyedropperTool.h"
#import "PXCanvas.h"
#import "PXCanvasController.h"

@implementation PXEyedropperTool

- (NSString *)name
{
	return NSLocalizedString(@"EYEDROPPER_NAME", @"Eyedropper Tool");
}

- compositeColorAtPoint:(NSPoint)aPoint fromCanvas:canvas
{
	if (![canvas containsPoint:aPoint]) { return nil; }
	id image = [[NSImage alloc] initWithSize:[canvas size]];
	[image lockFocus];
	[canvas drawRect:NSMakeRect([canvas correct:aPoint].x, [canvas correct:aPoint].y, 1, 1) fixBug:YES];	
	id color = NSReadPixel([canvas correct:aPoint]);
	[image unlockFocus];
	[image release];
	return color;
}

- (void)eyedropAtPoint:(NSPoint)aPoint fromCanvasController:controller
{
	[switcher setColor:[self compositeColorAtPoint:aPoint fromCanvas:[controller canvas]]];
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
    [self eyedropAtPoint:aPoint fromCanvasController:controller];
}

- (void)mouseDraggedFrom:(NSPoint)initialPoint to:(NSPoint)finalPoint fromCanvasController:controller
{
    [self eyedropAtPoint:finalPoint fromCanvasController:controller];
}

- (void)mouseUpAt:(NSPoint)aPoint fromCanvasController:controller
{
    [self eyedropAtPoint:aPoint fromCanvasController:controller];   
}


@end
