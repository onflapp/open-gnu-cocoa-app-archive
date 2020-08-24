//
//  Thumbnailer.h
//  ToyViewer
//
//  Created by OGIHARA Takeshi on Tue Jan 29 2002.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import "../common.h"
#import "../ToyWin.h"

@interface Thumbnailer : NSObject {
	NSSize		targetSize;
	ToyWin		*toywin;
	commonInfo	*info, *_newinfo;
	float		factor;
	unsigned char	*_bitmap;
}

- (id)initWithToyWin:(ToyWin *)tw;
- (void)dealloc;
- (commonInfo *)makeThumbnail:(unsigned char **)bitmap;

@end
