//
//  PXCanvasResizeView.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Jun 09 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXCanvasResizeView.h"
#import <math.h>

@implementation PXCanvasResizeView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		cachedImage = [[NSImage imageNamed:@"greybox"] retain];
		scaleTransform = [[NSAffineTransform alloc] init];
		backgroundColor = [[NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:0] retain];
    }
    return self;
}

- (void)dealloc
{
	[guideDisappearTimer invalidate];
	[guideDisappearTimer release];
	[backgroundColor release];
	[scaleTransform release];
	[cachedImage release];
	[super dealloc];
}


- (NSRect)applyTransformation:(NSAffineTransform *)transform toRect:(NSRect)rect
{
	NSRect newRect;
	newRect.size = [transform transformSize:rect.size];
	newRect.origin = [transform transformPoint:rect.origin];
	return newRect;
}


- (void)drawLineAndNumberLengthFromPoint:(NSPoint)from toPoint:(NSPoint)to scale:(float)scale inSize:(NSSize)frameSize;
{
	float temp;
	if (from.x > to.x) {
		temp = from.x;
		from.x = to.x;
		to.x = temp;
	}
	if (from.y > to.y) {
		temp = from.y;
		from.y = to.y;
		to.y = temp;
	}
	float distance = sqrt(pow(from.x - to.x, 2) + pow(from.y - to.y, 2)) / scale;
	[[NSColor grayColor] set];
	[NSBezierPath strokeLineFromPoint:from toPoint:to];
	
	NSAttributedString *distanceString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d", (int)distance] attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSColor blackColor], NSForegroundColorAttributeName,
		[NSFont fontWithName:@"Helvetica" size:10], NSFontAttributeName,
		nil]] autorelease];
	NSRect stringRect = NSZeroRect;
	stringRect.size = [distanceString size];
	stringRect.origin = NSMakePoint((from.x + to.x - stringRect.size.width)/2, (from.y + to.y - stringRect.size.height)/2); // center the string on the center of the line
	if (from.x < to.x + .1 && from.x > to.x - .1) {
		[NSBezierPath strokeLineFromPoint:from toPoint:NSMakePoint(from.x + 3, from.y + 3)];
		[NSBezierPath strokeLineFromPoint:from toPoint:NSMakePoint(from.x - 3, from.y + 3)];
		[NSBezierPath strokeLineFromPoint:to toPoint:NSMakePoint(to.x + 3, to.y - 3)];
		[NSBezierPath strokeLineFromPoint:to toPoint:NSMakePoint(to.x - 3, to.y - 3)];
		stringRect.origin.x += stringRect.size.width / 2.0;
	} else {
		[NSBezierPath strokeLineFromPoint:from toPoint:NSMakePoint(from.x + 3, from.y + 3)];
		[NSBezierPath strokeLineFromPoint:from toPoint:NSMakePoint(from.x + 3, from.y - 3)];
		[NSBezierPath strokeLineFromPoint:to toPoint:NSMakePoint(to.x - 3, to.y + 3)];
		[NSBezierPath strokeLineFromPoint:to toPoint:NSMakePoint(to.x - 3, to.y - 3)];
		stringRect.origin.y += stringRect.size.height / 2.0;
	}
	
	if (stringRect.origin.x < 0) { // make sure the string is going to be visible
		stringRect.origin.x = 0;
	}
	if (stringRect.origin.y < 0) {
		stringRect.origin.y = 0;
	}
	if (stringRect.origin.x + stringRect.size.width > frameSize.width) {
		stringRect.origin.x = frameSize.width - stringRect.size.width;
	}
	if (stringRect.origin.y + stringRect.size.height > frameSize.height) {
		stringRect.origin.y = frameSize.height - stringRect.size.height;
	}
	
	//float radius = sqrt(pow(stringRect.size.width, 2) + pow(stringRect.size.height, 2)) / 2.0; // find the radius of the circle using a^2 + b^2 = c^2
	
	//NSBezierPath *path = [NSBezierPath bezierPath];
	//[path appendBezierPathWithArcWithCenter:NSMakePoint(stringRect.origin.x + stringRect.size.width/2.0, stringRect.origin.y + stringRect.size.height/2.0) radius:radius startAngle:0 endAngle:360]; // make the circle
	
	NSRect stringBackgroundRect = stringRect;
	stringRect.origin.x += 2;
	stringBackgroundRect.size.width += 4;
	[[NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:.9] set];
	NSRectFillUsingOperation(stringBackgroundRect, NSCompositeSourceAtop);
	//[path fill]; // fill the circle
	[distanceString drawAtPoint:stringRect.origin];
}

