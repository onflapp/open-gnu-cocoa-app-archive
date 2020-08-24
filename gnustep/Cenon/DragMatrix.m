
#import "DragMatrix.h"
//#import "DataPanel.subproj/DPModels.h"

NXAtom pastboardTypes[1];

@implementation DragMatrix


- init
{
	return [super init];
}

//Drag Support
- (unsigned int) draggingSourceOperationMaskForLocal:(BOOL)flag
{
    return (flag) ? NSDragOperationCopy : NSDragOperationNone;
}

#define mask (NSLeftMouseUpMask|NSLeftMouseDraggedMask)
/* true if mouse moves > n pixels from 'o' */
static int aMouseMoved(NSPoint *o, int n)
{	NSPoint	p;
	float	d;
	NSEvent *e;

	do
	{
		e = [[self window] nextEventMatchingMask:mask];
		p = [e locationInWindow];
		d = abs(p.x - o->x);
		if (d < abs(p.y - o->y))
			d = abs(p.y - o->y);
	}
	while ([e type] != NSLeftMouseUp && d < n);
	*o = p;
	return [e type] != NSLeftMouseUp;
}

- (void)mouseDown:(NSEvent *)event 
{	NSRect		dragRect;
	NSPoint		hit;
	NSEvent *saveEvent, *e, *ep;
	NSPasteboard	*dragPasteboard;
    int			oldMask, row, col;
	id			iCell;

#error EventConversion: eventMask: is obsolete; you no longer need to use the eventMask methods; for mouse moved events, see 'setAcceptsMouseMovedEvents:'
    oldMask = [[self window] eventMask];
#error EventConversion: setEventMask:(oldMask | mask): is obsolete; you no longer need to use the eventMask methods; for mouse moved events, see 'setAcceptsMouseMovedEvents:'
    [[self window] setEventMask:(oldMask | mask)];

//	move = aMouseMoved(&hit, 2);

	hit = [event locationInWindow];

	if(ep = (e = [[self window] nextEventMatchingMask:NSLeftMouseDownMask untilDate:[NSDate dateWithTimeIntervalSinceNow:0.2] inMode:NSEventTrackingRunLoopMode dequeue:NO]))
		ep = [[self window] nextEventMatchingMask:NSLeftMouseDownMask];

	hit = [self convertPoint:hit fromView:nil];
	if(!(iCell = [self cell] = [self getRow:&row column:&col forPoint:hit]))
		return NO;
	if(![[self cell] isEnabled])
		return NO;
	[self deselectAllCells];
	[self selectCell:iCell];

	if([event clickCount]>=2 || (ep && [ep clickCount]>=2))
	{	NSRect	rect;

		/* mouse inside text ? */
		rect = [self cellFrameAtRow:row column:col];
		rect = [iCell titleRectForBounds:rect];
		if([[self target] respondsToSelector:@selector(renameCell:to:)] && NSPointInRect(hit , rect))
		{	id fieldEditor = [[self window] fieldEditor:YES forObject:self];

			[iCell setEditable:YES];
			[iCell editWithFrame:rect inView:self editor:fieldEditor delegate:self event:event];
			return NO;
		}

		[[self target] perform:[self doubleAction] withObject:self];
		return NO;
	}

	[[self target] perform:[self action] withObject:self];

	saveEvent = event;
	if (aMouseMoved(&hit, 1))
	{	const char	*filename;

		if(!(filename = [[self target] filenameForCell:iCell]))
			return NO;

		hit.x = hit.y = 0;
		dragRect = [self cellFrameAtRow:row column:col];
		dragRect.origin.x += dragRect.size.width/2.0;
		dragRect.size = [[iCell image] size];
		dragRect.origin.x -= dragRect.size.width/2.0 -4;
		dragRect.origin.y += dragRect.size.height -4;
		dragPasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		[dragPasteboard declareTypes:[NSArray arrayWithObject:[NSString stringWithCString:*pastboardTypes]] owner:self];

		/* fill pasteboard */
#error StreamConversion: NSFilenamesPboardType used to be NXFilenamePboardType. Pasteboard data of type NSFilenamesPboardType will be an NSArray of NSString. Use 'setPropertyList:forType:' and 'propertyListForType:'
	    [dragPasteboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:self];
#error StreamConversion: NSFilenamesPboardType used to be NXFilenamePboardType. Pasteboard data of type NSFilenamesPboardType will be an NSArray of NSString. Use 'setPropertyList:forType:' and 'propertyListForType:'
	    [dragPasteboard setData:[NSData dataWithBytes:filename length:strlen(filename)+1] forType:NSFilenamesPboardType];

		[self dragImage:[iCell image] at:(dragRect.origin) offset:NSMakeSize((&hit)->x,(&hit)->y) event:saveEvent pasteboard:dragPasteboard source:self slideBack:YES];
	}

#error EventConversion: setEventMask:oldMask: is obsolete; you no longer need to use the eventMask methods; for mouse moved events, see 'setAcceptsMouseMovedEvents:'
    [[self window] setEventMask:oldMask];
	return NO;
//	return [super mouseDown:event];
}

- (BOOL)textShouldEndEditing:(NSText *)textObject
{	int			i, len;
	char		str[MAXPATHLEN];
	NSData *stream;

	stream = [textObject stream];
	len = [[textObject text] length];
	strncpy(str, stream->buf_base, len);
	str[len] = 0;
	for(i=[[self cells] count]-1; i>=0; i--)
	{	id iCell = [[self cells] objectAtIndex:i];

		if((iCell == [self cell]) || ![iCell title])
			continue;
		if([[iCell title] isEqualToString:[NSString stringWithCString:str]])
			return NO;
	}
	(![super textShouldEndEditing:textObject]);
	return YES;
}

#warning NotificationConversion: 'textDidEndEditing:' used to be 'textDidEnd:'.  This conversion assumes this method is implemented or sent to a delegate of NSText.  If this method was implemented by a NSMatrix or NSTextField textDelegate, use the text notifications in NSControl.h.
- (void)textDidEndEditing:(NSNotification *)notification
#warning NotificationConversion: if this notification was not posted by NSText (eg. was forwarded by NSMatrix or NSTextField from the field editor to their textDelegate), then the text object is found by [[notification userInfo] objectForKey:@"NSFieldEditor"] rather than [notification object]
{	NSText *theText = [notification object];
    int whyEnd = [[[notification userInfo] objectForKey:@"NSTextMovement"] intValue];
    NSData *stream;
	int			len;
	char 		str[MAXPATHLEN];

	stream = [theText stream];
	len = [[theText text] length];
	strncpy(str, stream->buf_base, len);
	str[len] = 0;

	if([[self target] respondsToSelector:@selector(renameCell:to:)])
		[[self target] renameCell:[self cell] to:str];

	/* textDidEnd:endChar: should call endEditing: on the Control's cell to 
	 * remove the fieldEditor from the View hierarchy.
	 */
	[[self cell] endEditing:theText];
	[[self cell] setEditable:NO];
	[[self cell] setTitle:[NSString stringWithCString:str]];
}

@end
