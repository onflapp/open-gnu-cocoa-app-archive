/* CvsQuickStatusRequest.m created by stephane on Tue 05-Oct-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsQuickStatusRequest.h"
#import <Foundation/Foundation.h>
#import "CVLFile.h"
#import <CvsRepository.h>
#import <NSString+Lines.h>
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>

@interface CvsQuickStatusRequest(Private)
- (void) readStatusesFromString:(NSString *)aBuffer;
- (void) parseString:(NSString *)data usingBuffer:(NSMutableString *)aBuffer;
- (BOOL)checkForAccessToHistoryFile:(NSString *)aLine;
- (BOOL)checkForConflicts:(NSString *)aLine;
- (BOOL)checkForCouldNotFindVersion:(NSString *)aLine;
- (BOOL)checkForIsModifiedButNoLongerPertinent:(NSString *)aLine;
- (BOOL)checkForLostFile:(NSString *)aLine;
- (BOOL)checkForMoveAway:(NSString *)aLine;
- (BOOL)checkForNewBornDisappeared:(NSString *)aLine;
- (BOOL)checkForNewDirectory:(NSString *)aLine;
- (BOOL)checkForNoLongerInRepository:(NSString *)aLine;
- (BOOL)checkForNoLongerPertinent:(NSString *)aLine;
- (BOOL)checkForPermissionsDenied:(NSString *)aLine;
- (BOOL)checkForWrapperOptionMNotSupported:(NSString *)aLine;

@end

@implementation CvsQuickStatusRequest

+ (CvsQuickStatusRequest *) cvsQuickStatusRequestFromPath:(NSString *)aPath
{
    CvsQuickStatusRequest	*request = [self requestWithCmd:CVS_QUICK_STATUS_CMD_TAG title:@"quick status" path:aPath files:nil];

    [request setIsQuiet:YES];
#if 0
NSAssert1([[(CVLFile *)[CVLFile treeAtPath:aPath] repository] root] != nil, @"No repository root for %@", aPath);
#else
	if(![[(CVLFile *)[CVLFile treeAtPath:aPath] repository] root])
        return nil;
#endif

    return request;
}

- (id) init
{
    if ( (self = [super init]) ) {
        parsingBuffer = [[NSMutableString allocWithZone:[self zone]] init];
        errorParsingBuffer = [[NSMutableString allocWithZone:[self zone]] init];
    }
    // If we get truncated lines, we will output bad results!!

    return self;
}

- (void) dealloc
{
    RELEASE(fileStatuses);
    RELEASE(parsingBuffer);
    RELEASE(errorParsingBuffer);

    [super dealloc];
}

- (NSArray *) cvsOptions
{
    NSArray		*previousOptions = [super cvsOptions];
    NSArray		*newOptions = [NSArray arrayWithObjects: @"-q", @"-n", nil];
    NSNumber	*aCompressionLevel = [repository compressionLevel];

    if( [aCompressionLevel intValue] > 0 )
        newOptions = [newOptions arrayByAddingObject:[NSString stringWithFormat:@"-z%@", aCompressionLevel]];

    return [previousOptions arrayByAddingObjectsFromArray:newOptions];
}

- (NSArray *) cvsCommandArguments
{
    return [NSArray array];
}

- (NSArray *) cvsCommandOptions
{
    // -P option has absolutely NO effect on the output!!!
    // Using -d option should be optional, as it also logs directories which
    // have definitely been removed!!!
    // Currently we will retrieve them, but mark them as UNKNOWN
//    if([[NSUserDefaults standardUserDefaults] boolForKey:@"QuickStatusShowsMissingDirectories"])
        return [NSArray arrayWithObjects:@"-d", nil]; // (pseudo) create missing directories
//    return [NSArray array];
}

- (NSString *) cvsWorkingDirectory
{
    return [self path];
}

- (void) parseError:(NSString *)data
{
    [self parseString:data usingBuffer:errorParsingBuffer];
    [super parseError:data];
}

- (void) parseOutput:(NSString *)data
{
    [self parseString:data usingBuffer:parsingBuffer];
}

- (void) parseString:(NSString *)data usingBuffer:(NSMutableString *)aBuffer
{
    NSRange	sentinelRange;
    NSArray	*results = nil;
    int		rCount = 0;
    int		j = 0;

    [aBuffer appendString:data];
    // sentinel to avoid deleting last split pattern
    sentinelRange.length = 2;
    [aBuffer appendString:@"xx"];

    results = [aBuffer lines];
    rCount = [results count];

    // Read all lines except the last one which may be uncomplete!
#ifdef JA_PATCH
    for(j = rCount - 2; j >= 0; j--){ // Give all results to the reader
        NSString	*aResult = [results objectAtIndex:j];

        if([aResult length] > .0)
            [self readStatusesFromString:aResult];
    }
#else
    for(j = rCount - 2; j >= 0; j--){ // Give all results to the reader
        NSString	*aResult = [results objectAtIndex:j];

        if([aResult length] > .0)
            [self readStatusesFromString:aResult];
    }
#endif

    [aBuffer setString:[results objectAtIndex:rCount - 1]];
    sentinelRange.location = [aBuffer length] - sentinelRange.length;
    [aBuffer deleteCharactersInRange:sentinelRange];
}

- (void) readStatusesFromString:(NSString *)aBuffer
/*" Status codes:
    'U' Up-to-date
    'A' Locally added
    'R' Locally removed
    'M' Locally modified
    'm' Custom flag to tell us we need a merge
    'C' Conflict OR needs merge
    '?' Unknown by cvs or not yet under cvs control
    'u' Custom flag to handle new directories in repository which are not yet registered in workarea
    '=' Custom flag to tell file is up-to-date
    '!' Custom flag to tell status output couldn't be parsed, so file needs full status retrieval
"*/
{
    // Up-to-date files are not displayed
    // Locally added files are prefixed with A
    // Locally added directories are NOT listed: only their content is listed
    // Locally removed files are prefixed with R
    // Locally removed directories are NOT listed: only their content is listed

    NSArray			*lines = [aBuffer lines];
    NSEnumerator	*statusLineEnum = [lines objectEnumerator];
    NSString		*aLine = nil;
	NSString		*aMsg = nil;
    BOOL			isMerging = NO;
    BOOL			statusRequestHasBeenAborted = NO;
    

    if(!fileStatuses)
        fileStatuses = [[NSMutableDictionary allocWithZone:[self zone]] initWithCapacity:[lines count]];
    
    while ( (aLine = [statusLineEnum nextObject]) ) {
        unichar	status;

        if([aLine length] < 3)
            continue;

        status = [aLine characterAtIndex:0];
        switch(status){
            case 'U': // Needs checkout or needs patch if already exists locally or needs merge if ???
            case 'A': // Locally added; locally added dirs are not listed: only their content is listed (=> problem if dir empty)
            case 'R': // Locally removed
            case 'M': // Locally modified OR needs merge!
                if([aLine characterAtIndex:1] != ' '){
                    // Merging differences between 1.11 and 1.16 into GPGKey.m
                    // RCS file: /cvsroot/gnustep/gnustep/core/base/Tools/AGSIndex.m,v
                    if([aLine hasPrefix:@"Merging differences"])
                        isMerging = YES;
                    break;
                }
            case 'C': // Conflict
            case '?': // Unknown by cvs, or contains non cvs files
                if(isMerging)
                    if(status == 'M')
                        status = 'm';
                [fileStatuses setObject:[NSString stringWithCharacters:&status length:1] forKey:[[self path] stringByAppendingPathComponent:[aLine substringFromIndex:2]]];
                isMerging = NO;
                break;
            case 'c': // In fact comes as an error (stderr), termination status != 0 (NEEDS TO BE CHECKED!!!!!!)
            case 'o':
#warning New outputs
// cvs [update aborted]: end of file from server (consult above messages if any)
                
    			// WARNING: in pserver mode, messages are a bit different: they begin with
       			// <cvs server> instead of <cvs update>
				if ( ([aLine hasPrefix:@"cvs"] || [aLine hasPrefix:@"ocvs"]) && 
					([aLine rangeOfString:@"update aborted"].length > 0 || 
					 [aLine rangeOfString:@"server aborted"].length > 0) ) {
					statusRequestHasBeenAborted = YES;
				}
				if([aLine hasPrefix:@"cvs"] || [aLine hasPrefix:@"ocvs"]){
					// cvs: inflate: unknown compression method
					// cvs: dying gasps from XXX unexpected
					// cvs: warning: unrecognized response XXX from cvs server
					if ( [aLine hasSuffix:@": inflate: unknown compression method"] || ([aLine rangeOfString:@": dying gasps from "].length > 0 && [aLine hasSuffix:@" unexpected"]) || ([aLine rangeOfString:@": warning: unrecognized response "].length > 0 && [aLine hasSuffix:@" from cvs server"]) )
						// Trace option (-t) is ON. Ignore output.
						break;
					// cvs update aborted: stat failed for XXX
					// cvs update aborted: reading from server: Input/output error
					if( statusRequestHasBeenAborted &&
						([aLine rangeOfString:@"stat failed for "].length > 0 || 
						 [aLine hasSuffix:@"reading from server: Input/output error"]) ){
						[self setUpdateAborted:YES 
										reason:aLine 
								  displayAlert:YES];
						break;
					}
					// cvs [server aborted]: -t/-f wrappers not supported by this version of CVS
					if ( statusRequestHasBeenAborted &&
						 ([aLine rangeOfString:@"-t/-f wrappers not supported by this version of CVS"].length > 0) ) {						
						[self setUpdateAborted:YES 
										reason:aLine 
								  displayAlert:NO];
						[self displayCvswappersAlertPanel:aLine];
						break;
					}
				}

				if ( [self checkForNewDirectory:aLine] == YES ) break;
				if ( [self checkForMoveAway:aLine] == YES ) break;
				if ( [self checkForNoLongerInRepository:aLine] == YES ) break;
				if ( [self checkForIsModifiedButNoLongerPertinent:aLine] == YES ) break;
				if ( [self checkForCouldNotFindVersion:aLine] == YES ) break;
				if ( [self checkForNoLongerPertinent:aLine] == YES ) break;
				if ( [self checkForLostFile:aLine] == YES ) break;
				if ( [self checkForConflicts:aLine] == YES ) break;
				if ( [self checkForAccessToHistoryFile:aLine] == YES ) break;
				if ( [self checkForPermissionsDenied:aLine] == YES ) break;
				if ( [self checkForNewBornDisappeared:aLine] == YES ) break;
				if ( [self checkForWrapperOptionMNotSupported:aLine] == YES ) break;

				// In this case, we will perform a full status request
				aMsg = [NSString stringWithFormat:
							  @"Unknown <cvs update> output(1): \"%@\"", aLine];
				SEN_LOG(aMsg);
				
				if ( statusRequestHasBeenAborted )
					[self setUpdateAborted:YES 
									reason:aLine 
							  displayAlert:YES];
                break;
            case 'S':
                if(![aLine hasPrefix:@"S->"]) {
                    // In this case, let's perform a full status request
                    aMsg = [NSString stringWithFormat:
                                  @"Unknown <cvs update> output: %@", aLine];
                    SEN_LOG(aMsg);
                }
                // Else trace option (-t) is ON. Ignore output.
                break;
            default:
            {
                if( ![aLine matchesPattern:@"^(\\s*)->(.*)" options:0] && 
                    ![aLine hasPrefix:@"retrieving revision "] && 
                    ![aLine isEqualToString:@"rcsmerge: warning: conflicts during merge"] && 
                    ![aLine hasPrefix:@"Unknown host "] && 
                    ![aLine isEqualToString:@"No such file or directory"] && 
                    ![aLine hasPrefix:@"cannot change mode for "]) {
                    // In this case, let's perform a full status request
                    aMsg = [NSString stringWithFormat:
                                  @"Unknown <cvs update> output: %@", aLine];
                    SEN_LOG(aMsg);
                }                
                // Else, trace option (-t) is ON. Ignore output.
            }

        }
    }
}

