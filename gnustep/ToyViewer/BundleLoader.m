#import "BundleLoader.h"
#import <Foundation/NSString.h>
#import <Foundation/NSBundle.h>

struct _load_tab {
	NSString	*resource;
	NSString	*classname;
};
static struct _load_tab loadtab[BundleNum] = {
	{ @"ImageOpr",	@"ImageOpr" },
	{ @"Reduction",	@"ImageReduce" },
	{ @"Resize",	@"ImageResize" },
	{ @"Resize",	@"Thumbnailer" },
	{ @"BackgCtr",	@"BackgCtr" },
	{ @"ADController", @"ADController" },
	{ @"ImageSave",	@"ImageSave" },

	{ @"ColorTune",	@"TonePanelCtrl" },
	{ @"Enhance",	@"EnhanceCtr" },
	{ @"ColorChange", @"ColorChangeCtr" },
	{ @"Noise",	@"NoiseCtr" },
	{ @"SoftFrame",	@"SoftFrameCtr" },
	{ @"Posterize",	@"PosterCtrl" },
};
static Class	classObj[BundleNum];

@implementation BundleLoader

+ (Class)loadClass:(int)classid
{
	NSBundle *bundle;
	NSString *path;

	if (classObj[classid])
		return classObj[classid];
	NSLog(@"Bundle %i",classid);
	/* Load "???.bundle" */
	bundle = [NSBundle mainBundle];
	path = [bundle pathForResource:loadtab[classid].resource
			ofType:@"bundle"];
	bundle = [NSBundle bundleWithPath: path];
	if (bundle == nil) /* ERROR */
		return nil;
	classObj[classid] = [bundle classNamed:loadtab[classid].classname];
	return classObj[classid];
}

+ (id)loadAndNew:(int)classid
{
  NSLog(@"====> load AND NEW %@",[[[self loadClass:classid] alloc] init]);
	return [[[self loadClass:classid] alloc] init];
}

@end
