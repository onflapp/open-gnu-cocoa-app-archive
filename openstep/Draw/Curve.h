@interface Curve : Line

/* Methods overridden from superclass */

- (float)arrowAngle:(int)corner;
- (void)drawLine;
- (BOOL)hit:(NSPoint)point;

@end
