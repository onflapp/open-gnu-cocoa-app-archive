//
//  PXPattern.h
//  Pixen-XCode
//
//  Created by Ian Henderson on 07.10.04.
//  Copyright 2004 Open Sword Group. All rights reserved.
//

#import "PXCanvas.h"

@interface PXPattern : PXCanvas {

}

- (NSArray *)pointsInPattern;
- (void)addPoint:(NSPoint)point;
- (void)addPoints:(NSArray *)points;

@end
