/* CvsReleaseRequest.m created by stephane on Fri 22-Oct-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsReleaseRequest.h"
#import <CvsRepository.h>
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>


@interface CvsReleaseRequest(Private)
- (void) setWorkAreaPath:(NSString *)aPath;
@end

@implementation CvsReleaseRequest

+ (CvsReleaseRequest *) cvsReleaseRequestWithPath:(NSString *)rootPath deleteWorkArea:(BOOL)flag handler:(id)aHandler
{
    CvsReleaseRequest	*aRequest;

    NSParameterAssert(rootPath != nil);
    NSParameterAssert(!aHandler || [aHandler respondsToSelector:@selector(request:releaseWorkAreaContainingModifiedFilesNumber:)]);
    
    aRequest = [[self alloc] initWithTitle:@"release"];
    [aRequest setWorkAreaPath:rootPath];
    aRequest->deleteWorkArea = flag;
    aRequest->handler = aHandler;

    return [aRequest autorelease];
}

- (id) init
{
    if ( (self = [super init]) ) {
        cmdTag = CVS_RELEASE_CMD_TAG;
    }

    return self;
}

- (void) dealloc
{
    RELEASE(workAreaPath);
    RELEASE(summedOutput);
    [cvsInput closeFile];
    RELEASE(cvsInput);

    [super dealloc];
}

- (void) setWorkAreaPath:(NSString *)aPath
{
    [workAreaPath autorelease];
    workAreaPath = [aPath copy];
    [self setRepository:[CvsRepository repositoryForPath:workAreaPath]];
}

- (NSString *) workAreaPath
{
    return workAreaPath;
}

- (BOOL) deleteWorkArea
{
    return deleteWorkArea;
}

- (NSString *) cvsWorkingDirectory
{
    // We must be in the parent directory of the work area directory
    return [workAreaPath stringByDeletingLastPathComponent];
}

- (NSArray *) cvsCommandOptions
{
    if(deleteWorkArea)
        return [NSArray arrayWithObject:@"-d"];
    else
        return [NSArray array];
}

- (NSArray *) cvsCommandArguments
{
    return [NSArray arrayWithObject:workAreaPath];
}

#ifndef JA_PATCH
- (BOOL) canContinue
{
    return [self precedingRequestsEnded];
}
#endif

- (NSString *) summary
{
    return @"cvs release";
}

- (NSString *) shortDescription
{
    return [NSString stringWithFormat:@"%@ %@%@\n", [self cmdTitle], (deleteWorkArea ? @"-d ":@""), workAreaPath];
}

- (BOOL) setUpTask
{
    if([super setUpTask]){
        NSPipe	*aPipe = [NSPipe pipe];

        cvsInput = [[aPipe fileHandleForWriting] retain];
        [task setStandardInput:aPipe];
        
        return YES;
    }
    return NO;
}

- (void) parseOutput:(NSString *)data
{
    NSString	*numberString, *answer = @"y";
    int			alteredFileNumber;
    
    if(!summedOutput)
        summedOutput = [[NSMutableString alloc] init];
    [summedOutput appendString:data];

    if(!cvsInput)
        return; // We already wrote to stdin
    
// M NeedsMergeFileName
//	You have [0] altered files in this repository.
//	Are you sure you want to release (and delete) directory `Special2': n

    numberString = [[summedOutput findAllSubPatternMatchesWithPattern:@".*You have \\[([0-9]*)\\].*\\n.*': $" options:AGRegexMultiline] lastObject];
    if(!numberString)
        return;
    
    alteredFileNumber = [numberString intValue];

    if(alteredFileNumber)
        if(handler && ![handler request:self releaseWorkAreaContainingModifiedFilesNumber:alteredFileNumber])
            answer = @"n";

    [cvsInput writeData:[[answer stringByAppendingString:RequestNewLineString] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
    [cvsInput closeFile];
    RELEASE(cvsInput);
}

- (void) parseError:(NSString *)data
{
    // cvs release: unable to release `/Network/Users/stephane/Tests/Special2'
    if([data hasPrefix:@"cvs release: unable to release"] || [data hasPrefix:@"ocvs release: unable to release"])
        failed = YES;
}

- (void) end
{
    [cvsInput closeFile];
    RELEASE(cvsInput);

    [super endWithoutInvalidation];
}

- (BOOL) succeeded
{
    return [super succeeded] && !failed;
}

@end