- (void)drawRect:(NSRect)rect
{
	NSRect newRect = NSMakeRect(0, 0, newSize.width, newSize.height); // Find the new size of the canvas
	NSRect oldRect = NSMakeRect(position.x, position.y, oldSize.width, oldSize.height); // Find the old size of the canvas
	NSSize maxSize = NSMakeSize(MAX(newSize.width, oldSize.width), MAX(newSize.height, oldSize.height)); // Find the size we need to display in the view
	NSSize frameSize = [self frame].size;
	
	float scale = 1.0f / MAX(maxSize.height / frameSize.height, maxSize.width / frameSize.width); // Find the scaling factor by looking at the rect that contains both the new size and old size, then scaling it to fit our frame
	
	oldRect.origin.x = round(oldRect.origin.x);
	oldRect.origin.y = round(oldRect.origin.y);
	
	[scaleTransform release];
	scaleTransform = [[NSAffineTransform transform] retain]; // transform the image-pixel scale to screen-pixel scale
	[scaleTransform scaleBy:scale];
	
	newRect = [self applyTransformation:scaleTransform toRect:newRect]; // transform our rects
	oldRect = [self applyTransformation:scaleTransform toRect:oldRect];
	
	NSAffineTransform *translateTransform = [NSAffineTransform transform];
	[translateTransform translateXBy:(frameSize.width - newRect.size.width) / 2 yBy:(frameSize.height - newRect.size.height) / 2]; // center the view on the new frame
	
	newRect = [self applyTransformation:translateTransform toRect:newRect]; // transform the rects again
	oldRect = [self applyTransformation:translateTransform toRect:oldRect];
	
	[[backgroundColor colorWithAlphaComponent:1] set];
	NSRectFill(newRect); // draw background for new frame
	
	[cachedImage drawInRect:oldRect fromRect:NSMakeRect(0, 0, [cachedImage size].width, [cachedImage size].height) operation:NSCompositeSourceAtop fraction:1.0f]; // draw the image in the old frame
	[[NSColor blackColor] set];
	[NSBezierPath strokeRect:oldRect]; // draw an outline around the image
	
	NSBezierPath *canvasOutline = [NSBezierPath bezierPathWithRect:newRect];
	float dashed[2] = {3, 3};
	[canvasOutline setLineDash:dashed count:2 phase:0];
	[canvasOutline stroke]; // draw an outline around the canvas
	[canvasOutline setLineDash:dashed count:2 phase:3];
	[[NSColor whiteColor] set];
	[canvasOutline stroke]; // dash white and black
	
	if (drawingArrows) { // if we're dragging the image
		
		float horizontalOffset = (oldRect.size.width / 2) + oldRect.origin.x;
		float verticalOffset = (oldRect.size.height / 2) + oldRect.origin.y;
		BOOL drawLines = YES;
		
		// a whole bunch of checks to position the lines correctly follow...
		
		if (horizontalOffset > newRect.size.width + newRect.origin.x) {
			if (newRect.size.width + newRect.origin.x < oldRect.origin.x) {
				drawLines = NO; // we don't care about it, it's off the new image entirely
			} else {
				horizontalOffset = newRect.size.width + newRect.origin.x; // move line so it doesn't go off the edge
			}
		}
		
		if (horizontalOffset < newRect.origin.x) { // pretty much the same as above
			if (newRect.origin.x > oldRect.size.width + oldRect.origin.x) {
				drawLines = NO;
			} else {
				horizontalOffset = newRect.origin.x;
			}
		}
		
		if (verticalOffset > newRect.size.height + newRect.origin.y) {
			if (newRect.size.height + newRect.origin.y < oldRect.origin.y) {
				drawLines = NO;
			} else {
				verticalOffset = newRect.size.height + newRect.origin.y; // move line so it doesn't go off the edge
			}
		}
		
		if (verticalOffset < newRect.origin.y) { // pretty much the same as above
			if (newRect.origin.y > oldRect.size.height + oldRect.origin.y) {
				drawLines = NO;
			} else {
				verticalOffset = newRect.origin.y;
			}
		}
		
		if (drawLines) {
			// up
			[self drawLineAndNumberLengthFromPoint:NSMakePoint(horizontalOffset, oldRect.size.height + oldRect.origin.y)
										   toPoint:NSMakePoint(horizontalOffset, newRect.size.height + newRect.origin.y)
											 scale:scale
											inSize:frameSize];
			
			// down
			[self drawLineAndNumberLengthFromPoint:NSMakePoint(horizontalOffset, oldRect.origin.y)
										   toPoint:NSMakePoint(horizontalOffset, newRect.origin.y)
											 scale:scale
											inSize:frameSize];
		
			// right
			[self drawLineAndNumberLengthFromPoint:NSMakePoint(oldRect.size.width + oldRect.origin.x, verticalOffset)
										   toPoint:NSMakePoint(newRect.size.width + newRect.origin.x, verticalOffset)
											 scale:scale
											inSize:frameSize];
			
			// left
			[self drawLineAndNumberLengthFromPoint:NSMakePoint(oldRect.origin.x, verticalOffset)
										   toPoint:NSMakePoint(newRect.origin.x, verticalOffset)
											 scale:scale
											inSize:frameSize];
		}
	}
}

