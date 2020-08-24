#import "draw.h"

@implementation SyncScrollView
/*
 * This subclass of ScrollView is extremely useful for programmers
 * who want some View to scroll along with a main docView.  A good
 * example is a spreadsheet that wants its column and row headings
 * to scroll along with the cells in the spreadsheet itself.
 * It is actually quite simple.  We simply override tile to place
 * two ClipViews with our views (rulers in this case) in them into
 * the view hierarchy, then override scrollClip:to: to update their
 * drawing origins when the docView is scrolled.  We also override
 * reflectScroll: since we don't want that to apply to our little
 * ruler views, only to the main docView.
 */

- (void)setRulerClass:factoryId
{
    if ([factoryId conformsToProtocol:@protocol(Ruler)]) rulerClass = factoryId; 
}

- (void)setRulerWidths:(float)horizontal :(float)vertical
{
    horizontalRulerWidth = horizontal;
    verticalRulerWidth = vertical; 
}

- (BOOL)bothRulersAreVisible
{
    return verticalRulerIsVisible && horizontalRulerIsVisible;
}

- (BOOL)eitherRulerIsVisible
{
    return verticalRulerIsVisible || horizontalRulerIsVisible;
}

- (BOOL)verticalRulerIsVisible
{
    return verticalRulerIsVisible;
}

- (BOOL)horizontalRulerIsVisible
{
    return horizontalRulerIsVisible;
}

- (void)setRulerOrigin:(RulerOrigin)origin
{
    RulerOrigin oldRulerOrigin = rulerOrigin;

    rulerOrigin = origin;
    switch (origin) {
	case LowerRight:
	    [[hClipRuler documentView] setZeroAtViewOrigin:NO];
	    break;
	case UpperRight:
	    [[hClipRuler documentView] setZeroAtViewOrigin:NO];
	case UpperLeft:
	    [[vClipRuler documentView] setZeroAtViewOrigin:NO];
	case LowerLeft:
	    break;
	default:
	    rulerOrigin = oldRulerOrigin;
	    break;
    } 
}

- makeRulers
/*
 * This makes the rulers.
 * We do this lazily in case the user never asks for the rulers.
 */
{
    NSView <Ruler> *ruler;
    NSRect aRect, bRect;

    if (!rulerClass || (!horizontalRulerWidth && !verticalRulerWidth)) return nil;

    if (horizontalRulerWidth) {
	aRect = [[_contentView documentView] frame];
	NSDivideRect(aRect, &bRect, &aRect, horizontalRulerWidth, NSMinYEdge);
	hClipRuler = [[NSClipView allocWithZone:(NSZone *)[self zone]] init];
	ruler = [[rulerClass allocWithZone:(NSZone *)[self zone]] initWithFrame:bRect];
	[hClipRuler setDocumentView:ruler];
    }
    if (verticalRulerWidth) {
	aRect = [[_contentView documentView] frame];
	NSDivideRect(aRect, &bRect, &aRect, verticalRulerWidth, NSMinXEdge);
	vClipRuler = [[NSClipView allocWithZone:(NSZone *)[self zone]] init];
	ruler = [[rulerClass allocWithZone:(NSZone *)[self zone]] initWithFrame:bRect];
	[vClipRuler setDocumentView:ruler];
    }
    [self setRulerOrigin:rulerOrigin];
    rulersMade = 1;

    return self;
}

- (void)updateRulers:(const NSRect *)rect
{
    if (!rect) {
	if (verticalRulerIsVisible) {
	    [[vClipRuler documentView] hidePosition];
	}
	if (horizontalRulerIsVisible) {
	    [[hClipRuler documentView] hidePosition];
	}
    } else {
	if (verticalRulerIsVisible) {
	    [[vClipRuler documentView] showPosition:rect->origin.y :rect->origin.y + rect->size.height];
	}
	if (horizontalRulerIsVisible) {
	    [[hClipRuler documentView] showPosition:rect->origin.x :rect->origin.x + rect->size.width];
	}
    } 
}

- (void)updateRuler
{
    NSRect aRect, bRect;

    if (horizontalRulerIsVisible) {
	aRect = [[_contentView documentView] frame];
	NSDivideRect(aRect, &bRect, &aRect, horizontalRulerWidth, NSMinYEdge);
	bRect.size.width += verticalRulerWidth;
	[[hClipRuler documentView] setFrame:bRect];
	[hClipRuler display];
    }
    if (verticalRulerIsVisible) {
	aRect = [[_contentView documentView] frame];
	NSDivideRect(aRect, &bRect, &aRect, verticalRulerWidth, NSMinXEdge);
	[[vClipRuler documentView] setFrame:bRect];
	[vClipRuler display];
    } 
}

- (BOOL)showRuler:(BOOL)showIt isHorizontal:(BOOL)isHorizontal
/*
 * Adds or removes a ruler from the view hierarchy.
 * Returns whether or not it succeeded in doing so.
 */
{
    NSClipView *ruler;
    BOOL isVisible;
    NSRect cRect, rRect;

    isVisible = isHorizontal ? horizontalRulerIsVisible : verticalRulerIsVisible;
    if ((showIt && isVisible) || (!showIt && !isVisible)) return NO;
    if (showIt && !rulersMade && ![self makeRulers]) return NO;
    ruler = isHorizontal ? hClipRuler : vClipRuler;

    if (!showIt && isVisible) {
	[ruler removeFromSuperview];
	if (isHorizontal) {
	    horizontalRulerIsVisible = NO;
	} else {
	    verticalRulerIsVisible = NO;
	}
    } else if (showIt && !isVisible && ruler) {
	[self addSubview:ruler];
	cRect = [_contentView bounds];
	rRect = [hClipRuler bounds];
	[hClipRuler setBoundsOrigin:(NSPoint){ cRect.origin.x, rRect.origin.y }];
	rRect = [vClipRuler bounds];
	[vClipRuler setBoundsOrigin:(NSPoint){ rRect.origin.x, cRect.origin.y }];
	if (isHorizontal) {
	    horizontalRulerIsVisible = YES;
	} else {
	    verticalRulerIsVisible = YES;
	}
    }

    return YES;
}

