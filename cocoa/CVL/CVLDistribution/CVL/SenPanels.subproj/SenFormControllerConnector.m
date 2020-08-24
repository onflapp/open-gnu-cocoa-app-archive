/* SenFormControllerConnector.m created by ja on Tue 24-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenFormControllerConnector.h"
#import "SenFormController.h"
#import <SenFoundation/SenFoundation.h>

@implementation SenFormControllerConnector
- (void) dealloc
{
    RELEASE(source);
    RELEASE(destination);
    RELEASE(label);
    [super dealloc];
}

- (id)source
{
    return source;
}

- (void)setSource:(NSObject *)newSource
{
    ASSIGN(source, newSource);
}

- (id)destination
{
    return destination;
}

- (void)setDestination:(NSObject *)newDestination
{
    ASSIGN(destination, newDestination);
}

- (NSString *)label
{
    return label;
}

- (void)setLabel:(NSString *)newLabel
{
    ASSIGN(label, newLabel);
}

- (void)replaceObject:(id)oldObject withObject:(id)newObject
{
    if (oldObject==source) {
        [self setSource:newObject];
    }
    if (oldObject==destination) {
        [self setDestination:newObject];
    }
}

- (void)establishConnection
{
    [[self source] setControl:[self destination] forKey:[self label]];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    int		version;

    self = [self init];

    version = [decoder versionForClassName:@"SenFormControllerConnector"];
    switch (version) {
    case 0:
        ASSIGN(source, [decoder decodeObject]);
        ASSIGN(destination, [decoder decodeObject]);
        ASSIGN(label, [decoder decodeObject]);
        
        break;
    default:
        break;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];

    // Version == 1
    [coder encodeObject:source];
    [coder encodeObject:destination];
    [coder encodeObject:label];
}

- (id)nibInstantiate
{
    return self;
}
@end
