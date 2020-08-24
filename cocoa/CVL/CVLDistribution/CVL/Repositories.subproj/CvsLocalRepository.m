/* CvsLocalRepository.m created by ja on Thu 26-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsLocalRepository.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <AGRegex/AGRegexes.h>


@implementation CvsLocalRepository
+ (NSString *)rootForProperties:(NSDictionary *)properties
{
    NSString *repositoryPath;

    repositoryPath=[properties objectForKey:PATH_KEY];
    if (repositoryPath) {
        if ([repositoryPath rangeOfString:@":"].length==0) { // does it contains ':' ?
            return repositoryPath;
        } else {
            return [@":local:" stringByAppendingString:repositoryPath];
        }
    } else {
        return nil;
    }
}

- initWithMethod:(NSString *)theMethod root:(NSString *)repositoryRoot
{
    if ( (self=[super initWithMethod:theMethod root:repositoryRoot]) ) {
        NSString *theRepositoryPath=nil;
        if ([repositoryRoot rangeOfString:@":"].length==1) { // :method: format
            NSArray *matchingResult=[repositoryRoot findAllSubPatternMatchesWithPattern:@"^:local:(.+)$" options:AGRegexMultiline];
            if ([matchingResult count]!=1) {
                NSRunAlertPanel(@"Cvs Repository Problem", 
                    @"The repository root string \"%@\" is invalid. We will ignore this repository.",
                    nil, nil, nil, repositoryRoot);
                [self release];
                return nil;
            }
            theRepositoryPath=[matchingResult objectAtIndex:0];
        } else {
            theRepositoryPath=repositoryRoot;
        }
        path=[theRepositoryPath retain];
    }
    return self;
}

- initWithProperties:(NSDictionary *)properties
{
    NSString *theMethod,*theRepositoryPath;

    theMethod=[properties objectForKey:METHOD_KEY];
    theRepositoryPath=[properties objectForKey:PATH_KEY];

    if ( (self=[super initWithMethod:theMethod root:[[self class] rootForProperties:properties]]) ) {
        path=[theRepositoryPath retain];
    }
    return self;
}

- (BOOL)isLocal
{
    return YES;
}

- (NSDictionary *)properties
{
    return [NSDictionary dictionaryWithObjectsAndKeys:method,METHOD_KEY,path,PATH_KEY,nil];
}


@end
