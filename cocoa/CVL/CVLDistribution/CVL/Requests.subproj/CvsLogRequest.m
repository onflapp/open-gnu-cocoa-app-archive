/* CvsLogRequest.m created by ja on Thu 04-Sep-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsLogRequest.h"
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>


static NSString* CvsLogWorkingFilePattern = @"Working file:\\s+(.*)\\n";


@interface CvsLogRequest (Private)
- (void)initResult;
@end

@implementation CvsLogRequest
+ (CvsLogRequest *)cvsLogRequestForFiles:(NSArray *)someFiles inPath:(NSString *)aPath
{
    return [self requestWithCmd:CVS_LOG_CMD_TAG title:@"log" path:aPath files:someFiles];
}

- (void)dealloc
{
    RELEASE(parsingBuffer);
    RELEASE(result);
    RELEASE(logPath);
    
    [super dealloc];
}

- (NSArray *)cvsCommandOptions
{
    return nil;
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
    if ([super setUpTask]) {

        parsingBuffer=[[NSMutableString alloc] init];

        if (!result) {
            [self initResult];
        }
        return YES;
    } else {
        return NO;
    }
}

- (void) readLogFrom: (NSString*) aString
  // scan 'aString' and update log info, if any
{
    NSAutoreleasePool *subpool = [[NSAutoreleasePool alloc] init];
    NSArray* matchArray= [aString findAllSubPatternMatchesWithPattern:CvsLogWorkingFilePattern  options:0];
    NSArray* linesArray;
    int linesCount= 0;
    int i= 0;
    NSString* revision= nil;
    NSString* author= nil;
    NSString* message= nil;
    NSCalendarDate* date= nil;
    NSString	*lineModif = nil;
    NSString	*stateString = nil;

    if ([matchArray count] > 0) {
        ASSIGN(logPath, [[self path] stringByAppendingPathComponent: [matchArray objectAtIndex: 0]]);
    }
    
    linesArray= [aString splitStringWithPattern:CvsRequestNewLinePattern
                                        options:0];
    linesCount= [linesArray count];

    while (!(revision) && (i < linesCount)) {
        NSString* line= [linesArray objectAtIndex: i];

        if (([line length] > 10) && ([[line substringToIndex: 9] isEqualToString: @"revision "])) {
            revision= [line substringFromIndex: 9];
        }
        i++;
    }
    if ((revision) && (i < linesCount)) {
        NSString* nextLine= [linesArray objectAtIndex: i];
		NSMutableString *aDateString = nil;
		NSRange searchRange;
		unsigned int numberOfReplacements = 0;

        // Warning: <lines: xxx> is optional!
        matchArray= [nextLine findAllSubPatternMatchesWithPattern:@"date:\\s+(.*);\\s+author:\\s+(.*);\\s+state:\\s+(.*);(\\s+lines:\\s+(.*))?"  options:0];
        if ([matchArray count] > 4) { // all infos are present
            author= [matchArray objectAtIndex: 1];
			
            // log is the only cvs subcommand which returns dates in UTC timezone
			// In cvs 1.12.9, the date format in 'cvs log' output has changed 
			// from 'yyyy/mm/dd' to 'yyyy-mm-dd'.
			aDateString = [NSMutableString stringWithString:[matchArray objectAtIndex: 0]];
			// Lets replace dashes with slashes.
			searchRange = NSMakeRange(0, [aDateString length]);
			numberOfReplacements = [aDateString replaceOccurrencesOfString:@"-" 
										       withString:@"/" 
											      options:0 
											        range:searchRange];
			if ( numberOfReplacements == 0 ) {
				// If there are no replacements then we known that we are not 
				// using cvs 1.12.9 so we add the time zone offset here.
				// Note: cvs 1.12.9 adds the time zone offset to the date.
				[aDateString appendString:@" +0000"];
			}
            date= [NSCalendarDate dateWithString: aDateString
                                  calendarFormat: @"%Y/%m/%d %H:%M:%S %z"];
            [date setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
			
			lineModif = [matchArray objectAtIndex:4];
            stateString = [matchArray objectAtIndex:2];
        }
    }
    if ((date) && (i+1 < linesCount)) {	// infos found, get complete log and fill dictionary
        NSRange theRange= {i+1, linesCount - i - 1};		
        NSArray* logArray= [linesArray subarrayWithRange: theRange];

        message= [logArray componentsJoinedByString: RequestNewLineString];
    }
    if (message) {	// all infos are filled, set them into dictionary
        NSMutableDictionary* resultDict= [result objectForKey: logPath];
        NSMutableArray* newArray= [NSMutableArray arrayWithCapacity: 0];
        NSMutableDictionary *logDict= [NSMutableDictionary dictionaryWithCapacity: 0];

        if (!resultDict)
        {
          resultDict=[NSMutableDictionary dictionary];
          [result setObject:resultDict forKey: logPath];
        }
        [logDict setObject: revision forKey: @"revision"];
        [logDict setObject: date forKey: @"date"];
        [logDict setObject: author forKey: @"author"];
        [logDict setObject: message forKey: @"msg"];
        [logDict setObject: lineModif forKey: @"modifs"];
        [logDict setObject: stateString forKey: @"state"];

        [newArray addObjectsFromArray: [resultDict objectForKey: @"log"]];
        [newArray addObject: logDict];
        [resultDict setObject: newArray forKey: @"log"];
    }
    [subpool release];
} // readLogFrom:

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
  results= [parsingBuffer splitStringWithPattern:CvsRequestLineOfEqualsOrMinusPattern 
                                         options:0];
  rCount= [results count];
  j= 0;
  for (j= 0; j< rCount-1; j++)
  {	// give all results to the reader
    NSString* aResult= [results objectAtIndex: j];
    if ([aResult length] > .0)
    {
      [self readLogFrom: aResult];
    }
  }
  [parsingBuffer setString: [results objectAtIndex: rCount -1]];
  sentinelRange.location= [parsingBuffer length] -  sentinelRange.length;
  [parsingBuffer deleteCharactersInRange: sentinelRange];
} //

#ifdef JA_PATCH
- (void)flushBuffers
{
    [self readLogFrom: parsingBuffer];
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
    [self readLogFrom: parsingBuffer];
    RELEASE(parsingBuffer);

    if (!result) {
        [self initResult];
    }
    [super endWithoutInvalidation];
}
#endif
@end
