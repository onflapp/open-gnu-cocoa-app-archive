//
//  PosterCtrl.m
//  ToyViewer
//
//  Created by Takeshi Ogihara on Tue Apr 30 2002.
//

#import "PosterCtrl.h"
#import <AppKit/NSControl.h>
#import "Posterizer.h"

@implementation PosterCtrl

- (void)posterize:(id)sender
{
	id she = [[Posterizer alloc] init];
	if (she == nil)
		return;
	[she setOption:[optionMenu selectedTag]];
	[she setDivFactor:[posterDiffSlider floatValue]
		andColorFactor:[posterCtrlSlider floatValue]];
	[she createNewImage];
	[she release];
}

@end
