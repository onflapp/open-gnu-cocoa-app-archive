#import <Foundation/NSObject.h>

@interface ReduceCtr:NSObject
{
	id	withDitherSW;
	id	fourBitSW;
	id	mcaColors;
	id	fixedColors;
	id	psudoMethod;
	id	psudoColors;
	id	cutdownBits;
}

- (void)reduceSelect:sender;
- (void)reduceFixedPalette:sender;
- (void)truncateBits:sender;
- (void)colorHalftone:sender;

@end
