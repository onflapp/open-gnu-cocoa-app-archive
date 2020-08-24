/* CvsUpdateRequest.m created by ja on Fri 29-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsUpdateRequest.h"
#import <Foundation/Foundation.h>
#import "CVLUnwrapRequest.h"
#import "CVLFile.h"
#import "NSFileManager_CVS.h"
#import <SenFoundation/SenFoundation.h>
#import <NSString+Lines.h>
#import <CVLConsoleController.h>
#import "WorkAreaViewer.h"
#import "CVLDelegate.h"
#import <CvsRepository.h>


@implementation CvsUpdateRequest


+ (CvsUpdateRequest *)cvsUpdateRequestForFiles:(NSArray *)someFiles inPath:(NSString *)aPath
{
    return [self cvsUpdateRequestForFiles: someFiles inPath: aPath revision: nil date: nil];
}

+ (CvsUpdateRequest *)cvsUpdateRequestForFiles:(NSArray *)someFiles inPath:(NSString *)aPath removesStickyAttributes:(BOOL)removesStickyAttributesFlag
{
    return [self cvsUpdateRequestForFiles: someFiles inPath: aPath revision: nil date: nil removesStickyAttributes:removesStickyAttributesFlag];
}

+ (CvsUpdateRequest *)cvsUpdateRequestForFiles:(NSArray *)someFiles inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate
{
    return [self cvsUpdateRequestForFiles:someFiles inPath:aPath revision:aRevision date:aDate removesStickyAttributes:NO];
}

+ (CvsUpdateRequest *)cvsUpdateRequestForFiles:(NSArray *)someFiles inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate removesStickyAttributes:(BOOL)removesStickyAttributesFlag
{
    NSArray *checkedFiles=nil;
    NSDictionary* pathDict;
    NSString* commonPath;
    CvsUpdateRequest *newRequest;

    if (someFiles) {
        pathDict=[[self class] canonicalizePath: aPath andFiles: someFiles];
        commonPath= [[pathDict allKeys] objectAtIndex: 0];
        checkedFiles= [pathDict objectForKey: commonPath];
    } else {
        commonPath=aPath;
    }

    newRequest=[self requestWithCmd:CVS_UPDATE_CMD_TAG
                              title:@"update" 
                               path: commonPath 
                              files: checkedFiles];
    
    if (aRevision)
    {
        [newRequest setRevision:aRevision];
    }
    if (aDate)
    {
        [newRequest setDate:aDate];
    }
    [newRequest setRemovesStickyAttributes:removesStickyAttributesFlag];
    return newRequest;
}

+ (CvsUpdateRequest *)cvsUpdateRequestForFile:(NSString *)file inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate toFile:(NSString *)fullPath
{
    return [self cvsUpdateRequestForFile:file inPath:aPath revision:aRevision date:aDate removesStickyAttributes:NO toFile:fullPath];
}

+ (CvsUpdateRequest *)cvsUpdateRequestForFile:(NSString *)file inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate removesStickyAttributes:(BOOL)removesStickyAttributesFlag toFile:(NSString *)fullPath
{
    NSDictionary* pathDict= [[self class] canonicalizePath: aPath andFiles: [NSArray arrayWithObject:file]];
    NSString* commonPath= [[pathDict allKeys] objectAtIndex: 0];
    CvsUpdateRequest *newRequest;

    newRequest=[self requestWithCmd:CVS_UPDATE_CMD_TAG
                              title:@"update" 
                               path: commonPath 
                              files: [pathDict objectForKey: commonPath]];
    [newRequest setIsQuiet: NO];
    if (aRevision)
    {
        [newRequest setRevision:aRevision];
    }
    if (aDate)
    {
        [newRequest setDate:aDate];
    }
    [newRequest setDestinationFilePath:fullPath];
    [newRequest setRemovesStickyAttributes:removesStickyAttributesFlag];
    return newRequest;
}

- (void)dealloc
{
    RELEASE(parsingBuffer);
    RELEASE(destinationFile);
    RELEASE(revision);
    RELEASE(date);
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

- (void)setRevision:(NSString *)aRevision
{
    ASSIGN(revision, aRevision);
}

- (void)setDate:(NSString *)aDate
{
    ASSIGN(date, aDate);
}

- (void) setRemovesStickyAttributes:(BOOL)flag
{
    removesStickyAttributes = flag;
}

- (void)setDestinationFilePath:(NSString *)fullPath
{
    ASSIGN(destinationFile, fullPath);
}

- (NSString *) destinationFilePath
{
    return destinationFile;
}

- (id)outputFile
{
    if (destinationFile) {
      NSFileHandle *file = nil;
      NSFileManager* fileManager= [NSFileManager defaultManager];
	  CVLDelegate *theAppDelegate = nil;
	  NSDictionary *theFileAttributes = nil;
	  NSString *theDestinationDirectory = nil;
	  BOOL isSuccessful = NO;
	  BOOL isDirectory = NO;

	  theAppDelegate = [NSApp delegate];
	  
      // Stephane: there is currently a bug with cvs and wrappers: wrappers are not restored correctly
      // when doing an update with date or revision or tag: they are still wrapped (gnutar-gzipped)!!
      // What we could do is trying to gunzip and gnutar xf them...
      if (![fileManager senFileExistsAtPath: destinationFile isDirectory:&isDirectory] || isDirectory)
      {
          if ( isDirectory == YES ) {
			  [fileManager removeFileAtPath:destinationFile handler:theAppDelegate]; // We are in troubles when it fails (permissions)...
		  }
		  // theFileAttributes = o700
		  theFileAttributes = [NSDictionary 
						dictionaryWithObject: [NSNumber numberWithInt: 448]
									  forKey: NSFilePosixPermissions];
		  theDestinationDirectory = [destinationFile 
										  stringByDeletingLastPathComponent];
		isSuccessful = [fileManager createAllDirectoriesAtPath:theDestinationDirectory
										            attributes:theFileAttributes];
		if ( isSuccessful == YES ) {
			isSuccessful = [fileManager createFileAtPath:destinationFile
												 contents:nil
											  attributes:theFileAttributes];
		}
		if ( isSuccessful == NO ) {
			(void)NSRunAlertPanel(@"File Error", 
                            @"CVL was not able to create the file at path \"%@\" with attributes of \"%@\".", 
                            @"OK", nil, nil, destinationFile, theFileAttributes);        
		}                                      
		// Stephane: could it be here that we have problems with NFS?
      }
      file=[NSFileHandle fileHandleForWritingAtPath:destinationFile];
      if (file) {
          [file truncateFileAtOffset:0];
        return file;
      } else {
        return nil;
      }
    } else {
      return [super outputFile];
    }
}


- (NSArray *)cvsOptions
{
    NSArray		*previousOptions = [super cvsOptions];
    NSArray		*newOptions = nil;
    NSNumber	*aCompressionLevel = [repository compressionLevel];

    if( [aCompressionLevel intValue] > 0 )
        newOptions = [NSArray arrayWithObjects:@"-q", [NSString stringWithFormat:@"-z%@", aCompressionLevel], nil];

    if(newOptions)
        return [previousOptions arrayByAddingObjectsFromArray:newOptions];
    else
        return [previousOptions arrayByAddingObject:@"-q"];
}


- (NSArray *)cvsCommandOptions
{
    NSMutableArray *options;

    options=[NSMutableArray arrayWithObjects:@"-d", @"-P", nil];
    if (destinationFile)
    {
      [options insertObject: @"-p" atIndex: 0];
    }
    if (revision) {
        [options addObject:@"-r"];
        [options addObject:revision];
    }
    if (date) {
        [options addObject:@"-D"];
        [options addObject:date];
    }
    if(removesStickyAttributes)
        [options addObject:@"-A"];

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

- (void) unwrapEnd:(NSNotification *)aNotif
{
    // We need to rename the unwrapped file to the destination file
    (void)[[NSFileManager defaultManager] movePath:[[destinationFile stringByDeletingLastPathComponent] stringByAppendingPathComponent:[files lastObject]] toPath:destinationFile handler:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[aNotif name] object:aNotif];
    [super endWithoutInvalidation];
}

#ifdef JA_PATCH
- (void)endWithSuccess;
{
    if (!destinationFile) [self updateFileStatuses];
}

- (void)endWithFailure;
{
    if (!destinationFile) [self updateFileStatuses];
}
#else
- (void)end
{
    [self parseUnremovedNibsFromString:parsingBuffer];
    [parsingBuffer release];
    parsingBuffer = nil;
    
    if (destinationFile)
    {
        // In case of destinationFile, there is only one input file
        if(![[NSUserDefaults standardUserDefaults] boolForKey:@"DisableUnwrap"] && [(CVLFile *)[CVLFile treeAtPath:[[self path] stringByAppendingPathComponent:[[self files] lastObject]]] isRealWrapper]){
            CVLUnwrapRequest	*unwrapRequest = [CVLUnwrapRequest unwrapRequestForWrapper:destinationFile];

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unwrapEnd:) name:@"RequestCompleted" object:unwrapRequest];
            [unwrapRequest schedule];
        }
        else
            [super endWithoutInvalidation];
    }
    else
    {
        [super end];
    }
}
#endif

- (BOOL) setUpTask
    /*" This method calls supers implementation and if that returns YES then 
        this method finishes the setup of this task. If supers implementation
        returns NO then this method returns NO. Here we are only setting up a 
        parsing buffer so that we can catch error messages from the CVS update 
        command.
    "*/
{
    if( [super setUpTask] == YES ) {
        parsingBuffer = [[NSMutableString alloc] init];
        return YES;
    }
    return NO;
}

