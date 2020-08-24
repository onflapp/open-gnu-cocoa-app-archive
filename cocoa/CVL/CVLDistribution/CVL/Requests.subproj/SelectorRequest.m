/* SelectorRequest.m created by stephane on Mon 31-Jan-2000 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SelectorRequest.h"
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>


@implementation SelectorRequest

+ (id) requestWithTarget:(id)aTarget selector:(SEL)aSelector argument:(id)anArgument
{
    SelectorRequest	*aRequest = [[self alloc] initWithTitle:NSStringFromSelector(aSelector)];

    aRequest->selector = aSelector;
    aRequest->target = [aTarget retain];
    aRequest->argument = [anArgument retain];
    [aRequest setCanBeCancelled:NO]; // Default is NO.
    
    return aRequest;
}

- (void) dealloc
{
    RELEASE(target);
    RELEASE(argument);
    
    [super dealloc];
}

#ifndef JA_PATCH
- (void) start
{    
    [super start];

    if(!selector || !target || ![target respondsToSelector:selector]){
        [self cancel];
        return;
    }
    
    NS_DURING{
        [target performSelector:selector withObject:argument];
        success = YES;
    }
    NS_HANDLER{
        NSLog(@"anException = %@",localException);
        success = NO;
    }
	NS_ENDHANDLER

    if(success)
        [self end];
}
#endif

- (BOOL) canBeCancelled
{
    return canBeCancelled;
}

- (void)setCanBeCancelled:(BOOL)aState
{
    canBeCancelled = aState;
}

- (NSMutableDictionary *)descriptionDictionary
    /*" This method returns a description of this instance in the form of a 
        dictionary. The keys are the names of the instance variables and the 
        values are the values of those instance variables. The keys return here 
        the keys from super's implementation plus selector, target and  argument.

        See also #{descriptionDictionary} in superclass Request.
    "*/
{
    NSMutableDictionary* dict = nil;
    
    dict = [super descriptionDictionary];
    [dict setObject: NSStringFromSelector(selector) forKey: @"selector"];
    [dict setObject: target forKey: @"target"];
    [dict setObject: argument forKey: @"argument"];
    
    return dict;
}


@end
