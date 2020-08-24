#import "draw.h"

/*
 * This Ruler should really look at the NSMeasurementUnit default
 * and, based on that, use the proper units (whether centimeters
 * or inches) rather than just always using inches.
 */

#define LINE_X (15.0)
#define WHOLE_HT (10.0)
#define HALF_HT (8.0)
#define QUARTER_HT (4.0)
#define EIGHTH_HT (2.0)
#define NUM_X (3.0)

#define WHOLE (72)
#define HALF (WHOLE/2)
#define QUARTER (WHOLE/4)
#define EIGHTH (WHOLE/8)

@implementation Ruler

+ (float)width
{
    return 23.0;
}

- (id)initWithFrame:(NSRect)frameRect {
    [super initWithFrame:frameRect];
    [self setFont:[NSFont systemFontOfSize:8.0]];
    startX = [[self class] width];
    zeroAtViewOrigin = YES;
    return self;
}

- setZeroAtViewOrigin:(BOOL)flag
/*
 * Tells whether the ruler has "0" at
 * the origin of the view or not.
 */
{
    zeroAtViewOrigin = flag ? YES : NO;
    return self;
}

- setFont:(NSFont *)aFont
{
    float as, lh;

    font = aFont;
    // This function is defined in the old NSCStringText class,
    // but it doesn't actually have anything to do with the text object.
    // It uses only the font info.
    NSTextFontInfo(aFont, &as, &descender, &lh);
    if (descender < 0.0) descender = -1.0 * descender;

    return self;
}

- drawHorizontal:(NSRect)rect
{
    NSRect line, clip;
    int curPos, last, mod, i, j;

    PSsetgray(NSLightGray);
    NSRectFill(rect);

    if (lastlp >= rect.origin.x && lastlp < rect.origin.x + rect.size.width) lastlp = - 1.0;
    if (lasthp >= rect.origin.x && lasthp < rect.origin.x + rect.size.width) lasthp = - 1.0;

    line = _bounds;				/* draw bottom line */
    line.size.height = 1.0;
    PSsetgray(NSDarkGray);
    if (!NSIsEmptyRect(line = NSIntersectionRect(rect, line))) NSRectFill(line);

    line = _bounds;
    line.size.width = 1.0;
    line.origin.x = startX - 1.0;
    if (!NSIsEmptyRect(line = NSIntersectionRect(rect, line))) NSRectFill(line);

    line = _bounds;				/* draw ruler line */
    line.origin.y = LINE_X;
    line.size.height = 1.0;
    line.origin.x = startX;
    line.size.width = _bounds.size.width - startX;

    PSsetgray(NSBlack);
    if (!NSIsEmptyRect(line = NSIntersectionRect(rect, line))) NSRectFill(line);

    clip = rect;
    clip.origin.x = startX;
    clip.size.width = _bounds.size.width - startX;
    if (!NSIsEmptyRect(clip = NSIntersectionRect(rect, clip))) {
	curPos = (int)(clip.origin.x - startX);
	last = (int)(NSMaxX(clip) - startX);
	if ((mod = (curPos % EIGHTH))) curPos -= mod;
	if ((mod = (last % EIGHTH))) last -= mod;
	line.size.width = 1.0;
	[font set];
	for (j = curPos; j <= last; j += EIGHTH) {
	    i = !zeroAtViewOrigin ? _bounds.size.width - j : j;
	    line.origin.x =  startX + (float)i - (!zeroAtViewOrigin ? 1.0 : 0.0);
	    if (!(i % WHOLE)) {
		NSString *formatString;
		
		line.origin.y = LINE_X - WHOLE_HT;
		line.size.height = WHOLE_HT;
		NSRectFill(line);
		PSmoveto(((float) j + NUM_X) + startX, descender + line.origin.y - 2.0);
		formatString = [NSString stringWithFormat:@"%d", i / WHOLE];
		PSshow([formatString cString]);
	    } else if (!(i % HALF)) {
		line.origin.y = LINE_X - HALF_HT;
		line.size.height = HALF_HT;
		NSRectFill(line);
	    } else if (!(i % QUARTER)) {
		line.origin.y = LINE_X - QUARTER_HT;
		line.size.height = QUARTER_HT;
		NSRectFill(line);
	    } else if (!(i % EIGHTH)) {
		line.origin.y = LINE_X - EIGHTH_HT;
		line.size.height = EIGHTH_HT;
		NSRectFill(line);
	    }
	}
    }

    return self;
}


