#import  "TVSavePanel.h"

@class NSString;

@interface JpegSavePanel : TVSavePanel
{
	id	JPEGslider;
	id	JPEGtext;
}

+ (void)initialize;
+ (NSString *)nameOfAccessory;
+ (void)setSuffix:(int)tag;

- (void)loadNib;
- (void)setFactor:(int)factor;
- (int)compressFactor;
- (NSString *)suffix;
- (void)saveParameters;

@end
