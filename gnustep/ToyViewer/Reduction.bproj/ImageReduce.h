#import  "../ImgOprAbs.h"

@class ColorMap;

enum {
	sp_NONE = 0,
	sp_Default,
	sp_FixedPalette
};

@interface ImageReduce : ImgOprAbs
{
	int	colornum;
	ColorMap *colormap;
	unsigned char *origmap[MAXPLANE];
	unsigned char *newmap[MAXPLANE];
	BOOL	fsFlag;
	BOOL	fourFlag;
	BOOL	hasAlpha;
	int	special;
}

- (id)init;
- (void)dealloc;
- (void)reduce:sender;		/* Default Method */
- (void)reduceWithFixedPalette:(int)colors;
- reduceTo:(int)colors withFS:(BOOL)fsflag fourBit:(BOOL)fourflag;
- (BOOL)needReduce:(NSString *)fn colors:(int)cnum ask:(BOOL)ask;

@end

@interface ImageReduce (ColorHalf)

- colorHalftoneWith:(int)colnum method:(int)tag;
	/* by Dither or MDA (Mean Density Approximation Method) */ 

@end

@interface ImageReduce (CutDownBits)

- (void)cutDownBitsTo:(int)bits;

@end

