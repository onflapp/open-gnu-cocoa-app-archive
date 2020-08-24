//
//  PXEllipseTool.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Mar 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXCanvasController.h"
#import "PXCanvas.h"
#import "PXEllipseTool.h"
#import "PXEllipseToolPropertiesView.h"


@implementation PXEllipseTool

- (NSString *)name
{
	return NSLocalizedString(@"ELLIPSE_NAME", @"Ellipse Tool");
}

- actionName
{
    return NSLocalizedString(@"ELLIPSE_ACTION", @"Drawing Ellipse");
}

- init
{
	[super init];
	propertiesView = [[PXEllipseToolPropertiesView alloc] init];
	return self;
}

- (void)mouseDownAt:(NSPoint)aPoint fromCanvasController:controller
{
    //origin = aPoint;
    [super mouseDownAt:aPoint fromCanvasController:controller];
}

- (void)drawPointsAddingToArray:(NSMutableArray *)points ifTracking:(BOOL)tracking withX:(int)x y:(int)y cx:(int)cx cy:(int)cy evenWidth:(BOOL)evenWidth evenHeight:(BOOL)evenHeight borderWidth:(int)borderWidth inCanvas:canvas goingHorizontally:(BOOL)horiz
{
    int cWidth;
    for (cWidth = 0; cWidth < borderWidth; cWidth++) {
		int dx = x;
		int dy = y;
		if (horiz) {
			dx -= cWidth;
		} else {
			dy -= cWidth;
		}
		int cxp;
		int cxn;
		int cyp;
		int cyn;
		cxp = cx-evenWidth;
		cxn = cx;
		cyp = cy-evenHeight;
		cyn = cy;
		NSPoint p1 = NSMakePoint(cxp+dx, cyp+dy);
		NSPoint p2 = NSMakePoint(cxp+dx, cyn-dy);
		NSPoint p3 = NSMakePoint(cxn-dx, cyp+dy);
		NSPoint p4 = NSMakePoint(cxn-dx, cyn-dy);
		if (tracking) {
			[points addObject:NSStringFromPoint(p1)];
			[points addObject:NSStringFromPoint(p2)];
			[points addObject:NSStringFromPoint(p3)];
			[points addObject:NSStringFromPoint(p4)];
		}
		[self drawPixelAtPoint:p1 inCanvas:canvas];
		[self drawPixelAtPoint:p2 inCanvas:canvas];
		[self drawPixelAtPoint:p3 inCanvas:canvas];
		[self drawPixelAtPoint:p4 inCanvas:canvas];
    }
}

- (NSArray *)plotEllipseInscribedInRect:(NSRect)bound withLineWidth:(int)borderWidth trackingPoints:(BOOL)tracking inCanvas:canvas
{
    NSMutableArray *points = [NSMutableArray array];
    int xRadius = bound.size.width/2, yRadius = bound.size.height/2;
    if (xRadius < 1) {
		xRadius = 1;
    }
    if (yRadius < 1) {
		yRadius = 1;
    }
    int cx = bound.origin.x + xRadius, cy = bound.origin.y + yRadius;
    int twoASquared = 2 * xRadius * xRadius;
    int twoBSquared = 2 * yRadius * yRadius;
    int x = xRadius;
    int y = 0;
    int xChange = yRadius * yRadius * (1 - 2*xRadius);
    int yChange = xRadius * xRadius;
    int error = 0;
    int stoppingX = twoBSquared * xRadius;
    int stoppingY = 0;
	BOOL evenWidth = ((float)xRadius == bound.size.width / 2.0f);
	BOOL evenHeight = ((float)yRadius == bound.size.height / 2.0f);
    while (stoppingX >= stoppingY) {
		[self drawPointsAddingToArray:points ifTracking:tracking withX:x y:y cx:cx cy:cy evenWidth:evenWidth evenHeight:evenHeight borderWidth:borderWidth inCanvas:canvas goingHorizontally:YES];
		y++;
		stoppingY += twoASquared;
		error += yChange;
		yChange += twoASquared;
		if ((2*error + xChange) > 0) {
			x--;
			stoppingX -= twoBSquared;
			error += xChange;
			xChange += twoBSquared;
		}
    }
    
    x = 0;
    y = yRadius;
    xChange = yRadius * yRadius;
    yChange = xRadius * xRadius * (1 - 2*yRadius);
    error = 0;
    stoppingX = 0;
    stoppingY = twoASquared * yRadius;
    
    while (stoppingX <= stoppingY) {
		[self drawPointsAddingToArray:points ifTracking:tracking withX:x y:y cx:cx cy:cy evenWidth:evenWidth evenHeight:evenHeight borderWidth:borderWidth inCanvas:canvas goingHorizontally:NO];
		x++;
		stoppingX += twoBSquared;
		error += xChange;
		xChange += twoBSquared;
		if ((2*error + yChange) > 0) {
			y--;
			stoppingY -= twoASquared;
			error += yChange;
			yChange += twoASquared;
		}
    }
    return points;
}

