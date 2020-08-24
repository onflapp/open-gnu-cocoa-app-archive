/* CvsInitRequest.m created by stephane on Mon 06-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsInitRequest.h"

#import "CvsRepository.h"

#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>


@interface CvsInitRequest(Private)
- (void) setNewRepositoryPath:(NSString *)aPath;
@end

@implementation CvsInitRequest

// There is no output to parse

+ (CvsInitRequest *) cvsInitRequestWithPath:(NSString *)initPath
{
    CvsInitRequest	*aRequest = [[self alloc] initWithTitle:@"init"];

    NSParameterAssert(initPath != nil);
    // Stephane: we should also check that path is absolute
    // Path may include computer name, like "hnw:/Local/Repository"
    [aRequest setNewRepositoryPath:initPath];
    
    return [aRequest autorelease];
}

- (id) init
{
    if ( (self = [super init]) ) {
        cmdTag = CVS_INIT_CMD_TAG;
    }

    return self;
}

- (void) dealloc
{
    RELEASE(newRepositoryPath);

    [super dealloc];
}

- (void) setNewRepositoryPath:(NSString *)aPath
{
    [newRepositoryPath autorelease];
    newRepositoryPath = [aPath copy];
}

- (NSString *) newRepositoryPath
{
    return newRepositoryPath;
}

- (NSArray *) cvsOptions
{
    return [NSArray arrayWithObjects:@"-d", newRepositoryPath, nil];
}

- (NSArray *) cvsCommandOptions
{
    return [NSArray array];
}

- (NSArray *) cvsCommandArguments
{
    return [NSArray array];
}

#ifdef JA_PATCH
- (void)endWithSuccess;
{
}

- (void)endWithFailure;
{
}
#else
- (BOOL) canContinue
{
    return [self precedingRequestsEnded];
}

- (void) end
{
    [self endWithoutInvalidation];
}
#endif

- (NSString *) summary
{
    return @"cvs init";
}

- (NSString *) shortDescription
{
    return [NSString stringWithFormat:@"%@ %@\n", [self cmdTitle], newRepositoryPath];
}

- (NSDictionary *) result
{
    if(newRepositoryPath)
        return [NSDictionary dictionaryWithObjectsAndKeys:newRepositoryPath, PATH_KEY, @"local", METHOD_KEY, nil];
    else
        return [NSDictionary dictionary];
}

@end
