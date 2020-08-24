/* CvsStatusRequest.m created by ja on Thu 04-Sep-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.


/*" This class performs a status request for an array of files/directories 
    located in a common directory. If any directories are specified then the 
    status command will be recursive. The output from this request is in the 
    form of a dictionary with values for the following keys. Some key/values may
    not be present.

    _{StatusKey             mandatory}
    _{VersionKey            mandatory}
    _{RepositoryVersionKey	optional}
    _{RepositoryPathKey     optional}
    _{LastCheckoutKey       optional}
    _{StickyTagKey          optional}
    _{StickyDateKey         optional}
    _{StickyOptionsKey		optional}
    

Example of a full status output (without tag info):
 ===================================================================
 File: aFilename         	Status: aStatus
 
 Working revision:	aWorkAreaRevision	aLastCheckoutDate
 Repository revision:	aRepositoryRevision aRepositoryPath
 Sticky Tag:		aStickyTag
 Sticky Date:		aStickyDate
 Sticky Options:	aStickyOption
 
 Note that aLastCheckoutDate does NOT appear in client/server mode!
 Lines up to Repository revision ALWAYS appear.
 aFilename can be "no file %s"
 aWorkAreaRevision can be "No entry for %s", or "New file!"
 aRepositoryRevision can be "No revision control file"
 aStickyDate, aStickyTag, aStickyOption can be "(none)".
 aStickyTag can be "aBranch (branch)" or "aRevision (revision)", or "aBranch - MISSING from RCS file!" or "aRevision - MISSING from RCS file!"
 "*/

#import "CvsStatusRequest.h"
#import "ResultsRepository.h"
#import "NSArray.SenCategorize.h"
#import "CVLFile.h"
#import <CVLConsoleController.h>
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>
#import <CvsRepository.h>


NSString* CvsStatusExaminingPattern= @"cvs status: Examining\\s+(.*)\\n"; // FIXME Unused
NSString* CvsStatusStatusPattern= @"Status:\\s+(.*)\\n";
NSString* CvsStatusFilePattern= @"File:\\s+(no file)?\\s*(.*)\\t";
NSString* CvsStatusRevisionPattern= @"Working revision:\\s+(.*)\\n";
NSString* CvsStatusRepositoryPattern= @"Repository revision:\\s+(.*)\\n";
NSString* CvsStatusStickyTagPattern= @"Sticky Tag:\\s+(.*)\\n";
NSString* CvsStatusStickyDatePattern= @"Sticky Date:\\s+(.*)\\n";
NSString* CvsStatusStickyOptionsPattern= @"Sticky Options:\\s+(.*)\\n";
NSString* CvsStatusLineOfEqualsPattern= @"=+\\n";
BOOL warningSuppressed = NO;


@interface CvsStatusRequest (Private)
- (void)initResult;
@end

@implementation CvsStatusRequest
+ (CvsStatusRequest *)cvsStatusRequestForFiles:(NSArray *)someFiles inPath:(NSString *)aPath
{
    NSArray *checkedFiles=nil;
    NSDictionary* pathDict;
    NSString* commonPath;

    if (someFiles) {
        pathDict=[[self class] canonicalizePath: aPath andFiles: someFiles];
        commonPath= [[pathDict allKeys] objectAtIndex: 0];
        checkedFiles= [pathDict objectForKey: commonPath];
    } else {
        commonPath=aPath;
    }

    return [self requestWithCmd:CVS_STATUS_CMD_TAG title:@"status" path: commonPath files: checkedFiles];
}

- (void)dealloc
{
    RELEASE(parsingBuffer);
    RELEASE(result);
    
    [super dealloc];
}

- (NSArray *)cvsOptions
{
    NSArray		*previousOptions = [super cvsOptions];
    NSArray		*newOptions = nil;
    NSNumber	*aCompressionLevel = [repository compressionLevel];

    if( [aCompressionLevel intValue] > 0 )
        newOptions = [NSArray arrayWithObject:[NSString stringWithFormat:@"-z%@", aCompressionLevel]];

    if(newOptions)
        return [previousOptions arrayByAddingObjectsFromArray:newOptions];
    else
        return previousOptions;
}

