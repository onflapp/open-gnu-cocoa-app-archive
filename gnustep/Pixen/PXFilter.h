//
//  PXFilter.h
//  Pixen-XCode
//
//  Created by Ian Henderson on 20.09.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@class PXCanvas;

@protocol PXFilter

- (NSString *)name;
- (void)applyToCanvas:(PXCanvas *)canvas;

@end
