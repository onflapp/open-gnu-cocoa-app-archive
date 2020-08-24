/* CvsImportRequest.m created by vincent on Wed 26-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsImportRequest.h"
#import "CvsRepository.h"
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>

@implementation CvsImportRequest

+ (id) cvsImportRequestForSubpath: (NSString*) aRepositorySubpath
                    inRepository: (CvsRepository *)aRepository
                      importPath: (NSString *)aPath
                      releaseTag: (NSString*) rTag
                       vendorTag: (NSString*) vTag
                         message: (NSString*) mesgString
{
    CvsImportRequest* newRequest= [self requestWithCmd:CVS_IMPORT_CMD_TAG title:@"import" path:aPath files: nil];

    [newRequest setRepositorySubpath: aRepositorySubpath];
    [newRequest setReleaseTag: rTag];
    [newRequest setVendorTag: vTag];
    [newRequest setMessage: mesgString];
    [newRequest setRepository:aRepository];

    return newRequest;
}


- (void) dealloc
{
    RELEASE(repositorySubpath);
    RELEASE(releaseTag);
    RELEASE(vendorTag);
    RELEASE(message);
    [super dealloc];
}


- (void) setRepositorySubpath: (NSString*) aString
{
    ASSIGN(repositorySubpath, aString);
}


- (void) setReleaseTag: (NSString*) aString
{
    ASSIGN(releaseTag, aString);
}

- (void) setVendorTag: (NSString*) aString
{
    ASSIGN(vendorTag, aString);
}

- (void) setMessage: (NSString*) aString
{
    ASSIGN(message, aString);
}

- (NSArray *)cvsCommandOptions
{
  return [NSArray arrayWithObjects:@"-m", message, nil];
}


- (NSArray *)cvsCommandArguments
{
    NSArray* arguments = nil;

	if ( isNotEmpty(repositorySubpath) && 
		 isNotEmpty(vendorTag) &&
		 isNotEmpty(releaseTag) ) {
		arguments = [NSMutableArray arrayWithObjects:repositorySubpath, vendorTag, releaseTag, nil];		
	}
    return arguments;
}

- (NSString *)cvsWorkingDirectory
{
    return [self path];
}

#ifdef JA_PATCH
- (void)endWithSuccess;
{
}

- (void)endWithFailure;
{
}
#else

- (void) end
{
	NSString	*aTitle			= nil;
    BOOL		 showError		= NO;
    BOOL		 showWarning	= NO;
	
	if ( isNotEmpty(completeErrorMsgString) ) {
		showError = [self didGenerateAnError];
		showWarning = [self didGenerateAWarning];

		if ( (showError == YES) || (showWarning == YES)) {
			if ( showError == YES ) {
                aTitle = @"CVS Import Error";
            } else {
				aTitle = @"CVS Import Warning";
            }
			NSRunAlertPanel(aTitle, 
							@"%@\n\nSee the CVL Console for more information.",
							@"OK", nil, nil,
							completeErrorMsgString);            
		} else {
			NSRunAlertPanel(@"CVS Import", 
							@"Import was successful.\n\nSee the CVL Console for more information.",
							@"OK", nil, nil);            			
		}
	}
    [super endWithoutInvalidation];
}
#endif
@end