- (NSArray *)cvsCommandOptions
{
    // Developer's note: The "-l" option does not work with the status command
    // for version "Concurrent Versions System (CVS) 1.10 `Halibut' (client/server)"
    // Stephane says we should not be using the "-l" option anyway.
    // William Swats -- 19-May-2004
    //return [NSArray arrayWithObject:@"-l"];
    return [NSArray array];
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
    /*" The output from this request is in the form of a dictionary with values
        for the following keys. Some key/values may not be present.

        _{StatusKey             mandatory}
        _{VersionKey            mandatory}
        _{RepositoryVersionKey	optional}
        _{RepositoryPathKey     optional}
        _{LastCheckoutKey       optional}
        _{StickyTagKey          optional}
        _{StickyDateKey         optional}
        _{StickyOptionsKey		optional}
    "*/

{
  return result;
}

- (void)initResult
{
    NSMutableDictionary *resultDict;
    NSString *filePath;
    CVLFile *file;
    id argsEnumerator;
    ResultsRepository *resultsRepository=[ResultsRepository sharedResultsRepository];

    result=[[NSMutableDictionary alloc] init];
    if ([self files]) {
        [resultsRepository startUpdate];

        argsEnumerator=[[self files] objectEnumerator];
        while ( (filePath=[argsEnumerator nextObject]) ) {
            filePath=[path stringByAppendingPathComponent:filePath];
            file=(CVLFile *)[CVLFile treeAtPath:filePath];
            if([file isLeaf]){
               // NSCalendarDate* pastDate= [[NSDate distantPast] dateWithCalendarFormat: NULL
               //                                                             timeZone: NULL];
                resultDict=[NSMutableDictionary dictionary];
                [resultDict setObject:@"Unknown" forKey:CVS_STATUS_KEYWORD];
                //[resultDict setObject:@"none" forKey:CVS_VERSION_KEYWORD];
                // [resultDict setObject: pastDate forKey:CVS_LAST_CHECKOUT_DATE_KEYWORD];
                //[resultDict setObject:@"none" forKey: CVS_REPOSITORY_VERSION_KEYWORD];
                [result setObject:resultDict forKey:filePath];
            }
        }
        [resultsRepository endUpdate];
    }
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
        if (!result) {
            [self initResult];
        }
        parsingBuffer=[[NSMutableString alloc] init];
    }
#endif

    return up;
}

