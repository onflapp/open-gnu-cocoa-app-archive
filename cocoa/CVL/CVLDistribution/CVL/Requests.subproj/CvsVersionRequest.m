/* CvsVersionRequest.m created by stephane on Thu 02-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsVersionRequest.h"
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>


@implementation CvsVersionRequest

+ (CvsVersionRequest *) cvsVersionRequest
{
    CvsVersionRequest	*aRequest = [[self alloc] initWithTitle:@"version"];

    return [aRequest autorelease];
}

- (id) init
{
	if ( (self = [super init]) )
        cmdTag = CVS_VERSION_TAG;

    return self;
}

- (void) dealloc
{
    RELEASE(result);
    
    [super dealloc];
}

- (NSArray *) cvsOptions
{
    return [NSArray arrayWithObject:@"--version"];
}

- (NSString *) cvsCommand
{
    // We must reimplement method like this: it is used to build task; there is no command for cvs --version, only one cvs option
    return nil;
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

- (unsigned int) cmdTag
{
    return CVS_VERSION_TAG;
}

- (NSString *) summary
{
    return @"cvs version";
}

- (NSString *) shortDescription
{
    return [[self cmdTitle] stringByAppendingString:@"\n"];
}

- (void) parseOutput:(NSString *)data
{
    if(!result)
        result = [[NSMutableDictionary allocWithZone:[self zone]] initWithObjectsAndKeys:[[data copyWithZone:[self zone]] autorelease], @"version", nil];
    else
        [result setObject:[[result objectForKey:@"version"] stringByAppendingString:data] forKey:@"version"];
}

- (void) parseError:(NSString *)data
{
    [self parseOutput: data];
    [super parseError:data];
}

- (NSDictionary *) result
{
    return result;
}

@end
