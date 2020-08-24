/* CvsVerboseStatusRequest.m created by vincent on Fri 22-May-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsVerboseStatusRequest.h"
#import "CvsStatusRequest.h"
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>
#import <CvsTag.h>


@implementation CvsVerboseStatusRequest
+ (CvsVerboseStatusRequest *)cvsVerboseStatusRequestForFiles:(NSArray *)someFiles inPath:(NSString *)aPath
{
    return [self requestWithCmd:CVS_GET_TAGS_CMD_TAG title:@"get tags" path:aPath files:someFiles];
}

- (void)dealloc
{
    RELEASE(parsingBuffer);
    RELEASE(result);
    RELEASE(tagsPath);

    [super dealloc];
}

- (NSString*) cvsCommand
{
    return @"status";
}

- (NSArray *)cvsCommandOptions
{
    return [NSArray arrayWithObject: @"-lv"];
}

- (NSArray *)cvsCommandArguments
{
    return [self files];
}

- (NSString *)cvsWorkingDirectory
{
    return [self path];
}

-(NSDictionary *)result
{
  return result;
}

- (void)initResult
{
    result=[[NSMutableDictionary alloc] init];
}

- (BOOL)setUpTask
{
#ifdef JA_PATCH
    if (!result) {
        [self initResult];
    }

    if ([super setUpTask]) {
        parsingBuffer=[[NSMutableString alloc] init];

        return YES;
    } else {
        return NO;
    }
#else
    if ([super setUpTask]) {

        parsingBuffer=[[NSMutableString alloc] init];

        if (!result) {
            [self initResult];
        }
        return YES;
    } else {
        return NO;
    }
#endif
}

- (void) readTagsFrom: (NSString*) aString
  // scan 'aString' and update tags info, if any
{
    NSAutoreleasePool *subpool = [[NSAutoreleasePool alloc] init];
    NSMutableDictionary* resultDict = nil;
    NSArray* matchArray = [aString splitStringWithPattern:CvsExistingTagsPattern 
                                                  options:0];
    if ([matchArray count] == 2)
    {
        NSString* infoPart= [matchArray objectAtIndex: 0];
        NSString* tagsPart= [matchArray objectAtIndex: 1];
        NSArray* linesArray;
        int i= 0;

        matchArray = [infoPart findAllSubPatternMatchesWithPattern:CvsStatusFilePattern
                                                           options:0];
        if ([matchArray count] > 0)
        { 		// assign after removing trailing spaces
            NSString* aMatchedObject = [matchArray objectAtIndex: 1];
            NSString* aFilename = [aMatchedObject replaceMatchesOfPattern:CvsLeadingWhiteSpacePattern 
                                                               withString:@"" 
                                                                  options:AGRegexMultiline];

            ASSIGN(tagsPath, [[self path] stringByAppendingPathComponent: aFilename]);
            resultDict = [result objectForKey: tagsPath];
            if ( resultDict == nil )
            {
                resultDict=[NSMutableDictionary dictionary];
                [result setObject:resultDict forKey: tagsPath];
            }            
        }

        linesArray = [tagsPart splitStringWithPattern:CvsRequestNewLinePattern 
                                              options:0];
        i= [linesArray count];

        while (i--)
        {
            NSString* line= [linesArray objectAtIndex: i];

            matchArray = [line findAllSubPatternMatchesWithPattern:CvsTagsPattern
                                                           options:0];
            if ([matchArray count] >= 3)
            { // all infos are present, set them into dictionary
                NSMutableArray* newArray= [NSMutableArray arrayWithCapacity: 0];
                CvsTag *aCvsTag = [[CvsTag alloc] init];

                NSString* aMatchedObject= [matchArray objectAtIndex: 0];
                NSString* currentTag = [aMatchedObject 
                                        replaceMatchesOfPattern:CvsLeadingWhiteSpacePattern 
                                                     withString:@"" 
                                                        options:AGRegexMultiline];
                NSString* tagKind= [matchArray objectAtIndex: 1];
                NSString* revision= [matchArray objectAtIndex: 2];

                [aCvsTag setTagTitle:currentTag];
                if ( [tagKind isEqualToString:@"branch"] ) {
                    [aCvsTag setIsABranchTag:YES];
                } else {
                    [aCvsTag setIsABranchTag:NO];
                }
                [aCvsTag setTagRevision:revision];

                [newArray addObjectsFromArray: [resultDict objectForKey: @"TagsKey"]];
                [newArray addObject:aCvsTag];
                [resultDict setObject: newArray forKey: @"TagsKey"];
            }
        }
    }
    [subpool release];
} // readTagsFrom:

- (void)parseOutput:(NSString *)data
{
    NSRange sentinelRange;
    NSArray* results= nil;
    int rCount= 0;
    int j= 0;

    [parsingBuffer appendString: data];
    // sentinel to avoid deleting last split pettern
    sentinelRange.length= 2;
    [parsingBuffer appendString: @"xx"];

    // split sur ==== ou sur ---
    results = [parsingBuffer splitStringWithPattern:CvsRequestLineOfEqualsOrMinusPattern
                                            options:0];
    rCount= [results count];
    j= 0;
    for (j= 0; j< rCount-1; j++)
    {	// give all results to the reader
        NSString* aResult= [results objectAtIndex: j];
        if ([aResult length] > .0)
        {
            [self readTagsFrom: aResult];
        }
    }
    [parsingBuffer setString: [results objectAtIndex: rCount -1]];
    sentinelRange.location= [parsingBuffer length] -  sentinelRange.length;
    [parsingBuffer deleteCharactersInRange: sentinelRange];
} //

#ifdef JA_PATCH
- (void)flushBuffers
{
    [self readTagsFrom: parsingBuffer];
    RELEASE(parsingBuffer);
}

- (void)endWithSuccess;
{
    [self flushBuffers];
}

- (void)endWithFailure;
{
    [self flushBuffers];
}
#else
- (void)end
{
    [self readTagsFrom: parsingBuffer];
    RELEASE(parsingBuffer);

    if (!result) {
        [self initResult];
    }
    [super endWithoutInvalidation];
}
#endif

@end