- (void) readStatusFrom: (NSString*) aString
    // scan 'aString' and update status, if any
{
  NSAutoreleasePool *subpool = nil;
  NSMutableDictionary *statusDict;
  NSString *aPath = nil;
  NSString *aFilename = nil;
  NSString *aStatus = nil;
  NSString *aWorkAreaRevision = nil;
  NSCalendarDate *aLastCheckoutDate = nil;
  NSString *aRepositoryRevision = nil;
  NSString *aRepositoryPath = nil;
  NSString *aStickyTag = nil;
  NSString *aStickyOption = nil;
  NSCalendarDate *aStickyDate = nil;
  ECFileFlags fileFlags;
  
  subpool = [[NSAutoreleasePool alloc] init];
  
  fileFlags = [(CVLFile *)[CVLFile treeAtPath:[self path]] flags];
  aFilename = [self parseFilenameFromString:aString];
  if ( isNotEmpty(aFilename) ) {
      aRepositoryPath = [self parseRepositoryPathFromString:aString];
      // Developers Note: Since the option "-l" does not work 
      // (See -cvsCommandOptions above), we cannot assume that the file whose
      // status information is given in aString is in the directory [self path].
      // Instead, the file could be in a sub-directory. Hence we work out the 
      // path with the call to the method -createPathFrom:andRepositoryPath:
      aPath = [self createPathFrom:aFilename andRepositoryPath:aRepositoryPath];
      
    statusDict=[result objectForKey:aPath];
    if ( statusDict == nil ) {
      statusDict=[NSMutableDictionary dictionary];
      [result setObject:statusDict forKey:aPath];
    }
    
    aStatus = [self parseStatusFromString:aString];
    if ( aStatus != nil ) {
      [statusDict setObject:aStatus forKey:CVS_STATUS_KEYWORD];
    }
    
    aWorkAreaRevision = [self parseWorkAreaRevisionFromString:aString];
    if ( isNotEmpty(aWorkAreaRevision) ) {
        [statusDict setObject:aWorkAreaRevision forKey: CVS_VERSION_KEYWORD];
        // Start "Locally Added" hack.
        // If this is a  file that has been locally added but not committed and
        // then deleted in the Finder; then it will disappear in the CVL browser
        // if we do not correct the status here! The status string returned from
        // CVS is "Entry Invalid" but we want it to be "Locally Added". So if
        // the revision string is "New file!" but the status string is
        // "Entry Invalid" then we change the status string to "Locally Added".
        if ( [aWorkAreaRevision isEqualToString:@"New file!"] &&
             [aStatus isEqualToString:@"Entry Invalid"] ) {
            [statusDict setObject:@"Locally Added" forKey:CVS_STATUS_KEYWORD];
        }
        // End of "Locally Added" hack.        
    }
    
    aLastCheckoutDate = [self parseLastCheckoutDateFromString:aString];
    if ( aLastCheckoutDate != nil ) {
        [statusDict setObject:aLastCheckoutDate
                       forKey:CVS_LAST_CHECKOUT_DATE_KEYWORD];
    }

    aRepositoryRevision = [self parseRepositoryRevisionFromString:aString];
    if ( isNotEmpty(aRepositoryRevision) ) {
        [statusDict setObject:aRepositoryRevision 
                       forKey:CVS_REPOSITORY_VERSION_KEYWORD];
    }

    // Already parsed the Repository Path above.
    if ( isNotEmpty(aRepositoryPath) ) {
        [statusDict setObject:aRepositoryPath 
                       forKey:CVS_REPOSITORY_PATH_KEYWORD];
    }
    
    aStickyTag = [self parseStickyTagFromString:aString];
    if ( isNotEmpty(aStickyTag) ) {
        if ( [aStickyTag isEqualToString: @"(none)"] == NO ) {
            [statusDict setObject:aStickyTag 
                           forKey:CVS_STICKY_TAG_KEYWORD];
        }
    }

    aStickyOption = [self parseStickyOptionsFromString:aString];
    if ( isNotEmpty(aStickyOption) ) {
        if ( [aStickyOption isEqualToString: @"(none)"] == NO ) {
            [statusDict setObject:aStickyOption 
                           forKey:CVS_STICKY_OPTIONS_KEYWORD];
        }
    }
    
    aStickyDate = [self parseStickyDateFromString:aString];
    if ( aStickyDate != nil ) {
        [statusDict setObject:aStickyDate forKey:CVS_STICKY_DATE_KEYWORD];
    }

  }
  [subpool release];
}


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

  // split sur ====
  results = [parsingBuffer splitStringWithPattern:CvsStatusLineOfEqualsPattern 
                                          options:0];
  rCount= [results count];
  for (j= 0; j< rCount-1; j++)
  {	// give all results to the reader
    NSString* aResult= [results objectAtIndex: j];
    if ([aResult length] > .0)
    {
      [self readStatusFrom: aResult];
    }
  }
  [parsingBuffer setString: [results objectAtIndex: rCount -1]];
  sentinelRange.location= [parsingBuffer length] -  sentinelRange.length;
  [parsingBuffer deleteCharactersInRange: sentinelRange];
}


- (void)parseError:(NSString *)aString
{
    // Note: This method used to append this error string to the parsingBuffer.
    // However, sometimes this caused the status output to become corrupted due
    // to error messages being embedded in the status output. Hence we no longer
    // do this. The code now simply looks for "status aborted" in the error
    // messages and warns the user if one is found.
    // William Swats -- 27-May-2004
	int aChoice = NSAlertDefaultReturn;

    if ( (warningSuppressed == NO ) &&
		 ([aString hasPrefix:@"cvs"] || [aString hasPrefix:@"ocvs"]) && 
         ([aString rangeOfString:@"status aborted"].length > 0) ) {
        aChoice = NSRunAlertPanel(@"CVS Status Request", 
                              @"Sorry, this status request was aborted by CVS. The reason given is:\n\n \"%@\"\n\n This may indicate that there is corruption in the workarea or in the repository.",
                              @"OK", @"Do Not Show Again", nil, aString);
		if ( aChoice == NSAlertAlternateReturn ) {
            warningSuppressed = YES;
        }		
        return;
    }
    [super parseError:aString];
}

#ifdef JA_PATCH
- (void)flushBuffers
{
    [self readStatusFrom: parsingBuffer];
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
    [self readStatusFrom: parsingBuffer];
    RELEASE(parsingBuffer);

    if (!result) {
        [self initResult];
    }
    [super endWithoutInvalidation];
}
#endif

