#import  "EnhanceCtr.h"
#import  <AppKit/AppKit.h>
#import  <Foundation/NSString.h>
#import  "Enhancer.h"
#import  "Blurrer.h"

@implementation EnhanceCtr

- (void)enhance:(id)sender
{
	id she = [[Enhancer alloc] init];
	if (she == nil)
		return;
	[she setFactor: [enhanceSlider floatValue]];
	[she setOutside:[whichside selectedTag]];
	[she createNewImage];
	[she release];
}

- (void)blur:(id)sender
{
	id she = [[Blurrer alloc] init];
	if (she == nil)
		return;
	[she setFactor: [blurSlider floatValue]];
	[she setOutside:[whichside selectedTag]];
	[she createNewImage];
	[she release];
}

- (id)contourCtrl { return contourCtrl; }

@end
