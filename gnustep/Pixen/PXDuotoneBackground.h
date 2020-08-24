//
//  PXDuotoneBackground.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Oct 28 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXMonotoneBackground.h"

@interface PXDuotoneBackground : PXMonotoneBackground {
    NSColor * backColor;
    IBOutlet NSColorWell * backWell;
}

- (IBAction)configuratorBackColorChanged:sender;
- (void)setBackColor:aColor;

@end
