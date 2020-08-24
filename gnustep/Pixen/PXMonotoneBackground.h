//
//  PXMonotoneBackground.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Sun Oct 26 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "PXBackground.h"

@interface PXMonotoneBackground : PXBackground {
    NSColor * color;
    IBOutlet NSColorWell * colorWell;
}
- (IBAction)configuratorColorChanged:sender;
- (void)setColor:aColor;
@end
