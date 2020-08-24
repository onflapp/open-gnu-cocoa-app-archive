//
//  RestoreWorkAreaPanelController.h
//  CVL
//
//  Created by William Swats on Mon Apr 05 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import "RestoreRetrieveController.h"

#import <AppKit/AppKit.h>

@class CVLFile;


@interface RestoreWorkAreaPanelController : RestoreRetrieveController
{
    NSString                *workAreaPath;
}

    /*" Class Methods "*/
+ sharedRestoreWorkAreaPanelController;

    /*" Action Methods "*/
- (IBAction)restoreWorkArea:(id)sender;

    /*" Other Methods "*/
- (void)restoreVersionForWorkArea:(NSString *)aPath;



@end
