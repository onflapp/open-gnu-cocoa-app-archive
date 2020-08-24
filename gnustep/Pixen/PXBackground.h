//
//  PXBackground.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Mon Oct 27 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXBackground : NSObject <NSCoding, NSCopying> {
    IBOutlet NSView * configurator;
    id name;
}
- defaultName;
- (NSString *)name;
- (void)setName:aName;
- (void)setConfiguratorEnabled:(BOOL)enabled;
- (NSView *)configurator;
- (NSString *)nibName;
- (void)changed;
- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect;
- (void)drawRect:(NSRect)rect withinRect:(NSRect)wholeRect withTransform:aTransform onCanvas:aCanvas;
@end
