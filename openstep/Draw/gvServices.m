#import "draw.h"

@implementation GraphicView(Services)

/* Services menu methods */

/*
 * Services in Draw are trivial to implement since we leverage heavily
 * off of the copy/paste code.  Note that write/readSelectionTo/FromPasteboard:
 * do little more than call the copy/paste code.
 */

/*
 * We are a valid requestor whenever any of the send or return types is
 * PostScript, TIFF, or Draw (actually, any return type that NSImage can
 * handle is okay with us).
 */

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{

    if ((!sendType || [sendType isEqual:@""] ||
	(([sendType isEqual:NSPostScriptPboardType] ||
	  [sendType isEqual:NSTIFFPboardType] ||
	  [sendType isEqual:DrawPboardType]) && [slist count])) &&
	(!returnType || [returnType isEqual:@""] ||
	  IncludesType([NSImage imagePasteboardTypes], returnType) ||
	  [returnType isEqual:DrawPboardType])) {
	return self;
    }
 
    return [super validRequestorForSendType:sendType returnType:returnType];
}

/*
 * If one of the requested types is one of the ones we handle,
 * then we put our selection in the Pasteboard.  The serviceActsOnSelection
 * flag is so that we can effectively undo a Service request.
 */

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
    int typeCount = [types count];
    int index = 0;
    
    while (index < typeCount) {
        NSString *currType = [types objectAtIndex:index];
	
	if ([currType isEqual:NSPostScriptPboardType] || [currType isEqual:NSTIFFPboardType] || [currType isEqual:DrawPboardType]) break;
	index++;
    }

    if ((index < typeCount) && [self copyToPasteboard:pboard types:types]) {
	gvFlags.serviceActsOnSelection = YES;
	return YES;
    } else {
	return NO;
    }
}

/*
 * When a result comes back from the Services menu request,
 * we replace the selection with the return value.
 * If the user really wants the return value in addition to
 * the current selection, she can simply copy, then paste
 * twice to get two copies, then choose the Services menu item.
 */

- readSelectionFromPasteboard:(NSPasteboard *)pboard
{
    id change;
    NSRect sbbox;
    NSPoint *position = &sbbox.origin;
    
    change = [[MultipleChange alloc] initChangeName:SERVICE_CALL_OP];
    [change startChange];
	if (gvFlags.serviceActsOnSelection) {
	    sbbox = [self getBBoxOfArray:slist extended:NO];
	    sbbox.origin.x += floor(sbbox.size.width / 2.0 + 0.5);
	    sbbox.origin.y += floor(sbbox.size.height / 2.0 + 0.5);
	    [self delete:self];
	    gvFlags.serviceActsOnSelection = NO;
	} else {
	    position = NULL;
	}
	[self pasteFromPasteboard:pboard andLink:DontLink at:position];
    [change endChange];

    return self;
}

@end
