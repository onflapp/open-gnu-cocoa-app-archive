@interface Polygon : Scribble

/* Methods overridden from superclass */

+ (NSCursor *)cursor;
- (BOOL)create:(NSEvent *)event in:(GraphicView *)view;

@end

