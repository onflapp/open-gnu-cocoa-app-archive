@interface Line : Graphic
{
    int startCorner;	/* corner we start creating from */
}

/* Creation method */

- (id)init;

/* Methods overridden from superclass */

- (BOOL)isValid;
- (int)moveCorner:(int)corner to:(NSPoint)point constrain:(BOOL)flag;
- (void)constrainCorner:(int)corner toAspectRatio:(float)ratio;
- (int)cornerMask;
- draw;
- (BOOL)hit:(NSPoint)point;

/* Methods to be overridden by subclassers */

- (float)arrowAngle:(int)corner;
- (void)drawLine;

/* Archiving */

- (id)propertyList;
- initFromPropertyList:(id)plist inDirectory:(NSString *)directory;

@end