- drawVertical:(NSRect)rect
{
    NSRect line, clip;
    int curPos, last, mod, i, j;

    PSsetgray(NSLightGray);
    NSRectFill(rect);

    if (lastlp >= rect.origin.y && lastlp < rect.origin.y + rect.size.height) lastlp = - 1.0;
    if (lasthp >= rect.origin.y && lasthp < rect.origin.y + rect.size.height) lasthp = - 1.0;

    line = _bounds;				/* draw bottom line */
    line.origin.x = _bounds.size.width - 1.0;
    line.size.width = 1.0;
    PSsetgray(NSDarkGray);
    if (!NSIsEmptyRect(line = NSIntersectionRect(rect, line))) NSRectFill(line);

    line = _bounds;				/* draw ruler line */
    line.origin.x = _bounds.size.width - LINE_X - 2.0;
    line.size.width = 1.0;
    PSsetgray(NSBlack);
    if (!NSIsEmptyRect(line = NSIntersectionRect(rect, line))) NSRectFill(line);

    clip = rect;
    line.origin.x++;
    if (!NSIsEmptyRect(clip = NSIntersectionRect(rect, clip))) {
	curPos = (int)(clip.origin.y);
	last = (int)(NSMaxY(clip));
	if (!zeroAtViewOrigin) {
	    if ((mod = ((int)(_bounds.size.height - curPos) % EIGHTH))) curPos += mod;
	    if ((mod = ((int)(_bounds.size.height - last) % EIGHTH))) last += mod;
	} else {
	    if ((mod = (curPos % EIGHTH))) curPos -= mod;
	    if ((mod = (last % EIGHTH))) last -= mod;
	}
	line.size.height = 1.0;
	[font set];
	for (j = curPos; j <= last; j += EIGHTH) {
	    i = !zeroAtViewOrigin ? _bounds.size.height - j : j;
	    line.origin.y = (float)j - (!zeroAtViewOrigin ? 1.0 : 0.0);
	    if (!(i % WHOLE)) {
		NSString *formatString;
		line.size.width = WHOLE_HT;
		NSRectFill(line);
		PSmoveto(line.origin.x + 5.0, (float)j + (!zeroAtViewOrigin ? - 10.0 : 2.0));
		formatString = [NSString stringWithFormat:@"%d", i / WHOLE];
		PSshow([formatString cString]);
	    } else if (!(i % HALF)) {
		line.size.width = HALF_HT;
		NSRectFill(line);
	    } else if (!(i % QUARTER)) {
		line.size.width = QUARTER_HT;
		NSRectFill(line);
	    } else if (!(i % EIGHTH)) {
		line.size.width = EIGHTH_HT;
		NSRectFill(line);
	    }
	}
    }

    return self;
}

- (void)drawRect:(NSRect)rect
{
    if (_frame.size.width < _frame.size.height) {
	[self drawVertical:rect];
    } else {
	[self drawHorizontal:rect];
    }
}


#define SETPOSITION(value) (isVertical ? (rect.origin.y = value - (absolute ? 0.0 : 1.0)) : (rect.origin.x = value + (absolute ? 0.0 : startX)))
#define SETSIZE(value) (isVertical ? (rect.size.height = value) : (rect.size.width = value))
#define SIZE (isVertical ? rect.size.height : rect.size.width)

- doShowPosition:(float)lp :(float)hp absolute:(BOOL)absolute
{
    NSRect rect;
    BOOL isVertical = (_frame.size.width < _frame.size.height);

    rect = _bounds;

    if (!absolute && !isVertical) {
	if (lp < 0.0) lp -= startX;
	if (hp < 0.0) hp -= startX;
    }

    SETSIZE(1.0);
    lastlp = SETPOSITION(lp);
    NSHighlightRect(rect);
    lasthp = SETPOSITION(hp);
    NSHighlightRect(rect);

    return self;
}

- showPosition:(float)lp :(float)hp
{
    [self lockFocus];
    if (notHidden) [self doShowPosition:lastlp :lasthp absolute:YES];
    [self doShowPosition:lp :hp absolute:NO];
    [self unlockFocus];
    notHidden = YES;
    return self;
}

- hidePosition
{
    if (notHidden) {
	[self lockFocus];
	[self doShowPosition:lastlp :lasthp absolute:YES];
	[self unlockFocus];
	notHidden = NO;
    }
    return self;
}

@end
