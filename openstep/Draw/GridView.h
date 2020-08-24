@interface GridView : NSView
{
    id spacing;
    id grayField;
    id graySlider;
    id graphicView;
    id form;
}

/* Public methods */

- (void)runModalForGraphicView:(GraphicView *)graphicView;

/* Private methods */

- (void)drawGrid:(int)grid;

/* Methods overridden from superclass */

- (void)drawRect:(NSRect)rects;
- (void)mouseDown:(NSEvent *)event;

/* Target/Action methods */

- (void)show:sender;
- (void)off:sender;
- (void)cancel:(id)sender;
- (void)changeSpacing:sender;
- (void)changeGray:sender;

@end
