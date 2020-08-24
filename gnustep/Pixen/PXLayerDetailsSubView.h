//
//  PXLayerDetailsSubView.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Thu Aug 05 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXLayerDetailsSubView : NSView {
	id layer;
}

- (void)setLayer:aLayer;

@end