- (int)priority
{
    return -10;
}

- (NSString *) parseFilenameFromString:(NSString *)aString
    /*" This method returns a filename for the the workarea file that was parsed
        from aString or nil if none were found. aString contains the output of 
        the CVS status command. In aString the filename field can also be 
        "no file %s". See the class description for an explaination of output of
        a CVS status command.
    "*/
{
    NSString *aFilename = nil;
    NSString *aMatchedObject = nil;
    NSArray *matchArray = nil;
    
    matchArray = [aString 
                        findAllSubPatternMatchesWithPattern:CvsStatusFilePattern
                                                    options:0];
    if ( [matchArray count] > 1 ) {		// assign after removing trailing spaces
        aMatchedObject = [matchArray objectAtIndex:1];
        aFilename = [aMatchedObject 
                            replaceMatchesOfPattern:CvsLeadingWhiteSpacePattern 
                                         withString:@"" 
                                            options:AGRegexMultiline];
    }
    return aFilename;
}

- (NSString *) parseStatusFromString:(NSString *)aString
    /*" This method returns a status for the the workarea file that was parsed 
        from aString or nil if none were found. aString contains the output of 
        the CVS status command.  See the class description for an explaination 
        of output of a CVS status command. The status strings that this method 
        can return are:

        #{Up-to-date}   The file is identical with the latest revision in the 
        repository for the branch in use.

        #{Locally Modified} You have edited the file, and not yet committed your
        changes.

        #{Locally Added} You have added the file with add, and not yet committed 
        your changes.

        #{Locally Removed} You have removed the file with remove, and not yet 
        committed your changes.

        #{Needs Checkout} Someone else has committed a newer revision to the 
        repository. The name is slightly misleading; you will ordinarily use 
        update rather than checkout to get that newer revision.

        #{Needs Patch} Like Needs Checkout, but the CVS server will send a patch 
        rather than the entire file. Sending a patch or sending an entire file
        accomplishes the same thing.

        #{Needs Merge} Someone else has committed a newer revision to the 
        repository, and you have also made modifications to the file.

        #{File had conflicts on merge} This is like #{Locally Modified}, except 
        that a previous update command gave a conflict. If you have not already 
        done so, you need to resolve the conflict as described in section 
        Conflicts example.

        #{Unknown} CVS doesn't know anything about this file. For example, you
        have created a new file and have not run add.
    "*/
{
    NSString *aStatus = nil;
    NSString *aMatchedObject = nil;
    NSArray *matchArray = nil;
    
    matchArray = [aString 
                    findAllSubPatternMatchesWithPattern:CvsStatusStatusPattern 
                                                options:0];
    if ([matchArray count] > 0) {
        aMatchedObject = [matchArray objectAtIndex:0];
        aStatus = aMatchedObject;
    }
    return aStatus;
}

- (NSString *) parseWorkAreaRevisionFromString:(NSString *)aString
    /*" This method returns the workarea revision for the the workarea file that
        was parsed from aString or nil if none were found. aString contains the 
        output of the CVS status command. The workarea revision can also be 
        "No entry for %s", or "New file!". See the class description for an 
        explaination of output of a CVS status command.
    "*/
{
    NSString *aWorkAreaRevision = nil;
    NSString *aMatchedObject = nil;
    NSArray *matchArray = nil;
    NSArray *splitArray = nil;
    
    matchArray = [aString 
                    findAllSubPatternMatchesWithPattern:CvsStatusRevisionPattern  
                                                options:0];
    if ( [matchArray count] > 0 ) {
        aMatchedObject = [matchArray objectAtIndex:0];
        splitArray = [aMatchedObject splitStringWithPattern:@"\\t" 
                                                    options:0];
        aWorkAreaRevision = [splitArray objectAtIndex:0];
    }
    return aWorkAreaRevision;
}

