/*
 *  rescale.h
 *  ToyViewer
 *
 *  Created by Takeshi OGIHARA on Sat Apr 20 2002.
 *  Copyright (c) 2001 Takeshi OGIHARA. All rights reserved.
 *
 */

#import <Foundation/NSGeometry.h>

NSSize calcSizeRound(NSSize sz, float factor);
NSSize calcSize(NSSize sz, float factor);
void calcWidthAndHeight(int *newwd, int *newhg, int wd, int hg, float scale);

