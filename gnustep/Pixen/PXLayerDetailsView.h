//
//  PXLayerDetailsView.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Thu Feb 05 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//
#import <AppKit/AppKit.h>

@interface PXLayerDetailsView : NSView {
	IBOutlet id name;
	IBOutlet id thumbnail;
	IBOutlet id opacity;
	IBOutlet id opacityField;
	IBOutlet id opacityText;
	IBOutlet id view;
	id image;
	id timer;
	id layer;
	IBOutlet id visibility;
	BOOL isHidden; //for backwards compatibility with 10.2
	NSRect changedRect;
#ifndef __COCOA__
   id window;
#endif

}
- opacityText;
- initWithLayer:aLayer;
- (void)setLayer:aLayer;
- (void)invalidateTimer;
- (void)updatePreview:notification;
- (IBAction)opacityDidChange:sender;
- (IBAction)nameDidChange:sender;
- (IBAction)visibilityDidChange:sender;
- (BOOL)isHidden;
- (void)setHidden:(BOOL)shouldHide;
@end
