//
//  PXCanvasPrintView.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Tue Jul 13 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXCanvasPrintView : NSView {
	id canvas;
}
+ viewForCanvas:aCanvas;
- initWithCanvas:aCanvas;
@end
