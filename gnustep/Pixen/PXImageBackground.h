//
//  PXImageBackground.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Oct 28 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import "PXMonotoneBackground.h"

@interface PXImageBackground : PXMonotoneBackground {
    id image;
    IBOutlet id imageNameField, browseButton;
}
- (IBAction)configuratorBrowseForImageButtonClicked:sender;
- (void)setImage:anImage;

@end
