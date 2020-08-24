//
//  PXScaleAlgorithm.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Thu Jun 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@class PXCanvas, PXLayer;

@interface PXScaleAlgorithm : NSObject {
	IBOutlet NSView *parameterView;
}

+ algorithm;

- (NSString *)name;
- (NSString *)nibName;
- (NSString *)algorithmInfo;

- (BOOL)hasParameterView;
- (NSView *)parameterView;

- (BOOL)canScaleCanvas:canvas toSize:(NSSize)size;
- (void)scaleCanvas:canvas toSize:(NSSize)size;

@end
