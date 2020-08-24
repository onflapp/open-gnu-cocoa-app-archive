/* CvsCheckoutRequest.m created by vincent on Wed 26-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsCheckoutRequest.h"
#import <CvsRepository.h>
#import <Foundation/Foundation.h>
#import <CvsModule.h>
#import <CVLFile.h>
#import <CVLDelegate.h>
#import <CvsEntry.h>
#import <SenFoundation/SenFoundation.h>


@implementation CvsCheckoutRequest

+ (CvsCheckoutRequest *)cvsCheckoutRequestForModule:(NSString *)module inRepository:(CvsRepository *)aRepository toPath:(NSString *)aPath
{
    return [self cvsCheckoutRequestForModule:module inRepository:aRepository toPath:aPath revision:nil date:nil];
}

+ (CvsCheckoutRequest *)cvsCheckoutRequestForModule:(NSString *)module inRepository:(CvsRepository *)aRepository toPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate
{
    return [self cvsCheckoutRequestForModule:module inRepository:aRepository toPath:aPath revision:aRevision date:aDate removesStickyAttributes:NO];
}

+ (CvsCheckoutRequest *)cvsCheckoutRequestForModule:(NSString *)module inRepository:(CvsRepository *)aRepository toPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate removesStickyAttributes:(BOOL)removesStickyAttributesFlag
{
    CvsCheckoutRequest *request;

    if ( (request=[self requestWithCmd:CVS_CHECKOUT_CMD_TAG title:@"checkout" path:aPath files:[NSArray arrayWithObject: module]]) ) {
        [request setRepository:aRepository];
        [request setRevision:aRevision];
        [request setDate:aDate];
        [request setRemovesStickyAttributes:removesStickyAttributesFlag];
    }

    return request;
}
/*
+ (id) cvsCheckoutRequestForFile: (NSString*) aFile inPath: (NSString*) aPath
{
    CvsCheckoutRequest *request;

    if (request=[self requestWithCmd:CVS_CHECKOUT_CMD_TAG title:@"checkout" path:aPath files: [NSArray arrayWithObject: aFile]])
            [request setRepository:[CvsRepository defaultRepository]];

        return request;
}

+ (id) cvsCheckoutRequestForFile: (NSString*) aFile inDestinationPath: (NSString*) aDestinationPath;
// allow checkout with another dir name
// Stephane: this method is currently NOT used, is it?
// Perhaps we should add a textField in checkout panel to allow new name...
// Or we could check if given path exists: if it doesn't, it means that user wants
// to rename the destination path.
{
    CvsCheckoutRequest* newRequest;

    newRequest=[self requestWithCmd:CVS_CHECKOUT_CMD_TAG
                              title:@"checkout"
                               path: [aDestinationPath stringByDeletingLastPathComponent]
                              files: [NSArray arrayWithObject: aFile]];
    if (newRequest) {
        [newRequest setDestinationPath: aDestinationPath];
        [newRequest setRepository:[CvsRepository defaultRepository]];
    }
    return newRequest;
}
*/

+ (CvsCheckoutRequest *)cvsUpdateRequestForFile:(NSString *)aFile inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate removesStickyAttributes:(BOOL)removesStickyAttributesFlag toFile:(NSString *)fullPath
	/*" For some unknown reason the pipe feature no longer works for wrapper 
		files from pserver repositories. Hence we are using a checkout
		request to a temporary directory to work around this problem.
	"*/
{
	CVLFile *aCVLFile = nil;
	NSString *aFullPath = nil;
	NSString *aFilename = nil;
    NSDictionary* pathDict= [[self class] canonicalizePath: aPath andFiles: [NSArray arrayWithObject:aFile]];
    NSString* commonPath= [[pathDict allKeys] objectAtIndex: 0];
    NSString* thePathInRepository = nil;
    CvsCheckoutRequest *newRequest = nil;
	NSArray  *someFiles = nil;
	
	aFullPath = [aPath stringByAppendingPathComponent:aFile];
	aCVLFile = (CVLFile *)[CVLFile treeAtPath:aFullPath];
	thePathInRepository = [aCVLFile pathInRepository];
	SEN_ASSERT_NOT_NIL(thePathInRepository);
	someFiles = [NSArray arrayWithObject:thePathInRepository];
    newRequest=[self requestWithCmd:CVS_CHECKOUT_CMD_TAG
                              title:@"update" 
                               path:commonPath 
                              files:someFiles];

    [newRequest setIsQuiet: NO];
    if (aRevision)
    {
        [newRequest setRevision:aRevision];
    }
    if (aDate)
    {
        [newRequest setDate:aDate];
    }
	// we are updating a CvsWrappers file then put the results into
	// a temporary directory.
	// Cycle thru names such as tmp, tmp-1, tmp-2
	// etc until we find one that does not exist. Return that one.
	// But give up after 10,000 tries.
	aFilename = [NSString uniqueFilenameWithPrefix:@"tmp" 
									   inDirectory:aPath];
	if ( aFilename == nil ) {
		(void)NSRunAlertPanel(@"CVL File Error", 
							  @"Sorry, could not create a temporary directory \"tmp\" in the directory \"%@\". Tried 10,000 times and failed. Giving up.",
							  nil, nil, nil, aPath);
		return nil;
	}
	
    [newRequest setDestinationPath:aFilename];
    [newRequest setFinalDestinationPath:fullPath];
    [newRequest setRemovesStickyAttributes:removesStickyAttributesFlag];
    [newRequest setFetchingACvsWrappersFile:YES];
	
    return newRequest;
}