- (void) parseOutput:(NSString *)data
    /*" This method appends the string named data to the parsing buffer.
    "*/
{
    [parsingBuffer appendString:data];
}

- (void)parseError:(NSString *)data
    /*" This method appends the new error data to the parsing buffer and then 
        calls super's implementation.
    "*/
{    
    [parsingBuffer appendString:data];
    [super parseError:data];
}


- (void) parseUnremovedNibsFromString:(NSString *)aString
    /*" This method takes the error output of this command (in the form of a string) 
        and searches for an error message indicating that CVS was not able to 
        remove a nib file. This occurs because CVS thinks that the nib is a 
        file, since it has been wrapped before it is put into the repository, 
        however the nib is actually a directory. Hence CVS issues the wrong 
        commands in trying to delete it and therefore it fails. This method finds
        these nibs and then deletes them correctly. Then an update is issued to 
        the parent directory of these nibs so that the CVL browser displays them
        properly.
    "*/
{
    NSString *aLine = nil;
    NSString *aFilename = nil;
    NSString *aPath = nil;
    NSString *aConsoleMessage = nil;
    CVLFile *aCVLFile = nil;
    NSArray	*lines = nil;
    NSArray	*regexMatches = nil;
    NSMutableArray *someCVLFiles = nil;
    NSFileManager *fileManager = nil;
    CVLDelegate *theAppDelegate = nil;
    WorkAreaViewer *aWorkAreaViewer = nil;
    CvsUpdateRequest *anUpdateRequest = nil;
    unsigned int anIndex = 0;
    unsigned int aLineCount = 0;
    unsigned int aCount = 0;
    BOOL isNibDeleted = NO;

    fileManager = [NSFileManager defaultManager];

    lines = [aString lines];

    // Now we loop thru looking for the ones like this:
    // cvs update: unable to remove Folder 1/English.lproj/CVLRename.nib: Operation not permitted
    aLineCount = [lines count];
    for (anIndex = 0; anIndex < aLineCount; anIndex++) {
        aLine = [lines objectAtIndex:anIndex];
        regexMatches = [aLine findAllSubPatternMatchesWithPattern:
                   @"^o?cvs(.*): unable to remove (.*): Operation not permitted$" 
                                                          options:0];
        if ( isNotEmpty(regexMatches) ) {
            aFilename = [regexMatches lastObject];
            if ( isNotEmpty(aFilename) &&
                 ([[aFilename pathExtension] isEqualToString:@"nib"] == YES) ) {
                // Found a nib file.
                aPath = [[self path] stringByAppendingPathComponent:aFilename];
                aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];
                // Check to make sure it was wrapped.
                if ( [aCVLFile isRealWrapper] == YES ) {
                    // Yes it was, now delete it.
                    isNibDeleted = [fileManager removeFileAtPath:aPath handler:nil];
                    // If successful save its CVLFile object in an array for
                    // later updating.
                    if ( isNibDeleted == YES ) {
                        if ( someCVLFiles == nil ) {
                            someCVLFiles = [NSMutableArray arrayWithCapacity:1];
                        }
                        [someCVLFiles addObject:[aCVLFile parent]];
                    }
                }                
            }
        }
    }
    // Write a message to the CVL console saying what we are doing.
    if ( isNotEmpty(someCVLFiles) ) {
        aCVLFile = [someCVLFiles objectAtIndex:0];
        aCount = [someCVLFiles count];
        if ( aCount == 1 ) {
            aConsoleMessage = [NSString stringWithFormat:
                @"The nib file \"%@\" could not be removed by CVS since it is a wrapped directory, so CVL will delete it and then run an update request on its parent so that it will disappear from the CVL browser.\n", 
                [aCVLFile path]];
        } else {
            aConsoleMessage = [NSString stringWithFormat:
                @"There were %d nib files that could not be removed by CVS since they were wrapped directories, so CVL will delete them and then run an update request on their parents so that they will disappear from the CVL browser.\n", 
                aCount];
        }
        [[CVLConsoleController sharedConsoleController] output:aConsoleMessage 
                                                          bold:YES];
        // Issue a new update request so that the CVL browser is updated
        // correctly. If we do not do this then empty directories will be left
        // lying around.
        theAppDelegate = [NSApp delegate];        
        aWorkAreaViewer= [theAppDelegate viewerShowingFile:aCVLFile];
        anUpdateRequest = [aWorkAreaViewer returnAnUpdateRequestForEmptyDirectories:someCVLFiles];
        if ( anUpdateRequest != nil ) {
            [anUpdateRequest schedule];
        }
    }        
}

- (NSMutableDictionary *)descriptionDictionary
    /*" This method returns a description of this instance in the form of a 
        dictionary. The keys are the names of the instance variables and the 
        values are the values of those instance variables. The keys return here 
        the keys from super's implementation plus destinationFile, revision, 
        date and the removesStickyAttributes.

        See also #{descriptionDictionary} in superclass CvsRequest.
    "*/
{
    NSMutableDictionary* aDescriptionDictionary = nil;
        
    aDescriptionDictionary = [super descriptionDictionary];
    [aDescriptionDictionary setObject:(destinationFile ? destinationFile : @"nil") 
                               forKey:@"destinationFile"];
    [aDescriptionDictionary setObject:(revision ? revision : @"nil") 
                               forKey:@"revision"];
    [aDescriptionDictionary setObject:(date ? date : @"nil") 
                               forKey:@"date"];
    [aDescriptionDictionary setObject:(removesStickyAttributes ? @"YES" : @"NO") 
                               forKey:@"removesStickyAttributes"];

    return aDescriptionDictionary;
}


@end
