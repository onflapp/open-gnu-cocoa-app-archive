//
//  PXPoint.h
//  Pixen-XCode
//
//  Created by Joe Osborn on 2004.08.08.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PXPoint : NSObject {
	NSPoint point;
}
+ withNSPoint:(NSPoint)aPoint;
- initWithNSPoint:(NSPoint)aPoint;
- (NSPoint)pointValue;
- (unsigned)hash;
- (BOOL)isEqual:other;
@end