- (NSCalendarDate *) parseLastCheckoutDateFromString:(NSString *)aString
    /*" This method returns the last checkout date for the workarea file that 
        was parsed from aString or nil if none were found. aString contains the
        output of the CVS status command.  Note that a last checkout date does 
        NOT appear in client/server mode! See the class description for an 
        explaination of output of a CVS status command.
    "*/
{
    NSString *aMatchedObject = nil;
    NSArray *matchArray = nil;
    NSArray *splitArray = nil;
    NSString *dateString = nil;
    NSString *aNewDateString = nil;
    NSCalendarDate *aLastCheckoutDate = nil;
    
    matchArray = [aString 
                    findAllSubPatternMatchesWithPattern:CvsStatusRevisionPattern  
                                                options:0];
    if ( [matchArray count] > 0 ) {
        aMatchedObject = [matchArray objectAtIndex:0];
        splitArray = [aMatchedObject splitStringWithPattern:@"\\t" 
                                                     options:0];
        if ( [splitArray count] > 1 ) {
            dateString = [splitArray objectAtIndex:1];
            // cvs outputs time and dates in LOCAL timezones! 
            // Except for the cvs log command which returns UTC timezone
            // (Stephane) It seems that this is wrong: it outputs an UTC date here...
            aNewDateString = [dateString stringByAppendingString: @" +0000"];
            aLastCheckoutDate = [NSCalendarDate dateWithString:aNewDateString
                                    calendarFormat:@"%a %b %d %H:%M:%S %Y %z"];
            
            // BUG 1000063: it may happen that second element is NOT a date, 
            // but a description like "Result of merge"!
        }            
    }
    return aLastCheckoutDate;
}

- (NSString *) parseRepositoryRevisionFromString:(NSString *)aString
    /*" This method returns the repository revision for the workarea file that 
        was parsed from aString or nil if none were found. aString contains the 
        output of the CVS status command. In aString the repository revision can be 
        "No revision control file". See the class description for an 
        explaination of output of a CVS status command.
    "*/
{
    NSString *aRepositoryRevision = nil;
    NSString *aMatchedObject = nil;
    NSArray *matchArray = nil;
    NSArray *splitArray = nil;
    
    matchArray = [aString 
                findAllSubPatternMatchesWithPattern:CvsStatusRepositoryPattern  
                                            options:0];
    if ( [matchArray count] > 0 ) {
        aMatchedObject = [matchArray objectAtIndex:0];
        splitArray = [aMatchedObject splitStringWithPattern:@"\\t" 
                                                    options:0];
        aRepositoryRevision = [splitArray objectAtIndex:0];
    }
    return aRepositoryRevision;
}

- (NSString *) parseRepositoryPathFromString:(NSString *)aString
    /*" This method returns the repository path for the workarea file that was parsed 
        from aString or nil if none were found. aString contains the output of 
        the CVS status command. See the class description for an explaination of 
        output of a CVS status command.
    "*/
{
    NSString *aMatchedObject = nil;
    NSArray *matchArray = nil;
    NSArray *splitArray = nil;
    NSString *aRepositoryPath = nil;
    
    matchArray = [aString 
                    findAllSubPatternMatchesWithPattern:CvsStatusRepositoryPattern  
                                                options:0];
    if ( [matchArray count] > 0 ) {
        aMatchedObject = [matchArray objectAtIndex:0];
        splitArray = [aMatchedObject splitStringWithPattern:@"\\t" 
                                                    options:0];
        if ( [splitArray count] > 1 ) {
            aRepositoryPath = [splitArray objectAtIndex:1];
        }            
    }
    return aRepositoryPath;
}

- (NSString *) parseStickyTagFromString:(NSString *)aString
    /*" This method returns the sticky tag for the workarea file that was parsed
        from aString or nil if none were found. aString contains the output of 
        the CVS status command. In aString the sticky tag can be "(none)". See 
        the class description for an explaination of output of a CVS status 
        command.  Note: aStickyTag can be one of the following:
        _{1. "aBranch (branch)"}
        _{2. "aBranch - MISSING from RCS file!"}
        _{3. "aRevision (revision)"}
    "*/
{
    NSString *aStickyTag = nil;
    NSArray *matchArray = nil;
    
    matchArray = [aString 
                findAllSubPatternMatchesWithPattern:CvsStatusStickyTagPattern  
                                            options:0];
    if ( [matchArray count] > 0 ) {
        aStickyTag = [matchArray objectAtIndex:0];
    }
    return aStickyTag;
}

- (NSString *) parseStickyOptionsFromString:(NSString *)aString
    /*" This method returns the sticky options for the the workarea file that 
        was parsed from aString or nil if none were found. aString contains the
        output of the CVS status command. In aString the sticky options can be 
        "(none)". See the class description for an explaination of output of a 
        CVS status command.
    "*/
{
    NSString *aStickyOption = nil;
    NSArray *matchArray = nil;
    
    matchArray = [aString 
            findAllSubPatternMatchesWithPattern:CvsStatusStickyOptionsPattern  
                                        options:0];
    if ( [matchArray count] > 0 ) {
        aStickyOption = [matchArray objectAtIndex:0];
    }
    return aStickyOption;
}

