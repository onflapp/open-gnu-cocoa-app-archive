/*$Id: SenOysterShell.h,v 1.3 2001/03/29 08:25:31 stephane Exp $*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/NSObject.h>

@class NSNumber;
@class NSString;
@class NSArray;
@class NSDictionary;

extern NSString *SenOysterEvaluationFailedException;

@interface SenOysterShell:NSObject
{
    @private
    void *_perl;
}

+ (SenOysterShell *) sharedOyster;
+ (SenOysterShell *) oyster;
@end


@interface SenOysterShell (Evaluation)
- (void) eval:(NSString *) command;
@end


@interface SenOysterShell (ScalarVariables)
- (NSString *) stringWithName:(NSString *) name;
- (void) setString:(NSString *) value forName:(NSString *) name;

- (int) intWithName:(NSString *) name;
- (void) setIntValue:(int) value forName:(NSString *) name;

- (double) doubleWithName:(NSString *) name;
- (void) setDoubleValue:(double) value forName:(NSString *) name;

- (NSNumber *) numberWithName:(NSString *) name;
@end


@interface SenOysterShell (ArrayVariables)
- (NSArray *) arrayWithName:(NSString *) name;
//- (void) setArray:(NSArray *) value forName:(NSString *) name;
@end


@interface SenOysterShell (DictionaryVariables)
//- (NSDictionary *) dictionaryWithName:(NSString *) name;
//- (void) setDictionary:(NSDictionary *) value forName:(NSString *) name;
@end


@interface SenOysterShell (ObjectVariables)
//- (id) objectWithName:(NSString *) name;
// Returns NSNumber, NSArray,  NSDictionary, NSString
@end
