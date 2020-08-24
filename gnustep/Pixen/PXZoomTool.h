//  PXZoomTool.h
//  Pixen
//
//  Created by Joe Osborn on Mon Oct 13 2003.
//  Copyright (c) 2003 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "PXTool.h"

typedef enum {
    PXZoomIn = 0,
    PXZoomOut
} PXZoomType;

@interface PXZoomTool : PXTool {
    PXZoomType zoomType;
}
//should implement 'drag to create rect and zoom to fit that rect'

@end