- adjustSizes
{
    id windelegate;
    NSRect winFrame;
    NSWindow *window = [self window];

    windelegate = [window delegate];
    if ([windelegate respondsToSelector:@selector(windowWillResize:toSize:)]) {
	winFrame = [window frame];
	winFrame.size = [windelegate windowWillResize:window toSize:winFrame.size];
	[window setFrame:winFrame display:YES];
    }
    [self resizeSubviewsWithOldSize:NSZeroSize];

    return self;
}

- (void)showHorizontalRuler:(BOOL)flag
{
    if ([self showRuler:flag isHorizontal:YES]) [self adjustSizes]; 
}

- (void)showVerticalRuler:(BOOL)flag
{
    if ([self showRuler:flag isHorizontal:NO]) [self adjustSizes]; 
}

- (void)showHideRulers:sender
/*
 * If both rulers are visible, they are both hidden.
 * Otherwise, both rulers are made visible.
 */
{
    BOOL resize = NO;

    if (verticalRulerIsVisible && horizontalRulerIsVisible) {
	resize = [self showRuler:NO isHorizontal:YES];
	resize = [self showRuler:NO isHorizontal:NO] || resize;
    } else {
	if (!horizontalRulerIsVisible) resize = [self showRuler:YES isHorizontal:YES];
	if (!verticalRulerIsVisible) resize = [self showRuler:YES isHorizontal:NO] || resize;
    }
    if (resize) [self adjustSizes]; 
}

/* ScrollView-specific stuff */

- (void)dealloc
{
    
    if (!horizontalRulerIsVisible) /* TOPS-WARNING!!!  NSObject conversion:  This release used to be a free. */ [hClipRuler release];
    if (!verticalRulerIsVisible) /* TOPS-WARNING!!!  NSObject conversion:  This release used to be a free. */ [vClipRuler release];
    [super dealloc];    

}

- (void)reflectScrolledClipView:(NSClipView *)cView
/*
 * We only reflect scroll in the contentView, not the rulers.
 */
{
    if (cView != hClipRuler && cView != vClipRuler) [super reflectScrolledClipView:cView];
}

- (void)tile
/*
 * Here is where we lay out the subviews of the ScrollView.
 * Note the use of NSDivideRect() to "slice off" a section of
 * a rectangle.  This is useful since the two scrollers each
 * result in slicing a section off the _contentView of the
 * ScrollView.
 */
{
    NSRect aRect, bRect, cRect;

    [super tile];

    if (horizontalRulerIsVisible || verticalRulerIsVisible) {
	aRect = [_contentView frame];
	cRect = [[self documentView] frame];
	if (horizontalRulerIsVisible && hClipRuler) {
	    NSDivideRect(aRect, &bRect, &aRect, horizontalRulerWidth, NSMinYEdge);
	    [hClipRuler setFrame:bRect];
	    [[hClipRuler documentView] setFrameSize:(NSSize){ cRect.size.width+verticalRulerWidth, bRect.size.height }];
	}
	if (verticalRulerIsVisible && vClipRuler) {
	    NSDivideRect(aRect, &bRect, &aRect, verticalRulerWidth, NSMinXEdge);
	    [vClipRuler setFrame:bRect];
	    [[vClipRuler documentView] setFrameSize:(NSSize){ bRect.size.width, cRect.size.height }];
	}
	[_contentView setFrame:aRect];
    }
}

- (void)scrollClipView:(NSClipView *)aClipView toPoint:(NSPoint)aPoint
/*
 * This is sent to us instead of rawScroll:.
 * We scroll the two rulers, then the clipView itself.
 */
{
    id fr;
    NSRect rRect;

    if (horizontalRulerIsVisible && hClipRuler) {
	rRect = [hClipRuler bounds];
	rRect.origin.x = aPoint.x;
	[hClipRuler scrollToPoint:(rRect.origin)];
    }
    if (verticalRulerIsVisible && vClipRuler) {
	rRect = [vClipRuler bounds];
	rRect.origin.y = aPoint.y;
	[vClipRuler scrollToPoint:(rRect.origin)];
    }

    [aClipView scrollToPoint:aPoint];

    fr = [_window firstResponder];
    if ([fr respondsToSelector:@selector(isRulerVisible)] && [fr isRulerVisible]) [fr updateRuler];
}

- (void)viewFrameChanged:(NSNotification *)notification {
    NSRect aRect, bRect, cRect;

    if (horizontalRulerIsVisible || verticalRulerIsVisible) {
	aRect = [_contentView frame];
	cRect = [[self documentView] frame];
	if (horizontalRulerIsVisible && hClipRuler) {
	    NSDivideRect(aRect, &bRect, &aRect, horizontalRulerWidth, NSMinYEdge);
	    [[hClipRuler documentView] setFrameSize:(NSSize){ cRect.size.width+verticalRulerWidth, bRect.size.height }];
	}
	if (verticalRulerIsVisible && vClipRuler) {
	    NSDivideRect(aRect, &bRect, &aRect, verticalRulerWidth, NSMinXEdge);
	    [[vClipRuler documentView] setFrameSize:(NSSize){ bRect.size.width, cRect.size.height }];
	}
    }
}

@end
