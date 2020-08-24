#import  <AppKit/AppKit.h>
#import  "common.h"


@interface ColorMap:NSObject

- (id)init;
- (void)setFourBitsPalette:(BOOL)flag;
- (id)mallocForFullColor;
- (id)mallocForPaletteColor;
- (void)dealloc;
- (int)getAllColor:(refmap)map limit:(int)limit alpha:(BOOL *)alpha;
- (int)getAllColor:(refmap)map limit:(int)limit;
- (int)regPalColorWithAlpha:(BOOL)alpha;
- (void)tabInitForRegColors;
- (int)regColorToMap: (int)red : (int)green : (int)blue;
- (void)regGivenPal:(paltype *)gpal colors:(int)cnum;
- (paltype *)getNormalmap:(int *)cnum;
- (paltype *)getReducedMap:(int *)cnum alpha:(BOOL)alpha;
- (paltype *)getPalette;

@end
