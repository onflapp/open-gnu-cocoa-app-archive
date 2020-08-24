/*
	This class is the superclass of ToyWinEPS and ToyWinPict.
*/

#import "ToyWin.h"

@class NSData, NSBitmapImageRep;

@interface ToyWinVector : ToyWin
{
	NSBitmapImageRep *tiffrep;
}

- (id)init;
- (void)dealloc;

/* New */
// NSData objects returned by these methods will be autoreleased.
- (NSData *)openTiffDataBy:(float)scale compress:(BOOL)compress;

/* Over write */
- (int)getBitmap:(unsigned char **)map info:(commonInfo **)infp;
- (void)freeTempBitmap;
- (void)printWithDPI:(int)dpi;

@end