- (NSDictionary *) result
{
    return fileStatuses;
}

#ifdef JA_PATCH
- (void) closeReadHandle
{
    [self readStatusesFromString:parsingBuffer]; // Parse the last line, finally
    RELEASE(parsingBuffer);

    [super closeReadHandle];
}

- (void) closeErrorReadHandle
{
    [self readStatusesFromString:errorParsingBuffer]; // Parse the last line, finally
    RELEASE(errorParsingBuffer);

    [super closeErrorReadHandle];
}

- (void)endWithSuccess;
{
}

- (void)endWithFailure;
{
}
#else
- (void) end
{    
    NSString *aPath = nil;
    CVLFile *aCVLFile = nil;
    
    [self readStatusesFromString:parsingBuffer]; // Parse the last line, finally
    RELEASE(parsingBuffer);

    [self readStatusesFromString:errorParsingBuffer]; // Parse the last line, finally
    RELEASE(errorParsingBuffer);

    // The following code fixes a bug where a refresh of a file in top level
    // folder would perform a status of the whole top level folder. This was due
    // to the top level folder never having the instance variable named
    // statusWasInvalidated set to NO. This little piece of code below fixes 
    // this. Hopefully there are no side effects. Note that the top level folder
    // is called the root file in the CVLFile class.
    // William swats -- 2-Apr-2004
    aPath = [self path];
    aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];
    if ( [aCVLFile isRootFile] == YES ) {
        [aCVLFile setStatus:tokenizedStatus[ECNoStatus]];
    }        
    // End of fix.
    
    [super endWithoutInvalidation];
}
#endif

