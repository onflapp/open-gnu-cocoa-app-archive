#import  <Foundation/NSObject.h>

@interface ImageResize : NSObject

- (void)newBitmapWith:(float)factor;
- (void)EPSResizeWith:(float)factor;
- (void)simpleResizeWith:(float)factor;
- (void)smoothResizeWith:(int) b :(int) a;

@end
