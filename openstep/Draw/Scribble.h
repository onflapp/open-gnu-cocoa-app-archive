#define CHUNK_SIZE 64	/* this is a malloc good size */

@interface Scribble : Graphic
{
    float *points;	/* the points in the scribble */
    char *userPathOps;	/* the linetos */
    int length;		/* the number of points */
    float bbox[4];	/* the bounding box of the scribble */
}

/* Factory methods */

+ (NSCursor *)cursor;

/* Free method */

- (void)dealloc;

/* Private methods */

- (void)allocateChunk;

/* Methods overridden from superclass */

- (float)naturalAspectRatio;
- (int)moveCorner:(int)corner to:(NSPoint)point constrain:(BOOL)flag;
- (BOOL)create:(NSEvent *)event in:(GraphicView *)view;
- draw;

/* Archiving methods */

- (id)propertyList;
- initFromPropertyList:(id)plist inDirectory:(NSString *)directory;

@end