- (int) priority
{
    return -9; // Higher priority than CvsStatusRequest
}

- (BOOL) updateAborted
{
    return updateAborted;
}

- (void)setUpdateAborted:(BOOL)aState reason:(NSString *)aReason displayAlert:(BOOL)isDisplayed
    /*" This method sets the instance variable named updateAborted to aState. It
        will also display an alert message to the user if the argument
        isDisplayed is YES. Included in the alert message is the reason given in
        the argument aReason.
    "*/
{
    updateAborted = aState;
    if ( isDisplayed == YES ) {
        if ( isNotEmpty(aReason) ) {
            (void)NSRunAlertPanel(@"CVS Quick Status Request", 
                                  @"Sorry, this status request was aborted by CVS. The reason given is:\n\n \"%@\"\n\n  This may indicate that there is corruption in the workarea or in the repository. CVL will attempt to preform a full status request instead. This will take a bit longer.",
                                  nil, nil, nil, aReason);
        } else {
            (void)NSRunAlertPanel(@"CVS Quick Status Request", 
                                  @"Sorry, this status request was aborted by CVS. No reason was given. This may indicate that there is corruption in the workarea or in the repository. CVL will attempt to preform a full status request instead. This will take a bit longer.",
                                  nil, nil, nil);            
        }
    }
}


