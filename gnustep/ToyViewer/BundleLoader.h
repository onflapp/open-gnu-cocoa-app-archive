#import <AppKit/NSApplication.h>

#define  BundleNum	13
enum {
	b_ImageOpr,
	b_Reduction,
	b_Resize,
	b_Thumbnail,
	b_BackgCtr,
	b_ADController,
	b_ImageSave,

	bt_ColorTune,
	bt_Enhance,
	bt_ColorChange,
	bt_Noise,
	bt_SoftFrame,
	bt_Posterize
};

@interface BundleLoader:NSObject

+ (Class)loadClass:(int)classid;
+ (id)loadAndNew:(int)classid;

@end

