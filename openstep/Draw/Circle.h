@interface Circle : Graphic

/* Methods overridden from superclass(es) */

- (Graphic *)colorAcceptorAt:(NSPoint)point;
- (float)naturalAspectRatio;
- draw;
- (BOOL)hit:(NSPoint)point;

@end
