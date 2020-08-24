/*
 * Any View that responds to these messages can be a "ruler".
 * This is a nice way to make an object which works in concert
 * with another object, but isn't hardwired into the implementation
 * of that object and, instead, publishes a minimal interface
 * which it expects another object to respond to.
 */

@protocol Ruler
- setZeroAtViewOrigin:(BOOL)flag;		/* if NO, coordinates go right->left or top->bottom */
- hidePosition;				/* hide any positioning markers */
- showPosition:(float)p :(float)q;	/* put the positioning markers at p and q */
@end

typedef enum {
    LowerLeft = 0, LowerRight, UpperLeft, UpperRight
} RulerOrigin;

@interface SyncScrollView : NSScrollView
{
    NSClipView *hClipRuler;
    NSClipView *vClipRuler;
    id rulerClass;
    float horizontalRulerWidth;
    float verticalRulerWidth;
    RulerOrigin rulerOrigin;
    BOOL verticalRulerIsVisible;
    BOOL horizontalRulerIsVisible;
    BOOL rulersMade;
}

/* Setting up the rulers */

- (BOOL)bothRulersAreVisible;
- (BOOL)eitherRulerIsVisible;
- (BOOL)verticalRulerIsVisible;
- (BOOL)horizontalRulerIsVisible;

- (void)setRulerClass:factoryId;
- (void)setRulerWidths:(float)horizontal :(float)vertical;
- (void)setRulerOrigin:(RulerOrigin)origin;

- (void)showHorizontalRuler:(BOOL)flag;
- (void)showVerticalRuler:(BOOL)flag;

- (void)updateRuler;

/* Comes up the responder chain to us */

- (void)updateRulers:(const NSRect *)rect;
- (void)showHideRulers:sender;

/* Overridden from superclass */

- (void)reflectScrolledClipView:(NSClipView *)cView;
- (void)tile;
- (void)scrollClipView:(NSClipView *)aClipView toPoint:(NSPoint)aPoint;
- (void)viewFrameChanged:(NSNotification *)notification;

@end
