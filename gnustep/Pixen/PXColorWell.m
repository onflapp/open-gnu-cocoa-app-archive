#import "PXColorWell.h"

@implementation PXColorWell

- initWithFrame:(NSRect)frameRect
{
	[super initWithFrame:frameRect];
	[self setColor:[NSColor clearColor]];
	return self;
}

- (void)leftSelect
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PXColorWellLeftSelected" object:self userInfo:nil];
	[self setNeedsDisplay:YES];
}

- (void)rightSelect
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PXColorWellRightSelected" object:self userInfo:nil];
	[self setNeedsDisplay:YES];
}

- (void)mouseDown:event
{
	if ([event clickCount] == 2) {
		[self activate:YES];
		return;
	}
	if([event modifierFlags] & NSControlKeyMask)
	{
		[self rightSelect];
	}
	else
	{
		[self leftSelect];
	}
	[super mouseDown:event];
}

- (void)rightMouseDown:event
{
	if ([event clickCount] == 2) {
		[self activate:YES];
		return;
	}
	[self rightSelect];
}

- (void)deactivate
{
	[super deactivate];
	[self setNeedsDisplay:YES];
}

- (void)_setColorNoVerify:aColor
{
	id newColor = (aColor != nil ? aColor : [NSColor clearColor]);
	[super setColor:newColor];
}

- (void)drawRect:(NSRect)rect
{
	NSImage *background = [NSImage imageNamed:@"colorWellBackground"];
	[background drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [background size].width, [background size].height) operation:NSCompositeCopy fraction:1];
	
	[[self color] set];
	NSRectFillUsingOperation(rect, NSCompositeSourceAtop);
}

- (void)setColor:aColor
{
	id newColor = (aColor != nil ? aColor : [NSColor clearColor]);
	id old = [[[self color] retain] autorelease];
	[super setColor:newColor];
	if([old isEqual:newColor] || (old == nil)) { return; }
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PXColorWellColorChanged" object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:old, @"oldColor", nil]];
}

- copyWithZone:(NSZone *)zone
{
	return [[NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self]] retain];
}

@end
