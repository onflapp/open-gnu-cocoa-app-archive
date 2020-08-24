/* SenStringArrayBrowserController.h created by ja on Thu 21-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@interface SenStringArrayBrowserController : NSObject
{
    NSBrowser *browser;
    NSTextField *textField;
    NSMutableArray *value;
}

- (void) setStringArrayValue:(NSArray *)anArray;
- (NSArray *)stringArrayValue;
- (NSString *)selectedEntry;

- (void)moveUp:(id)sender;
- (void)moveDown:(id)sender;
- (void)newEntry:(id)sender;
- (void)removeEntry:(id)sender;

@end
