#import "ToyWinPict.h"
#import <AppKit/NSImage.h>
#import <AppKit/NSImageRep.h>
#import <AppKit/NSPICTImageRep.h>
#import <AppKit/NSBitmapImageRep.h>
#import <Foundation/NSData.h>
#import <stdio.h>
//#import <libc.h>
#import <string.h>
#import "ToyView.h"
#import "common.h"

@implementation ToyWinPict

/* Overload */
- (NSData *)openEPSData
{
	id	tv = [self toyView];
	return [tv dataWithEPSInsideRect:[tv frame]];
}

/* Overload */
- (void)makeComment:(commonInfo *)cinf
{
	sprintf(cinf->memo, "%d x %d  pict", cinf->width, cinf->height);
}

@end
