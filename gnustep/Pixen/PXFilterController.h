//
//  PXFilterController.h
//  Pixen-XCode
//
//  Created by Ian Henderson on 20.09.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXFilterController : NSObject {
	NSMutableDictionary *filters;
	NSMutableArray *filterBundles;
	
	IBOutlet NSMenu *filterMenu;
}

@end