- (BOOL)checkForNewDirectory:(NSString *)aLine
{
	NSString		*aKey		= nil;
    NSString        *aFilename	= nil;
	
	// cvs XXX: New directory `XXX' -- ignored
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
		@"^o?cvs(.*): New directory .(.*). -- ignored$"
		options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		aKey = [[self path] stringByAppendingPathComponent:aFilename];
		if ( isNotEmpty(aKey) ) {
			[fileStatuses setObject:@"u" forKey:aKey];
			return YES;
		}
	}
	return NO;
}

- (BOOL)checkForMoveAway:(NSString *)aLine
{
    NSString        *aFilename	= nil;
	
	// cvs update: move away XXX; it is in the way
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
					@"^o?cvs(.*): move away (.*); it is in the way$"
					options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		// We can ignore this case
		return YES;
	}
	return NO;
}

- (BOOL)checkForNoLongerInRepository:(NSString *)aLine
{
	NSString		*aKey		= nil;
    NSString        *aFilename	= nil;
	
	// cvs update: XXX is no longer in the repository.
	// cvs server: warning: XXX is no longer in the repository.
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
		@"^o?cvs(.*): (.*) is no longer in the repository$" 
		options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		aKey = [[self path] stringByAppendingPathComponent:aFilename];
		if ( isNotEmpty(aKey) ) {
			// Perform full status
			[fileStatuses setObject:@"!" forKey:aKey];
			return YES;
		}
	}
	return NO;
}

- (BOOL)checkForIsModifiedButNoLongerPertinent:(NSString *)aLine
{
	NSString		*aKey		= nil;
    NSString        *aFilename	= nil;
	
	// cvs server: conflict: XXX is modified but no longer in the repository
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
											  @"^o?cvs(.*): conflict: (.*) is modified but no longer in the repository$" 
												   options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		aKey = [[self path] stringByAppendingPathComponent:aFilename];
		if ( isNotEmpty(aKey) ) {
			// Perform full status
			[fileStatuses setObject:@"!" forKey:aKey];
			return YES;
		}
	}
	return NO;
}

