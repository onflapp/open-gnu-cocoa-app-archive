//
//  SFAqua.h
//  ToyViewer
//
//  Created on Sun Jun 23 2002.
//  Copyright (c) 2002 OGIHARA Takeshi. All rights reserved.
//

#import "SoftFramer.h"

@interface SFAqua : SoftFramer
{
	int	buttonColor[MAXPLANE];
	int	modelid;
	const unsigned char *aq_model;
	const unsigned char *aq_in;
	const unsigned char *aq_hl;
}

+ (void)initialize;
- (void)setButtonColor:(int *)clr;
- (BOOL)isTooLarge;
- (BOOL)isColorImageMade;
- (commonInfo *)makeNewInfo;
- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;

@end
