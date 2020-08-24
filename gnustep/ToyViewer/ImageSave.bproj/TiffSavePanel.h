#import  "TVSavePanel.h"

@class NSString;

@interface TiffSavePanel : TVSavePanel
{
	id	compButton;
}

+ (NSString *)nameOfAccessory;
- (void)loadNib;
- (int)compressType;
/* Over write */
- (NSString *)suffix;

@end