- (void)drawPixelAtPoint:(NSPoint)aPoint withColor:(NSColor *)specialColor inCanvas:aCanvas //should probably be put into PXPencilTool
{
    [self drawWithOldColor:[aCanvas
colorAtPoint:aPoint] newColor:specialColor atPoint:aPoint inLayer:[aCanvas activeLayer] ofCanvas:aCanvas];
}

- (void)plotFilledEllipseInscribedInRect:(NSRect)bound withLineWidth:(int)borderWidth withFillColor:(NSColor *)fillColor inCanvas:canvas
{
    NSArray *points = [self plotEllipseInscribedInRect:(NSRect)bound withLineWidth:borderWidth trackingPoints:YES inCanvas:canvas];
    NSEnumerator *pointEnumerator = [points objectEnumerator];
    id start, end;
    NSPoint startPoint, endPoint;
    NSColor *prevColor = [[[self color] retain] autorelease];
	[self setColor:fillColor];
	while ((start = [pointEnumerator nextObject]) && (end = [pointEnumerator nextObject])) {
		startPoint = NSPointFromString(start);
		endPoint = NSPointFromString(end);
		while ([points containsObject:NSStringFromPoint(startPoint)]) {
			startPoint.y--;
		}
		startPoint.y++;
		while ([points containsObject:NSStringFromPoint(endPoint)]) {
			endPoint.y++;
		}
		if (startPoint.y > endPoint.y) {
			[self drawLineFrom:startPoint to:endPoint inCanvas:canvas];
		}
	}
	[self setColor:prevColor];
}

- (void)plotUnfilledEllipseInscribedInRect:(NSRect)bound withLineWidth:(int)borderWidth inCanvas:canvas
{
    [self plotEllipseInscribedInRect:(NSRect)bound withLineWidth:borderWidth trackingPoints:NO inCanvas:canvas];
}

- (NSRect)getEllipseBoundFromdrawFromPoint:(NSPoint)origin toPoint:(NSPoint)aPoint
{
    NSPoint start = origin;
    NSPoint end = aPoint;
    if (aPoint.x < start.x)
    {
		start.x = aPoint.x + 1;
		end.x = origin.x + 1;
    }
    if (aPoint.y < start.y)
    {
		start.y = aPoint.y + 1;
		end.y = origin.y + 1;
    }
	return NSMakeRect(start.x, start.y, end.x - start.x, end.y - start.y);
}

- (void)finalDrawFromPoint:(NSPoint)origin toPoint:(NSPoint)aPoint inCanvas:canvas
{
    NSRect ellipseBound = [self getEllipseBoundFromdrawFromPoint:(NSPoint)origin toPoint:aPoint];
    if ([propertiesView shouldFill]) {
		[self plotFilledEllipseInscribedInRect:ellipseBound withLineWidth:[propertiesView borderWidth] withFillColor:([propertiesView shouldUseMainColorForFill]) ? [self color] : [propertiesView fillColor] inCanvas:canvas];
    } else {
		[self plotUnfilledEllipseInscribedInRect:ellipseBound withLineWidth:[propertiesView borderWidth] inCanvas:canvas];
    }
}
- (void)drawFromPoint:(NSPoint)origin toPoint:(NSPoint)finalPoint inCanvas:canvas
{
    NSRect ellipseBound = [self getEllipseBoundFromdrawFromPoint:(NSPoint)origin toPoint:finalPoint];
    [self plotUnfilledEllipseInscribedInRect:ellipseBound withLineWidth:[propertiesView borderWidth] inCanvas:canvas];
}
@end