- (BOOL)checkForCouldNotFindVersion:(NSString *)aLine
{
	NSString		*aKey		= nil;
    NSString        *aFilename	= nil;
	
	// cvs update aborted: could not find desired version XXX in XXX,v
	// cvs server aborted: could not find desired version XXX in XXX,v
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
		@"^o?cvs(.*) \\[((update)|(server)) aborted\\]: could not find desired version (.*) in (.*),v$" 
		options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		aKey = [[self path] stringByAppendingPathComponent:aFilename];
		if ( isNotEmpty(aKey) ) {
			// In this case, we should warn user, 
			// because local CVS info is inconsistent!!!
			// Also Perform full status
			[fileStatuses setObject:@"!" forKey:aKey]; 
			[self setUpdateAborted:YES 
							reason:aLine 
					  displayAlert:YES];
			return YES;
		}
	}
	return NO;
}

- (BOOL)checkForNoLongerPertinent:(NSString *)aLine
{
	NSString		*aKey		= nil;
    NSString        *aFilename	= nil;
	
	// cvs update: XXX is not (any longer) pertinent
	// cvs server: warning: XXX is not (any longer) pertinent
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
		@"^o?cvs(.*): (warning: )*(.*) is not \\(any longer\\) pertinent$" 
		options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		aKey = [[self path] stringByAppendingPathComponent:aFilename];
		if ( isNotEmpty(aKey) ) {
			// File should become NeedsUpdate
			[fileStatuses setObject:@"U" forKey:aKey];
			return YES;
		}
	}
	return NO;
}

- (BOOL)checkForLostFile:(NSString *)aLine
{
	NSString		*aKey		= nil;
    NSString        *aFilename	= nil;
	
	// cvs XXX: warning: XXX was lost
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
											  @"^o?cvs(.*): warning: (.*) was lost$" 
												   options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		aKey = [[self path] stringByAppendingPathComponent:aFilename];
		if ( isNotEmpty(aKey) ) {
			// File should become NeedsUpdate
			[fileStatuses setObject:@"U" forKey:aKey];
			return YES;
		}
	}
	return NO;
}

- (BOOL)checkForConflicts:(NSString *)aLine
{
	NSString		*aKey		= nil;
    NSString        *aFilename	= nil;
	
	// cvs XXX: conflicts found in XXX
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
		@"^o?cvs(.*): conflicts found in (.*)$"
		options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		aKey = [[self path] stringByAppendingPathComponent:aFilename];
		if ( isNotEmpty(aKey) ) {
			// File should become Conflicted
			[fileStatuses setObject:@"C" forKey:aKey];
			return YES;
		}
	}
	return NO;
}

- (BOOL)checkForAccessToHistoryFile:(NSString *)aLine
{
	// cvs update: Sorry, you don't have read/write access to the history file
	if ( [aLine hasSuffix:@"Sorry, you don't have read/write access to the history file"] == YES ) {
		[self setUpdateAborted:YES 
						reason:aLine 
				  displayAlert:YES];
	}
	return NO;
}

- (BOOL)checkForPermissionsDenied:(NSString *)aLine
{	
	// cvs update: Sorry, you don't have read/write access.
	if ( [aLine rangeOfString:@"Permission denied"].length > 0 ) {
		[self setUpdateAborted:YES 
						reason:aLine 
				  displayAlert:YES];
	}
	return NO;
}

- (BOOL)checkForNewBornDisappeared:(NSString *)aLine
{
	NSString		*aKey		= nil;
    NSString        *aFilename	= nil;
	
	aFilename = [[aLine findAllSubPatternMatchesWithPattern:
		@"^o?cvs(.*): warning: new-born (.*) has disappeared$"
		options:0] lastObject];
	if ( isNotEmpty(aFilename) ) {
		aKey = [[self path] stringByAppendingPathComponent:aFilename];
		if ( isNotEmpty(aKey) ) {
			[fileStatuses setObject:@"A" forKey:aKey];
			return YES;
		}
	}
	return NO;
}

- (BOOL)checkForWrapperOptionMNotSupported:(NSString *)aLine
{
	// cvs update: -m wrapper option is not supported remotely; ignored.
	if ( [aLine rangeOfString:@"-m wrapper option is not supported remotely; ignored"].length > 0 ) {
		// We can ignore this case
		return YES;
	}
	return NO;
}


@end
