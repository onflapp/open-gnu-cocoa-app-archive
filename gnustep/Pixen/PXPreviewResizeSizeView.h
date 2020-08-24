//
//  PXPreviewResizeSizeView.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Fri Jul 16 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXPreviewResizeSizeView : NSView {
	NSAttributedString *scaleString;
#ifdef __COCOA__
	NSShadow *shadow;
#endif
}

- (void)updateScale:(float)scale;
- (NSSize)scaleStringSize;

@end
