#import  "ReduceCtr.h"
#import  <AppKit/NSControl.h>
#import  <AppKit/NSButton.h>
#import  "../common.h"
#import  "../BundleLoader.h"
#import  "../ImageOpCtr.h"
#import  "../Reduction.bproj/ImageReduce.h"

/* Note: [ImageOpCtr loadBundle] and [ImageOpCtr loadNib:] have already
    called by "activateToolPanel:".
 */

@implementation ReduceCtr

- (void)reduceSelect:sender
{
	id reduce;

	reduce = [BundleLoader loadAndNew: b_Reduction];
	[reduce reduceTo: [mcaColors selectedTag]
		withFS:[withDitherSW state] fourBit:[fourBitSW state]];
	[reduce release];
}

- (void)reduceFixedPalette:sender
{
	id reduce;

	reduce = [BundleLoader loadAndNew: b_Reduction];
	[reduce reduceWithFixedPalette:[fixedColors selectedTag]];
	[reduce release];
}

- (void)truncateBits:sender
{
	id reduce;

	reduce = [BundleLoader loadAndNew: b_Reduction];
	[reduce cutDownBitsTo:[cutdownBits selectedTag]]; 
	[reduce release];
}

- (void)colorHalftone:sender
{
	id reduce;

	reduce = [BundleLoader loadAndNew: b_Reduction];
	[reduce colorHalftoneWith: [psudoColors selectedTag]
		method:[psudoMethod selectedTag]]; 
	[reduce release];
}

@end
