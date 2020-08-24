/*
	2001.04.20  JPEG compression of TIFF format is not supported...
*/

#import  "TiffSavePanel.h"
#import  <Foundation/NSString.h>
#import  <AppKit/NSApplication.h>
#import  <AppKit/NSControl.h>
#import  <AppKit/NSMatrix.h>
#import  <AppKit/NSBitmapImageRep.h>

#define  Tag_None	0
#define  Tag_LZW	1
#define  Tag_JPEG	2

#define  Tag_tiff	0
#define  Tag_tiF	1

static int suffixTagSV = Tag_tiff;

@implementation TiffSavePanel

+ (NSString *)nameOfAccessory { return @"TiffAccessory.nib"; }

+ (void)setSuffix:(int)tag { suffixTagSV = tag; }

- (void)loadNib
{
	[super loadNib];
	[suffixButton selectCellWithTag:(suffixTag = suffixTagSV)];
}

- (int)compressType
{
	if ([compButton selectedTag] == Tag_None)
		return NSTIFFCompressionNone;
	return NSTIFFCompressionLZW;
}

/* Over write */
- (NSString *)suffix
{
	return (suffixTag == Tag_tiF) ? @"tif" : @"tiff";
}

@end
