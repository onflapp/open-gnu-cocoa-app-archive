#import "draw.h"

@implementation GridView
/*
 * This class is the heart of the Grid Inspector modal panel.
 * It implements the draggable grid.  It also provides the external
 * interface (i.e. the runModalForGraphicView: method) to running
 * the panel.  It is a good example of a modal panel.
 * See the Interface Builder file for a better understanding of
 * the outlets and actions sent by controls in the window containing
 * the GridView.
 */

- (void)runModalForGraphicView:(GraphicView *)view
{
    int gridSpacing;
    float gridGray;

    if (graphicView != view) {
	graphicView = view;
	gridSpacing = [view gridSpacing];
	[spacing setIntValue:(gridSpacing >= 4 ? gridSpacing : 10)];
	gridGray = [view gridGray];
	[grayField setFloatValue:gridGray];
	[graySlider setFloatValue:gridGray];
	[self display];
    }

    [NSApp runModalForWindow:[self window]];
    [[self window] orderOut:self]; 
}

- (void)drawGrid:(int)grid
{
    float x, y, max, increment;
    NSRect bounds = [self bounds];

    increment = (float)grid;
    max = bounds.origin.y + bounds.size.height;
    for (y = bounds.origin.y; y < max; y += increment) {
	PSmoveto(0.0, y);
	PSlineto(bounds.size.width, y);
    }
    max = bounds.origin.x + bounds.size.width;
    for (x = bounds.origin.x; x < max; x += increment) {
	PSmoveto(x, 0.0);
	PSlineto(x, bounds.size.height);
    }
    PSstroke(); 
}

- (void)drawRect:(NSRect)rect
{
    int grid;
    float gray;

    grid = [spacing intValue];
    grid = MAX(grid, 0.0);
    PSsetgray(NSWhite);
    NSRectFill(rect);
    if (grid >= 4) {
	gray = [grayField floatValue];
	gray = MIN(gray, 1.0);
	gray = MAX(gray, 0.0);
	PSsetgray(gray);
	PSsetlinewidth(0.0);
	[self drawGrid:grid];
    }
    PSsetgray(NSBlack);
    NSFrameRect([self bounds]);
}

- (void)mouseDown:(NSEvent *)event 
{
    NSPoint p, start;
    int grid, gridCount;

    start = [event locationInWindow];
    start = [self convertPoint:start fromView:nil];
    grid = MAX([spacing intValue], 1.0);
    gridCount = (int)MAX(start.x, start.y) / grid;
    gridCount = MAX(gridCount, 1.0);

    event = [[self window] nextEventMatchingMask:NSLeftMouseDraggedMask|NSLeftMouseUpMask];
    while ([event type] != NSLeftMouseUp) {
	p = [event locationInWindow];
	p = [self convertPoint:p fromView:nil];
	grid = (int)MAX(p.x, p.y) / gridCount;
	grid = MAX(grid, 1.0);
	if (grid != [spacing intValue]) {
	    [form abortEditing];
	    [spacing setIntValue:grid];
	    [self display];
	}
	event = [[self window] nextEventMatchingMask:NSLeftMouseDraggedMask|NSLeftMouseUpMask];
    }
}

/* Target/Action methods */

- (void)show:sender
{
    [NSApp stopModal];
    [graphicView setGridSpacing:[spacing intValue] andGray:[grayField floatValue]];
    [graphicView setGridVisible:YES]; 
}

- (void)off:sender
{
    [NSApp stopModal];
    [graphicView setGridSpacing:1]; 
}

- (void)cancel:(id)sender
{
    [NSApp stopModal];
}

- (void)changeSpacing:sender
{
    [self setNeedsDisplay:YES]; 
}

- (void)changeGray:sender
{
    if (sender == graySlider) {
	[form abortEditing];
	[grayField setFloatValue:[sender floatValue]];
    } else {
	[graySlider setFloatValue:[sender floatValue]];
    }
    [self setNeedsDisplay:YES]; 
}

/* IB outlet-setting methods */

- setAppIconButton:anObject
{
    [anObject setImage:[NSImage imageNamed:@"appIcon"]];
    return self;
}

@end
