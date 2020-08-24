/* CVLWaitController.h created by stephane on Thu 21-Oct-1999 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@class NSPanel;
@class NSProgressIndicator;
@class NSButton;
@class NSTextField;
@class NSTimer;

extern NSString	*CVLWaitConditionMetNotification;


@interface CVLWaitController : NSObject
{
    IBOutlet NSPanel				*waitPanel;
    IBOutlet NSProgressIndicator	*progressIndicator;
    IBOutlet NSButton				*cancelButton;
    IBOutlet NSTextField			*messageTextField;
    BOOL							waitCancelled;
    BOOL							cancellable;
    BOOL                            isPanelDisplayed;
    id								(target);
    SEL								selector;
    NSDictionary                    *userInfo;
    NSTimeInterval					granularity;
    NSTimer							*timer;
    NSString						*waitMessage;
    NSTimeInterval					displayThresholdDelay;
}

+ (void) setGranularity:(NSTimeInterval)granularity;
+ (NSTimeInterval) granularity;

+ (void) setDisplayThresholdDelay:(NSTimeInterval)aDelay;
+ (NSTimeInterval) displayThresholdDelay;

+ (CVLWaitController *) waitForConditionTarget:(id)aTarget selector:(SEL)aSelector cancellable:(BOOL)canBeCancelled userInfo:(NSDictionary *)aUserInfo;
// Will wait until target returns non nil value when performing selector

- (void) setWaitMessage:(NSString *)aMessage;

- (IBAction) cancelWaiting:(id)sender;
- (BOOL) waitCancelled;

- (NSDictionary *)userInfo;
- (void)setUserInfo:(NSDictionary *)newUserInfo;

@end
