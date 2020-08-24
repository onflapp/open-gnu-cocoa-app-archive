//
//  PosterCtrl.h
//  ToyViewer
//
//  Created by Takeshi Ogihara on Tue Apr 30 2002.
//

#import "../ImgToolCtrlAbs.h"

@interface PosterCtrl : ImgToolCtrlAbs
{
	id	posterDiffSlider;
	id	posterCtrlSlider;
	id	optionMenu;
}

- (void)posterize:(id)sender;

@end
