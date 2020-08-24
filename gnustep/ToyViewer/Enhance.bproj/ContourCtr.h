//
//  ContourCtr.h
//  ToyViewer
//
//  Created by Takeshi OGIHARA on Sun May 19 2002.
//  Copyright (c) 2001 Takeshi OGIHARA. All rights reserved.
//

#import "../ImgToolCtrlAbs.h"

@interface ContourCtr : ImgToolCtrlAbs
{
	id	enhanceSlider;
	id	colorSlider;
	id	contourSlider;
	id	embossSwitch;
}

- (void)contour:(id)sender;
- (void)emboss:(id)sender;

@end
