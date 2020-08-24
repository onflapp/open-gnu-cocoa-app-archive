#import  "JpegSavePanel.h"
#import  <Foundation/NSString.h>
#import  <Foundation/NSUserDefaults.h>
#import  <AppKit/NSControl.h>
#import  <AppKit/NSMatrix.h>

#define  Tag_jpg	0
#define  Tag_jpEg	1
#define	 JpegDefFactor	90	/* Default */
#define  JPEGFactor	@"JPEGFactor"

static int suffixTagSV = Tag_jpg;
static int compFactor = JpegDefFactor;

@implementation JpegSavePanel

+ (void)initialize
{
	NSUserDefaults *usrdef = [NSUserDefaults standardUserDefaults];
	NSString *s = [usrdef stringForKey: JPEGFactor];
	compFactor = s ? [s intValue] : JpegDefFactor;
}

+ (NSString *)nameOfAccessory { return @"JpegAccessory.nib"; }

+ (void)setSuffix:(int)tag { suffixTagSV = tag; }

- (void)loadNib
{
	[super loadNib];
	[suffixButton selectCellWithTag:(suffixTag = suffixTagSV)];
	[self setFactor: compFactor];
}

- (void)setFactor:(int)factor
{
	if (factor > 100) factor = 100;
	else if (factor < 0) factor = 0;
	[JPEGtext setIntValue: factor];
	[JPEGslider setIntValue: factor];
}

- (int)compressFactor {
	compFactor = [JPEGtext intValue];
	return compFactor;
}

- (NSString *)suffix
{
	return (suffixTag == Tag_jpEg) ? @"jpeg" : @"jpg";
}

- (void)saveParameters
{
	[[NSUserDefaults standardUserDefaults]
		setInteger:[self compressFactor] forKey:JPEGFactor];
}

@end
