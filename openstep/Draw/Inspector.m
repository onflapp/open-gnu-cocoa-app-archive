#import "draw.h"

@implementation Inspector

- (void)reloadGraphic:(Graphic *)graphic
/*
 * Loads up the size fields if they have changed since last time
 * we loaded up the panel with this graphic.  This is used since we
 * know that none of the things controlled by the InspectorPanel
 * except the size or the fill color can change from event to event
 * (we should probably not make that assumption, but it makes the
 * updating of this panel go much faster and since it has to happen
 * on every event, it seems a worthwhile optimization).
 */
{
    NSRect bounds;

    if (graphic) {
        bounds = [graphic bounds];
        if (lastSize.width != bounds.size.width) {
            [width setFloatValue:bounds.size.width];
            lastSize.width = bounds.size.width;
        }
        if (lastSize.height != bounds.size.height) {
            [height setFloatValue:bounds.size.height];
            lastSize.height = bounds.size.height;
        }
        if ([graphic fill] != [filled indexOfSelectedItem]) [filled selectItemAtIndex:[graphic fill]];
        if (graphic && ![[fillColor color] isEqual:[graphic fillColor]]) [fillColor setColor:[graphic fillColor]];
    }
}

- (void)loadOrReloadGraphic:(Graphic *)graphic
{
    if (selectedGraphic == graphic) {
        return [self reloadGraphic:graphic];
    } else {
        return [self loadGraphic:graphic];
    }
}

- (void)loadGraphic:(Graphic *)graphic
/*
 * Loads up the InspectorPanel with a new graphic's attributes.
 */
{
    NSRect bounds;

    if ((selectedGraphic = graphic)) {
        [lineWidthField setFloatValue:[graphic lineWidth]];
        [lineWidthSlider setFloatValue:[graphic lineWidth]];
        [lineColor setColor:[graphic lineColor]];
        [fillColor setColor:[graphic fillColor]];
        bounds = [graphic bounds];
        [width setFloatValue:bounds.size.width];
        [height setFloatValue:bounds.size.height];
        lastSize = bounds.size;
	[filled selectItemAtIndex:[graphic fill]];
	[lineCap selectItemAtIndex:[graphic lineCap]];
	[arrows selectItemAtIndex:[graphic lineArrow]];
	[lineJoin selectItemAtIndex:[graphic lineJoin]];
        [formEntry setIntValue:[graphic isFormEntry]];
    }
}

- (void)load:(GraphicView *)view
/*
 * If the view has only one selected graphic, then the panel is loaded with it.
 */
{
    graphicView = view;
    [self loadOrReloadGraphic:[view selectedGraphic]]; 
}

- (void)initializeGraphic:(Graphic *)graphic
/*
 * Goes the opposite way of loadGraphic.  Gives the Graphic the attributes
 * which are in the InspectorPanel.
 */
{
    float value;
    NSString *lineWidth;
    NSColor * color;

    lineWidth = [lineWidthField stringValue];
    if (![lineWidth isEqual:@""] && (value = [lineWidth floatValue])) [graphic setLineWidth:&value];
    color = [lineColor color];
    [graphic setLineColor:color];
    color = [fillColor color];
    [graphic setFillColor:color];
    [graphic setFill:[filled indexOfSelectedItem]];
    [graphic setLineCap:[lineCap indexOfSelectedItem]];
    [graphic setLineArrow:[arrows indexOfSelectedItem]];
    [graphic setLineJoin:[lineJoin indexOfSelectedItem]];
}

- (void)preset
{
    [fillColor setColor:[NSColor whiteColor]];
    [lineColor setColor:[NSColor blackColor]]; 
}

/* Overridden from superclass */

- (void)windowDidUpdate:(NSWindow *)sender
/*
 * Called each time an event occurs.  Loads up the panel.
 */
{
    [self load:[[NSApp currentDocument] view]];
}

/* Target/Action methods */
/* These go here to keep the Inspector self-consistent. */
/* Other things just go down the responder chain. */

- (void)changeLineWidth:sender
{
    float linewidth;

    linewidth = [sender floatValue];
    if (sender == lineWidthSlider) {
	if ([[[graphicView window] currentEvent] type] == NSLeftMouseDragged) {
	    [[graphicView selectedGraphics] makeObjectsPerform:@selector(deselect)];
	} else {
	    [[graphicView selectedGraphics] makeObjectsPerform:@selector(select)];
	}
	[lineWidthField setFloatValue:linewidth];
    } else {
	if ([lineWidthSlider maxValue] < linewidth) {
	    [lineWidthSlider setMaxValue:linewidth];
	}
	[lineWidthSlider setFloatValue:linewidth];
	[[graphicView window] makeKeyWindow];
    }
    [graphicView takeLineWidthFrom:lineWidthField]; 
}

- (void)changeFillColor:sender
{
    [graphicView takeFillColorFrom:sender];
    if (![filled indexOfSelectedItem]) [filled selectItemAtIndex:2];
}

- (void)changeDimensions:sender
{
    id change;
    NSSize size;
    NSWindow *window;

    size.width = [width floatValue];
    size.height = [height floatValue];
    change = [[DimensionsGraphicsChange alloc] initGraphicView:graphicView];
    [change startChange];
        [graphicView graphicsPerform:@selector(sizeTo:) with:&size];
        window = [graphicView window];
        [window flushWindow];
        [window makeKeyWindow];
    [change endChange]; 
}

- (NSString *)description
{
    return [(NSDictionary *)[NSDictionary dictionaryWithObjectsAndKeys:selectedGraphic, @"Selected Graphic", graphicView, @"Active View", propertyListFromNSSize(lastSize), @"Size", nil] description];
}

@end
