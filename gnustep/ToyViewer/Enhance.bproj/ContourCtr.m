//
//  ContourCtr.m
//  ToyViewer
//
//  Created by Takeshi OGIHARA on Sun May 19 2002.
//  Copyright (c) 2001 Takeshi OGIHARA. All rights reserved.
//

#import "ContourCtr.h"
#import  <AppKit/AppKit.h>
#import  <Foundation/NSString.h>
#import "../BundleLoader.h"
#import "Embosser.h"
#import "Contourer.h"


@implementation ContourCtr

/* Local Method */
- (void)doitWith:(id)she
{
	float a = [enhanceSlider floatValue];
	float b = [colorSlider floatValue];
	[she setFactor:a andBright:b];
	[she createNewImage];
}

- (void)contour:(id)sender
{

	id she = [[Contourer alloc] init];
	if (she == nil)
		return;
	[she setContrast:[contourSlider floatValue]];
	[self doitWith: she];
	[she release];
}

- (void)emboss:(id)sender	/* Emboss & Contour */
{
	id she = [[Embosser alloc] init];
	if (she == nil)
		return;
	[she setEmbossDirection:[embossSwitch selectedTag]];
	[self doitWith: she];
	[she release];
}

@end