- (NSString *)module
{
    return [files objectAtIndex:0];
}

- (void) dealloc
{
    RELEASE(destinationPath);
    RELEASE(finalDestinationPath);	
    RELEASE(revision);
    RELEASE(date);
    [super dealloc];    
}

- (void) setDestinationPath: (NSString*) aString
{
    ASSIGN(destinationPath, aString);
}

- (NSString*) destinationPath
{
    if (destinationPath)
    {
        return [[self path] stringByAppendingPathComponent:destinationPath];
    }
    else{
        NSString	*moduleName = [files objectAtIndex:0];
        CvsModule	*aModule = [repository moduleWithSymbolicName:moduleName];

        if(aModule)
            return [[self path] stringByAppendingPathComponent:[aModule outputDirectoryName]];
        else
            // It may happen that modules are not defined in <modules> file. It is not an error.
            return [[self path] stringByAppendingPathComponent:moduleName];
    }
}


- (NSArray *) cvsOptions
{
    NSArray			*previousOptions = [super cvsOptions];
    NSMutableArray	*newOptions = nil;
    NSNumber		*aCompressionLevel = [repository compressionLevel];

    if( [aCompressionLevel intValue] > 0 )
        newOptions = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"-z%@", aCompressionLevel]];
    if(readOnly) {
        if(newOptions)
            [newOptions addObject:@"-r"];
        else
            newOptions = [NSMutableArray arrayWithObject:@"-r"];        
    }

    if(newOptions)
        return [previousOptions arrayByAddingObjectsFromArray:newOptions];
    else
        return previousOptions;
}


