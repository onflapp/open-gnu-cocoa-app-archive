/* CVLScheduler.h created by vincent on Tue 25-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>


@class NSMutableArray;
@class NSMutableSet;
@class Request;


@interface CVLScheduler : NSObject
{
  NSMutableArray *pendingRequests;
  NSMutableSet *runningRequests;
  NSMutableSet *requests;
  NSMapTable	*timers;
  int order;
}

+ sharedScheduler;

- (void) scheduleRequest: (Request*) aRequest;
- (int)requestCount;
- (int)requestCountForPath: (NSString*)aPath;
@end
