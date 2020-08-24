/*
 *  rescale.m
 *  Created by Takeshi OGIHARA on Sat Apr 20 2002.
 */

#import <objc/objc.h>
#import "common.h"
#import "rescale.h"

NSSize calcSizeRound(NSSize sz, float factor)
{
	int wd = (int)(sz.width * factor + 0.5);
	int ht = (int)(sz.height * factor + 0.5);
	if (wd > MAXWidth || ht > MAXWidth || wd < 4 || ht < 4)
		return NSZeroSize;
	return NSMakeSize((float)wd, (float)ht);
}

NSSize calcSize(NSSize sz, float factor)
{
	int wd = (int)(sz.width * factor);
	int ht = (int)(sz.height * factor);
	if (wd > MAXWidth || ht > MAXWidth || wd < 4 || ht < 4)
		return NSZeroSize;
	return NSMakeSize((float)wd, (float)ht);
}

void calcWidthAndHeight(int *newwd, int *newhg, int wd, int hg, float scale)
{
	*newwd = wd * scale;
	*newhg = hg * scale;
}