- (NSArray *)cvsCommandOptions
{
    NSMutableArray *options;

    options=[NSMutableArray array];

    [options addObject:@"-P"]; // Prune (remove) empty directories
    
    if (revision && ![revision isEqual:@""]) {
        [options addObject:@"-r"];
        [options addObject:revision];
    }
    if (date && ![date isEqual:@""]) {
        [options addObject:@"-D"];
        [options addObject:date];
    }
    if (destinationPath)
    {
        [options addObject:@"-d"];
        [options addObject:[destinationPath lastPathComponent]];
    }
    if(removesStickyAttributes)
        [options addObject:@"-A"];

    return options;
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

- (NSArray *)cvsCommandArguments
{
    return [self files];
}

- (NSString *)cvsWorkingDirectory
{
    return [self path];
}

- (void) setIsReadOnly:(BOOL)flag
{
    readOnly = flag;
}

- (BOOL)fetchingACvsWrappersFile
    /*" This is the get method for the instance variable 
		fetchingACvsWrappersFile. This instance variable is used to indicate 
		that a cvs wrapper file is being fetched for use in replacing a file in
		the workarea with another version or saving another version in the file 
		system or opening another version in the temporary directory for 
		viewing. Here we replacing a version not restoring a version. The 
		difference is that replacement means that the sticky attributes of a 
		file are not changed.

		See also #{-setFetchingACvsWrappersFile:}
    "*/
{
    return fetchingACvsWrappersFile;
}

- (void)setFetchingACvsWrappersFile:(BOOL)flag
    /*" This is the set method for the instance variable 
		fetchingACvsWrappersFile. This instance variable is used to indicate 
		that a cvs wrapper file is being fetched for use in replacing a file in
		the workarea with another version or saving another version in the file 
		system or opening another version in the temporary directory for 
		viewing. Here we replacing a version not restoring a version. The 
		difference is that replacement means that the sticky attributes of a 
		file are not changed.

		See also #{-fetchingACvsWrappersFile}
    "*/
{
    fetchingACvsWrappersFile = flag;
}

- (NSString *)finalDestinationPath
    /*" This is the get method for the instance variable 
		finalDestinationPath. This instance variable is used to indicate where a
		cvs wrapper file that is being fetched is to be placed. Note that this 
		instance variable is needed since the initial location of the cvs 
		wrapper file is in a temporary directory in the workarea which will 
		deleted after the cvs wrapper file is moved to this final destination.

		See also #{-setFinalDestinationPath:}
    "*/
{
    return finalDestinationPath; 
}

- (void)setFinalDestinationPath:(NSString *)newFinalDestinationPath
    /*" This is the set method for the instance variable 
		finalDestinationPath. This instance variable is used to indicate where a
		cvs wrapper file that is being fetched is to be placed. Note that this 
		instance variable is needed since the initial location of the cvs 
		wrapper file is in a temporary directory in the workarea which will 
		deleted after the cvs wrapper file is moved to this final destination.

		See also #{-finalDestinationPath}
    "*/
{
    if (finalDestinationPath != newFinalDestinationPath) {
        [newFinalDestinationPath retain];
        [finalDestinationPath release];
        finalDestinationPath = newFinalDestinationPath;
    }
}

#ifdef JA_PATCH

- (void)endWithSuccess;
{
    if ( fetchingACvsWrappersFile == NO ) [self updateFileStatuses];
}

- (void)endWithFailure;
{
    if ( fetchingACvsWrappersFile == NO ) [self updateFileStatuses];
}

#else

- (void)end
	/*" This method will normally just call super's implemenation. However in 
		the case of a cvs wrapper file this method does the following:
		_{1.	Moves the checkout file from the temporary directory in the 
			workarea to the final destination.}
		_{2.	Deletes the temporary directory in the workarea.}
		_{3.	Deletes the temporary directory in the CVS/Entries file in the 
			workarea.}
	"*/
{
    
    if ( fetchingACvsWrappersFile == YES ) {
		NSFileManager	*fileManager = nil;
		NSString *theDestinationPath = nil;
		NSString *aSingleFilePath = nil;
		NSString *aSingleFilename = nil;
		NSString *theFinalDestinationPath = nil;
		NSString *theFinalDestinationDirectory = nil;
		NSString *theDestinationDirectory = nil;
		CVLDelegate *theAppDelegate = nil;
		BOOL			doesExists = NO;
		BOOL			isSuccessful = YES;

		fileManager = [NSFileManager defaultManager];
        theAppDelegate = [NSApp delegate];
		aSingleFilePath = [self singleFile];
		if ( aSingleFilePath != nil ) {
			aSingleFilename = [aSingleFilePath lastPathComponent];
			if ( aSingleFilename != nil ) {
				theDestinationPath = [[self destinationPath] 
								stringByAppendingPathComponent:aSingleFilename];
			}
		}
		theFinalDestinationPath = [self finalDestinationPath];

		// Make sure the final destination directory exists, otherwise the copy
		// operation below will fail.
		theFinalDestinationDirectory = [theFinalDestinationPath stringByDeletingLastPathComponent];
		[fileManager createAllDirectoriesAtPath:theFinalDestinationDirectory 
									 attributes:nil];
		
		// Delete final destination file in case it exists so that we do not get a
		// failure later when creating it.
		if ( isNotEmpty(theFinalDestinationPath) ) {
			doesExists = [fileManager senFileExistsAtPath:theFinalDestinationPath];
			if ( doesExists == YES ) {
				isSuccessful = [fileManager removeFileAtPath:theFinalDestinationPath 
													 handler:theAppDelegate];
			}			
		}
		
		// Copy to the final destination.
		if ( isSuccessful == YES ) {
			if ( isNotEmpty(theDestinationPath) && 
				 isNotEmpty(theFinalDestinationPath) ) {
				(void)[fileManager copyPath:theDestinationPath
									 toPath:theFinalDestinationPath 
									handler:theAppDelegate];			
			}			
		}

		// Delete the tmp directory.
		theDestinationDirectory = [theDestinationPath stringByDeletingLastPathComponent];
		if ( isNotEmpty(theDestinationDirectory) ) {
			(void)[fileManager removeFileAtPath:theDestinationDirectory
										handler:theAppDelegate];			
		}
		// Delete the /tmp entry in the CVS/Entries file.
		[CvsEntry removeCvsEntryWithFilename:destinationPath
							   fromDirectory:[self path]];
    }
	[super end];
}

#endif

- (void)parseError:(NSString *)aString
	/*" This method catches the cvs wrappers error and displayes an alert panel 
		to the user.
	"*/
{
	if ( ([aString hasPrefix:@"cvs"] || [aString hasPrefix:@"ocvs"]) && 
		 ([aString rangeOfString:@"checkout aborted"].length > 0 || 
		  [aString rangeOfString:@"server aborted"].length > 0) ) {
		if ( [aString rangeOfString:@"-t/-f wrappers not supported by this version of CVS"].length > 0 ) {
			[self displayCvswappersAlertPanel:aString];
		}
	}
}


@end
