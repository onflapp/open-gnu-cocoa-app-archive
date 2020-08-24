@interface Inspector : NSObject
{
    Graphic *selectedGraphic;	/* the currently displayed graphic */
    GraphicView *graphicView;	/* the view selectedGraphic is in */
    NSSize lastSize;		/* the last size displayed */
    NSSlider *lineWidthSlider;
    NSTextField *lineWidthField;
    NSPopUpButton *arrows;
    NSTextField *width;
    NSColorWell *lineColor;
    NSColorWell *fillColor;
    NSPopUpButton *filled;
    NSPopUpButton *lineCap;
    NSPopUpButton *lineJoin;
    NSTextField *height;
    NSButton *formEntry;
}

/* Public methods */

- (void)loadGraphic:(Graphic *)graphic;
- (void)load:(GraphicView *)graphicView;
- (void)initializeGraphic:(Graphic *)graphic;
- (void)preset;

/* Panel delegate method */

- (void)windowDidUpdate:(NSWindow *)sender;

/* Target/Action methods */

- (void)changeDimensions:sender;
- (void)changeLineWidth:sender;
- (void)changeFillColor:sender;

@end
