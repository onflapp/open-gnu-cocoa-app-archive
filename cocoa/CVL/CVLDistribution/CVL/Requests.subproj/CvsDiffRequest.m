/* CvsDiffRequest.m created by vincent on Mon 08-Dec-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsDiffRequest.h"
#import "ResultsRepository.h"
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>

#define CVS_DIFF_KEYWORD	@"diff"


NSString* CvsDiffRequestFilenamePattern= @"(cvs diff: Diffing)|(Index:)\\s+(.*)\\n"; // FIXME Unused
NSString* CvsDiffPathPattern= @"diff\\s.*\\-r[\\w\\.]+\\s(.+)\\n";

static NSString	*rcsdiffOptions = nil;


@interface CvsDiffRequest (Private)
- (void)initResult;
+ (void)preferencesChanged:(NSNotification *)notification;
@end

@implementation CvsDiffRequest

+ (void) initialize
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesChanged:) name:@"PreferencesChanged" object:nil];
    [self preferencesChanged:nil];
}

+ (void)preferencesChanged:(NSNotification *)notification
{
    ASSIGN(rcsdiffOptions, [[NSUserDefaults standardUserDefaults] stringForKey:@"rcsdiffOptions"]);
}

- (void) setContext:(unsigned)contextLineNumber
{
    context = contextLineNumber;
}

- (void) setOutputFormat:(CVLDiffOutputFormat)newOutputFormat
{
    outputFormat = newOutputFormat;
}

+ (CvsDiffRequest*) cvsDiffRequestAtPath:(NSString *)aPath files:(NSArray *)someFiles context:(unsigned)contextLineNumber outputFormat:(CVLDiffOutputFormat)newOutputFormat
{
    NSArray *checkedFiles=nil;
    NSDictionary* pathDict;
    NSString* commonPath;
    CvsDiffRequest	*request;

    if (someFiles) {
        pathDict=[[self class] canonicalizePath: aPath andFiles: someFiles];
        commonPath= [[pathDict allKeys] objectAtIndex: 0];
        checkedFiles= [pathDict objectForKey: commonPath];
    } else {
        commonPath=aPath;
    }

    request = (CvsDiffRequest*)[self requestWithCmd: CVS_DIFF_CMD_TAG title:@"diff" path: commonPath files: checkedFiles];
    [request setContext:contextLineNumber];
    [request setOutputFormat:newOutputFormat];

    return request;
}

- (void)dealloc
{
    RELEASE(parsingBuffer);
    RELEASE(result);
    RELEASE(diffPath);
    
    [super dealloc];
}

- (NSArray *)cvsCommandOptions
{
    NSMutableArray	*options = [NSMutableArray arrayWithObject:@"-l"]; // Do not make it recursive; keep local
    
    if(rcsdiffOptions && [rcsdiffOptions length])
         [options addObject:rcsdiffOptions];
    switch(outputFormat){
        case CVLNormalOutputFormat:
            break;
        case CVLContextOutputFormat:
            if(context > 0)
                [options addObject:[NSString stringWithFormat:@"--context=%u", context]];
            else
                [options addObject:[NSString stringWithFormat:@"--context"]];
            break;
        case CVLUnifiedOutputFormat:
            if(context > 0)
                [options addObject:[NSString stringWithFormat:@"--unified=%u", context]];
            else
                [options addObject:[NSString stringWithFormat:@"--unified"]];
            break;
    }

    return options;
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
    BOOL up;

    up=[super setUpTask];

#ifdef JA_PATCH
    if (!result) {
        [self initResult];
    }
    if (up) {
        parsingBuffer=[[NSMutableString alloc] init];
    }
#else
    if (up) {
        parsingBuffer=[[NSMutableString alloc] init];
        if (!result) {
            [self initResult];
        }
    }
#endif

    return up;
}

- (void) readDiffFrom: (NSString*) aString
    // scan 'aString' and update status, if any
{
    // NSAutoreleasePool *subpool = [[NSAutoreleasePool alloc] init];
    NSMutableDictionary *diffDict;
    NSString* aPath= NULL;
    NSArray* matchArray= nil; // [aString findAllSubPatternMatchesWithPattern: CvsDiffRequestFilenamePattern options:0];

#if 0
    if ([matchArray count]) {
        ASSIGN(diffPath, [matchArray objectAtIndex: 2]);
    } else {	//	get path info from cmd queue
#endif
      {
        ECFileFlags fileFlags;

        ASSIGN(diffPath, [self path]);
        fileFlags=[(CVLFile *)[CVLFile treeAtPath:diffPath] flags];
//        if (!fileFlags.isDir || fileFlags.isWrapper) {
//            diffPath=[diffPath stringByDeletingLastPathComponent];
//        }
    }
#if 0
        // BUG 1000145: Perl works only with ASCII chars and Oyster makes a -[NSString cString] call
        // If aString cannot be converted to ASCII, an uncaught exception is raised!
    matchArray= [aString findAllSubPatternMatchesWithPattern:CvsDiffPathPattern  
                                                     options:0];
#else
	// We don't need to parse the whole output just to retrieve the filename.
 	// We can simply parse the first line. This way we avoid BUG 1000145.
	// In cvs 1.10.13 source, we can see that @"Index: " is followed immediately by the filename.
	if([aString hasPrefix:@"Index: "])
        matchArray = [NSArray arrayWithObject:[aString substringWithRange:NSMakeRange(7, [aString rangeOfString:RequestNewLineString].location - 7)]];
#endif
    if ([matchArray count])
    {
        aPath= [diffPath stringByAppendingPathComponent: [matchArray objectAtIndex: 0]];
        diffDict=[result objectForKey:aPath];
        if (!diffDict) {
            diffDict=[NSMutableDictionary dictionary];
            [result setObject:diffDict forKey:aPath];
        }
        [diffDict setObject: aString forKey: CVS_DIFF_KEYWORD];
    }
    // [subpool release];
} // readDiffFrom:

#ifdef JA_PATCH
- (void)parseOutput:(NSString *)data
{

    [parsingBuffer appendString: data];
    [self readDiffFrom: parsingBuffer];
}


- (void)parseError:(NSString *)data
{
    [self parseOutput: data];
    [super parseError:data];
}

- (void)flushBuffers
{
    [self readDiffFrom: parsingBuffer];
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
- (void)parseOutput:(NSString *)data
{
#if 0
    NSRange sentinelRange;
    NSArray* results= nil;
    int rCount= 0;
    int j= 0;
#endif

    [parsingBuffer appendString: data];
    // sentinel to avoid deleting last split pattern
#if 0
    sentinelRange.length= 2;
    [parsingBuffer appendString: @"xx"];
    // split sur ====
    results= [parsingBuffer splitStringWithPattern: @"=+\\n" 
                                           options:0];
    // WRONG! cut on --- between diffs: results= [parsingBuffer splitStringWithPattern: CvsRequestLineOfEqualsOrMinusPattern options:0];
    rCount= [results count];
    for (j= 0; j< rCount-1; j++)
    {	// give all results to the reader
        NSString* aResult= [results objectAtIndex: j];
        if ([aResult length] > .0)
        {
            [self readDiffFrom: aResult];
        }
    }
#else
    [self readDiffFrom: parsingBuffer];
#endif

#if 0
    [parsingBuffer setString: [results objectAtIndex: rCount -1]];
    sentinelRange.location= [parsingBuffer length] -  sentinelRange.length;
    [parsingBuffer deleteCharactersInRange: sentinelRange];
#endif    
}


- (void)parseError:(NSString *)data
{
    [self parseOutput: data];
    [super parseError:data];
}

- (void)end
{
    [self readDiffFrom: parsingBuffer];
    RELEASE(parsingBuffer);

    if (!result) {
        [self initResult];
    }
    [super endWithoutInvalidation];
}
#endif

@end
