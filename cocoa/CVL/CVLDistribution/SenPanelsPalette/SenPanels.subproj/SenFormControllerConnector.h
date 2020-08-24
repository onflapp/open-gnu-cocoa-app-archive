/* SenFormControllerConnector.h created by ja on Tue 24-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>
#import <InterfaceBuilder/InterfaceBuilder.h>

@interface SenFormControllerConnector : NSObject
{
    NSObject * source;
    NSObject * destination;
    NSString *label;
}
- (void)setSource:(NSObject *)newSource;
- (void)setDestination:(NSObject *)newDestination;
- (void)setLabel:(NSString *)newLabel;

@end

@interface SenFormControllerConnector (IBConnectors) <IBConnectors>
@end