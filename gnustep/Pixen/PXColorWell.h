/* PXColorWell */

#import <AppKit/AppKit.h>

@interface PXColorWell : NSColorWell
{
}
- (void)rightSelect;
- (void)leftSelect;
- (void)_setColorNoVerify:aColor;

@end