- (NSCalendarDate *) parseStickyDateFromString:(NSString *)aString
    /*" This method returns the sticky date for the the workarea file that 
        was parsed from aString or nil if none were found. aString contains the
        output of the CVS status command. In aString the sticky date can be 
        "(none)". See the class description for an explaination of output of a 
        CVS status command.
    "*/
{
    NSArray *matchArray = nil;
    NSString *aDateString = nil;
    NSString *aNewDateString = nil;
    NSCalendarDate *aStickyDate = nil;
    
    matchArray = [aString 
                findAllSubPatternMatchesWithPattern:CvsStatusStickyDatePattern  
                                            options:0];
    if ( [matchArray count] > 0 ) {
        aDateString = [matchArray objectAtIndex:0];
        // cvs outputs time and dates in LOCAL timezones! 
        // Except for the cvs log command which returns UTC timezone
        // (Stephane) It seems that this is wrong: it outputs an UTC date here...
        aNewDateString = [aDateString stringByAppendingString: @" +0000"];
        aStickyDate = [NSCalendarDate dateWithString:aNewDateString
                                calendarFormat:@"%Y.%m.%d.%H.%M.%S %z"];
    }
    return aStickyDate;
}

- (NSString *)createPathFrom:(NSString *)aFilename andRepositoryPath:(NSString *)aRepositoryPathString
    /*" This method will return a path in the workarea to the file whose name is
        given in afilename and has the path in the repository given by 
        aRepositoryPathString. This is the only way to determine the absolute
        path of this file based on the information returned by the CVS status 
        command.
    "*/
{
    NSString *aPath = nil;
    NSString *repositoryPathDirectory = nil;
    NSString *theCvsRepositoryPath = nil;
    NSString *subdirectories = nil;
    NSString *theCvsWorkingDirectory = nil;
    unsigned int theLength = 0;
    
    SEN_ASSERT_NOT_EMPTY(aFilename);

    // First get a path to the root of the workarea.
    theCvsWorkingDirectory = [self cvsWorkingDirectory];
    SEN_ASSERT_NOT_EMPTY(theCvsWorkingDirectory);
    
    if ( isNotEmpty(aRepositoryPathString) ) {
        // Get the directory path in the repository by strippping off the filename.
        repositoryPathDirectory = [aRepositoryPathString 
            stringByDeletingLastPathComponent];
        // Strip off the "Attic" repository directory if repositoryPathDirectory
        // has it appended at the end. Try both with and without a slash at the 
        // end.
        if ( [repositoryPathDirectory hasSuffix:@"/Attic"] == YES ) {
            repositoryPathDirectory = [repositoryPathDirectory 
                stringByDeletingLastPathComponent];
        }
        if ( [repositoryPathDirectory hasSuffix:@"/Attic/"] == YES ) {
            repositoryPathDirectory = [repositoryPathDirectory 
                stringByDeletingLastPathComponent];
        }
        // Get the repository path for the workarea.
        theCvsRepositoryPath = [CvsRepository
                        cvsRepositoryPathForDirectory:theCvsWorkingDirectory];
        // See if this workarea repository path and the repository path given as
        // argument to this method have the same leading components. They should.
        if ( [repositoryPathDirectory hasPrefix:theCvsRepositoryPath] == YES ) {
            // Strip off leading path components.
            theLength = [theCvsRepositoryPath length];
            // This should produce a path relative to the workarea root that
            // points to the directory containing the file named in afilename.
            subdirectories = [repositoryPathDirectory substringFromIndex:theLength];
            if ( isNotEmpty(subdirectories) ) {
                // Append the relative path to the workarea path to get the 
                // absolute path to the directory containing the file named in 
                // afilename.
                theCvsWorkingDirectory = [theCvsWorkingDirectory 
                                stringByAppendingPathComponent:subdirectories];
            }
        }        
    }
    // Append the file named in afilename to this result to get the absolute path
    // to file named in afilename that is in the workarea.
    aPath = [theCvsWorkingDirectory stringByAppendingPathComponent:aFilename];
    
    return aPath;    
}


@end