- (NSSize)newSize
{
	return newSize;
}

- (NSPoint)position
{
	NSPoint roundedPosition = position;
	roundedPosition.x = round(roundedPosition.x);
	roundedPosition.y = round(roundedPosition.y);
	return roundedPosition;
}

- (void)setNewImageSize:(NSSize)size
{
	newSize = size;
	[self setNeedsDisplay:YES];
}

- (void)setOldImageSize:(NSSize)size
{
	oldSize = size;
	position = NSMakePoint(0,0);
	[self setNeedsDisplay:YES];
}

- (void)setCachedImage:(NSImage *)image
{
	[cachedImage release];
	cachedImage = [[NSImage alloc] initWithSize:[image size]];
	
	[cachedImage lockFocus];
	[[NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1] set];
	NSRectFill(NSMakeRect(0,0,[image size].width,[image size].height));
	[image compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeSourceAtop];
	[cachedImage unlockFocus];
	
	[self setNeedsDisplay:YES];
}


- (void)setBackgroundColor:(NSColor *)color
{
	[color retain];
	[backgroundColor release];
	backgroundColor = color;
	[self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event
{
	drawingArrows = YES;
}

- (void)mouseUp:(NSEvent *)event
{
	drawingArrows = NO;
	[self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event
{
	NSAffineTransform *muffineTransform = [scaleTransform copy];
	[muffineTransform invert];
	NSPoint deltaVector = [muffineTransform transformPoint:NSMakePoint([event deltaX], [event deltaY])];
	
	position.x += deltaVector.x;
	position.y -= deltaVector.y;
	[self setNeedsDisplay:YES];
}

- (void)hideArrows:(NSTimer *)timer;
{
	drawingArrows = NO;
	[self setNeedsDisplay:YES];
	[guideDisappearTimer release];
	guideDisappearTimer = nil;
}

- (void)keyDown:(NSEvent *)event
{
	NSString *characters = [event charactersIgnoringModifiers];
	NSPoint deltaVector = NSMakePoint(0, 0);
	if ([characters characterAtIndex:0] == NSUpArrowFunctionKey) {
		deltaVector.y = 1;
	} else if ([characters characterAtIndex:0] == NSDownArrowFunctionKey) {
		deltaVector.y = -1;
	} else if ([characters characterAtIndex:0] == NSRightArrowFunctionKey) {
		deltaVector.x = 1;
	} else if ([characters characterAtIndex:0] == NSLeftArrowFunctionKey) {
		deltaVector.x = -1;
	} else {
		[super keyDown:event];
		return;
	}
	
	if ([event modifierFlags] & NSShiftKeyMask) {
		deltaVector.x *= 10;
		deltaVector.y *= 10;
	}
	
	position.x += deltaVector.x;
	position.y += deltaVector.y;
	
	drawingArrows = YES;
	[guideDisappearTimer invalidate];
	[guideDisappearTimer release];
	guideDisappearTimer = [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(hideArrows:) userInfo:nil repeats:NO] retain];
	[self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

@end
