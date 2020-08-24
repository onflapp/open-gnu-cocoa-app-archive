/* CvsRepository.m created by vincent on Thu 13-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsRepository.h"
#import <CvsCheckoutRequest.h>
#import "ResultsRepository.h"
#import "CVLFile.h"
#import <AppKit/AppKit.h>
#import <CvsModule.h>
#import "CVLDelegate.h"
#import <NSString+Lines.h>
#import "NSString+CVL.h"
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>


static NSMutableDictionary* repositories= nil;
static CvsRepository * nullRepository=nil;
static NSMutableSet * repositoriesToRemove=nil;
static NSDictionary* repositoryClasses=nil;


@interface CvsRepository (Private)
+ (NSString*) repositoriesSupportDirectory;
+ (NSString*) rootAtPath: (NSString*)aPath;
+ (CvsRepository *)repositoryWithWorkAreaAtPath:(NSString *)aPath;
+ (NSDictionary *)repositories;
- (CvsRepository *)initNullRepository;
- (void) doCheckout;
- (void)setCVSROOTWorkAreaPath:(NSString *)thePath;
- (NSArray *) arrayByBuildingBaseIgnoreWildCards;
- (NSArray *) arrayByBuildingBaseWrapperWildCards;
- (void) checkoutEnded:(NSNotification *)notification;
- (void) registerDir:(NSString *)dirPath;
- (void) invalidateControlledDirs;
- (void) invalidateCaches;
@end

/*
 We could make a category on NSNotificationCenter to add -addObserver:selector:name:repository:
 to be able to observe all notifications sent by a specific repository, for specific actions.
 */

@implementation CvsRepository
+ (void)initialize
{
    if(!repositoryClasses){
        [[NSNotificationCenter defaultCenter]
                  addObserver:self
                     selector:@selector(applicationWillTerminate:)
                         name:NSApplicationWillTerminateNotification
                       object:NSApp];

        repositoryClasses=[[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RepositoryClasses" ofType:@"plist"]];
        if (!repositoryClasses) {
            NSString *aMsg = [NSString stringWithFormat:
                    @"Warning: cannot open repository classes property list"];
            SEN_LOG(aMsg);
        }
    }
}

+ (NSArray *) registeredRepositories
{
    return [[self repositories] allValues];
}

+ (CvsRepository *) repositoryWithRoot:(NSString *)aRepositoryRoot
{
    CvsRepository *result=nil;
    NSString *theMethod;
    
    if (!aRepositoryRoot) {
        return [self nullRepository];
    }
    // Stephane: could we allow [NSString defaultCStringEncoding] or NSUTF8StringEncoding ?
    if (![aRepositoryRoot canBeConvertedToEncoding:NSASCIIStringEncoding]) {
        NSString *aMsg = [NSString stringWithFormat:
                @"Assertion failed: repository root not ascii"];
        SEN_LOG(aMsg);        
        return nil;
    }
    result=[[self repositories] objectForKey:aRepositoryRoot];
    if (!result) {
        if ([aRepositoryRoot rangeOfString:@":"].length==1) {
			// Contains a leading colon.
            NSArray *matchingResult=[aRepositoryRoot findAllSubPatternMatchesWithPattern:@"^:(\\w*):(.+)$" options:AGRegexMultiline];
            if ([matchingResult count]==2) {
				// The access method should be at index 0.
                theMethod=[matchingResult objectAtIndex:0];
            } else {
				(void)NSRunAlertPanel(@"CVL Repositories", 
									  @"Encountered a repository root string that we cannot interpert. We are assuming an access method of type \"ext\". This may not be correct. CVL may misbehave after this. The root string in question was \"%@\".",
									  nil, nil, nil, aRepositoryRoot);            
                theMethod=@"ext";
            }
        } else {
			// Does not contain a leading colon. We are assuming then that this 
			// is a local repository.
            theMethod=@"local";
        }
        result=[[[self repositoryClassForMethod:theMethod] alloc] initWithMethod:theMethod root:aRepositoryRoot]; 

        [result autorelease];
    }

    return result;
}

+ (CvsRepository *)nullRepository
{
    if (!nullRepository) {
        nullRepository=[[self alloc] initNullRepository];
    }

    return nullRepository;
}

- (BOOL) isNullRepository
    /*" This method returns YES if this object is the Null repository. Otherwise
        NO is returned.
    "*/
{
    if ( self == [[self class] nullRepository] ) {
        return YES;
    }
    return NO;
}

+ (CvsRepository *) defaultRepository;
	/*" This class method returns the CvsRepository instance that was last 
		selected in the repository viewer. This selection is even maintained 
		across application launches by saving the root instance variable in the 
		user defaults. If there is no root instance saved in the user defaults 
		then this method checks to see if an environment variable by the name of
		CVSROOT is set. If so then the value of this environment variable is 
		used as the root instance variable for the getting the default 
		CvsRepository. If a root instance variable is not found 
		then this method returns nil.
	"*/
{
	NSString* theDefaultCVSRoot= nil;
	CvsRepository *theDefaultRepository = nil;
	NSUserDefaults *theUserDefaults = nil;

    theUserDefaults = [NSUserDefaults standardUserDefaults];		
	theDefaultCVSRoot= [theUserDefaults stringForKey:@"CVSRoot"];
	if ( isNilOrEmpty(theDefaultCVSRoot) ) {
		theDefaultCVSRoot= [[[NSProcessInfo processInfo] environment] objectForKey: @"CVSROOT"];
	}
	if ( isNotEmpty(theDefaultCVSRoot) ) {
		theDefaultRepository = [self repositoryWithRoot:theDefaultCVSRoot];
	}
	return theDefaultRepository;
}

+ (void) setDefaultRepository:(CvsRepository *)aCvsRepository
	/*" This class method sets the root instance variable of the repository in 
		the argument aCvsRepository in the user defaults under the key 
		"CVSRoot". If aCvsRepository is nil or is a Null repository then the 
		user default for "CVSRoot" is removed. This user default is used later 
		to retrieve the default repository using the method -defaultRepository.
	"*/
{
	NSUserDefaults *theUserDefaults = nil;
	NSString* theDefaultCVSRoot= nil;

	theUserDefaults = [NSUserDefaults standardUserDefaults];			
	if ( (aCvsRepository != nil) &&
		 ([aCvsRepository isNullRepository] == NO) ) {
		theDefaultCVSRoot = [aCvsRepository root];
		if ( isNotEmpty(theDefaultCVSRoot) ) {
			[theUserDefaults setObject:theDefaultCVSRoot forKey:@"CVSRoot"];
		} else {
			[theUserDefaults removeObjectForKey:@"CVSRoot"];
		}
	} else {
		[theUserDefaults removeObjectForKey:@"CVSRoot"];
	}
}

+ (NSString *)rootForProperties:(NSDictionary *)properties;
{
    NSString *aRepositoryRoot;

    aRepositoryRoot=[properties objectForKey:ROOT_KEY];
    if (aRepositoryRoot) {
        return aRepositoryRoot;
    } else {
        return nil;
    }
}

+ (CvsRepository *) repositoryWithProperties:(NSDictionary *)thePropertiesDictionary
	/*" This method returns a CvsRepository, or one of its subclasses, based on 
		the repository properties contained in thePropertiesDictionary.
	"*/
{
    NSString *theMethod = nil;;
    NSString *aRepositoryRoot = nil;
    NSNumber *aCompressionLevel = nil;
    CvsRepository *aRepository = nil;
    
    theMethod=[thePropertiesDictionary objectForKey:METHOD_KEY];
    if (!theMethod) {
        NSString *aMsg = nil;
        aRepositoryRoot=[thePropertiesDictionary objectForKey:ROOT_KEY];
        if ( isNotEmpty(aRepositoryRoot) ) {
            aRepository = [self repositoryWithRoot:aRepositoryRoot];
        } else {
			aMsg = [NSString stringWithFormat:
						   @"Assertion failed: no method in thePropertiesDictionary for repository"];
			SEN_LOG(aMsg);        
		}
    } else {
        aRepositoryRoot=[[self repositoryClassForMethod:theMethod] rootForProperties:thePropertiesDictionary];
        if ( isNotEmpty(aRepositoryRoot) ) {
			// Stephane: could we allow [NSString defaultCStringEncoding] ?
			if (![aRepositoryRoot canBeConvertedToEncoding:NSASCIIStringEncoding]) {
				NSString *aMsg = [NSString stringWithFormat:
										 @"Assertion failed: repository root not ascii"];
				SEN_LOG(aMsg);
				return nil;
			}
			aRepository=[[self repositories] objectForKey:aRepositoryRoot];
			if (!aRepository) {
				aRepository=[[[[self repositoryClassForMethod:theMethod] alloc] initWithProperties:thePropertiesDictionary] autorelease];
			}
		}		
    }
	if ( aRepository != nil ) {
		NSString	*aPath;
		
		aCompressionLevel = [thePropertiesDictionary objectForKey:COMPRESSION_LEVEL_KEY];
		[aRepository setCompressionLevel:aCompressionLevel];
		aPath = [thePropertiesDictionary objectForKey:CVS_EXECUTABLE_PATH_KEY];
		if(aPath != nil)
			[aRepository setCvsExecutablePath:aPath];
	}
    return aRepository;
}

+ (Class)repositoryClassForMethod:(NSString *)methodName
	/*" This method returns the correct repository class based on the argument of
		methodName. The classes available to be returned are in the property 
		list named "RepositoryClasses.plist". These are CvsLocalRepository, 
		CvsRemoteRepository and CvsPserverRepository. The method names are 
		local, remote, rsh, server, pserver, kserver and bonjour. See the 
		property list for the mapping of the method name to the repository 
		class. If there is not a class for the method name then the 
		CvsRepository class is returned.
	"*/
{
    NSString *className;
    Class repositoryClass;

    className=[repositoryClasses objectForKey:methodName];

    if (className) {
        if ( (repositoryClass=NSClassFromString(className)) ) {  // Look for a class serving our needs
            return repositoryClass;
        }
    }
    return [CvsRepository class];
}

+ (NSString *) cvsRepositoryPathForDirectory:(NSString *)aDirectory
    /*" This method returns the contents (i.e. the repository path) of the 
        Repository file in the CVS directory that resides in aDirectory. For 
        example if the path in aDirectory is "/Users/jdoe/Projects/TestProject"
        then this method would return the contents of 
        "/Users/jdoe/Projects/TestProject/CVS/Repository".
    "*/
{
    NSString        *cvsDirectory = nil;
    NSString        *pathToRepositoryFileInCVSDirectory = nil;
    NSString        *pathToRepositoryFileStandardized = nil;
    NSFileManager   *fileManager = nil;
    NSString        *cvsRepositoryPath = nil;

    cvsDirectory = [aDirectory stringByAppendingPathComponent:@"CVS"];
    pathToRepositoryFileInCVSDirectory = [cvsDirectory stringByAppendingPathComponent:@"Repository"];
    pathToRepositoryFileStandardized = [pathToRepositoryFileInCVSDirectory stringByStandardizingPath];
    
    fileManager = [NSFileManager defaultManager];
    if ([fileManager senFileExistsAtPath:pathToRepositoryFileStandardized]) {
        cvsRepositoryPath = [[self class] rootAtPath:pathToRepositoryFileStandardized];
    }
    
    return cvsRepositoryPath;
}

+ (NSString *) cvsRootPathForDirectory:(NSString *)aDirectory
    /*" This method returns the contents (i.e. the root path) of the 
        Root file in the CVS directory that resides in aDirectory. For 
        example if the path in aDirectory is "/Users/jdoe/Projects/TestProject"
        then this method would return the contents of 
        "/Users/jdoe/Projects/TestProject/CVS/Root".
    "*/
{
    NSString        *cvsDirectory = nil;
    NSString        *pathToRootFileInCVSDirectory = nil;
    NSString        *pathToRootFileStandardized = nil;
    NSFileManager   *fileManager = nil;
    NSString        *cvsRootPath = nil;
    
    cvsDirectory = [aDirectory stringByAppendingPathComponent:@"CVS"];
    pathToRootFileInCVSDirectory = [cvsDirectory stringByAppendingPathComponent:@"Root"];
    pathToRootFileStandardized = [pathToRootFileInCVSDirectory stringByStandardizingPath];
    
    fileManager = [NSFileManager defaultManager];
    if ([fileManager senFileExistsAtPath:pathToRootFileStandardized]) {
        cvsRootPath = [[self class] rootAtPath:pathToRootFileStandardized];
    }
    
    return cvsRootPath;
}

+ (NSString *) cvsFullRepositoryPathForDirectory:(NSString *)aDirectory
    /*" This method returns the full repository path that is in the Root file 
        and the Repository file in the CVS directory that resides in aDirectory.
        For example if the path in aDirectory is 
        "/Users/jdoe/Projects/TestProject" then this method would return the 
        combined contents of "/Users/jdoe/Projects/TestProject/CVS/Root" and 
        "/Users/jdoe/Projects/TestProject/CVS/Repository" after stripping out 
        any duplicate parts. An example would be /Network/Projects/TestProject. 
        A pserver example would be 
        :pserver:william@boat:/Network/Developer/Repository/TestProject.
    "*/
{
    NSString *cvsFullRepositoryPath = nil;
    NSString *cvsRepositoryPath = nil;
    NSString *cvsRootPath = nil;
    NSString *firstPartOfRepositoryPath = nil;
    NSString *theBeginningOfRootPath = nil;
    NSRange aRange;
    
    if ( isNilOrEmpty(aDirectory) ) return nil;
    
    cvsRepositoryPath = [self cvsRepositoryPathForDirectory:aDirectory];
    cvsRootPath = [self cvsRootPathForDirectory:aDirectory];
    // Get the first part of the string cvsRepositoryPath.
    firstPartOfRepositoryPath = [cvsRepositoryPath substringToIndex:1];
    // Find where this starts in the string cvsRootPath.
    aRange = [cvsRootPath rangeOfString:firstPartOfRepositoryPath];
    // Now check on the location.
    if ( aRange.location == NSNotFound ) {
        // No match found; so return both root and repository.
        cvsFullRepositoryPath = [NSString stringWithFormat:@"%@%@",
            cvsRootPath, cvsRepositoryPath];
    } else if ( aRange.location > 0 ) {
        // Matched and they begin differently; so return part of root and all
        // of repository.
        theBeginningOfRootPath = [cvsRootPath substringToIndex:aRange.location];
        cvsFullRepositoryPath = [NSString stringWithFormat:@"%@%@",
            theBeginningOfRootPath, cvsRepositoryPath];        
    } else {
        // Matched but they begin the same so ignore root and return repository.
        cvsFullRepositoryPath = cvsRepositoryPath;
    }
    return cvsFullRepositoryPath;
}

+ (NSString*) repositoriesSupportDirectory
	/*" This method returns the repositories support directory. This directory 
		contains a directory for each of the repositories that are in the user's 
		repository viewer. The path to this directory is 
		~/Library/Application Support/CVL/Repositories.
	"*/
{
    return [[[NSApp delegate] resourceDirectory] stringByAppendingPathComponent:@"Repositories"];
}

+ (NSDictionary *)repositories
	/*" This class method returns a dictionary of CvsRepositories who have 
		support directories in ~/Library/Application Support/CVL/Repositories/. 
		And whose keys are the root instance variable of the respective repository 
		(e.g :pserver:jdoe@myserver:/Volumes/Volume-1/Repositories/Repository-1).  
	"*/
{
    if ( repositories == nil ) {
        NSArray *repositoriesDirContents;
        NSFileManager *fileManager=[NSFileManager defaultManager];
        id enumerator;
        NSString *aSupportDirectoryName;
        NSString *aSupportDirectory;
        NSString *aCVSROOTWorkAreaPath = nil;
        NSString *theRepositoriesSupportDirectory;
        CvsRepository *loadedRepository;
        
        repositories=[[NSMutableDictionary alloc] init];
        theRepositoriesSupportDirectory=[self repositoriesSupportDirectory];

        repositoriesDirContents=[fileManager directoryContentsAtPath:theRepositoriesSupportDirectory];
        enumerator=[repositoriesDirContents objectEnumerator];
        while ( (aSupportDirectoryName=[enumerator nextObject]) ) {
			aSupportDirectory=[theRepositoriesSupportDirectory 
									stringByAppendingPathComponent:aSupportDirectoryName];
			
			// Only look at the directories in this directory
			// (i.e. there may be other files (e.g. .DS_Store))
			if ( [fileManager senDirectoryExistsAtPath:aSupportDirectory] ) {
				aCVSROOTWorkAreaPath = [aSupportDirectory 
									stringByAppendingPathComponent:@"CVSROOT"];
				loadedRepository=[self 
							repositoryWithWorkAreaAtPath:aCVSROOTWorkAreaPath];
				if ( (loadedRepository != nil) && ([loadedRepository root] != nil) ) {
					[self registerRepository:loadedRepository];
				} else {
					[fileManager removeFileAtPath:[aCVSROOTWorkAreaPath stringByDeletingLastPathComponent] handler:nil];
				}				
			}
        }
    }
    return repositories;
}

+ (void) registerRepository:(CvsRepository *)repository
{
    if (repositoriesToRemove && [repositoriesToRemove containsObject:repository])
        [repositoriesToRemove removeObject:repository];

    if (repository!=nullRepository) {
        // (Stephane) Shouldn't we update the repository ASAP?
//        (void)[repository isUpToDate]; // Forces update of repository
        [repositories setObject:repository forKey:[repository root]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RegisteredRepositoriesChanged" object:self];
    }
}

+ (CvsRepository *)repositoryForPath:(NSString *)path
{
    NSString *previousPath = nil;
    NSString *newPath = nil;
    NSString *cvsRoot;
    CvsRepository *result;

    if ( isNilOrEmpty(path) ) {
        return [CvsRepository nullRepository];
    }
    path=[path stringByStandardizingPath];
    previousPath = [NSString stringWithString:path];

    cvsRoot = [CvsRepository cvsRootPathForDirectory:path];

    result=[CvsRepository repositoryWithRoot:cvsRoot];
    // If the above method returns the Null Repository then
    // this next "while" statement looks at the enclosing directories to see if there
    // is any of them that have a repository that is not the Null Repository.
    // If there is then that one is used. This allows us to exclude the Null 
    // Repositories in the -getChildren method of CVLFile which is a big
    // performance improvement. Without this fix new folders would not have 
    // shown up in the CVS workareas when running CVL.
    // William Swats 7-N0v-2003
    while ( [result isNullRepository] == YES ) {
        newPath = [previousPath stringByDeletingLastPathComponent];
        if ( isNilOrEmpty(newPath) ) break;
        if ( [newPath isEqualToString:previousPath] == YES ) break;
        previousPath = [NSString stringWithString:newPath];
        cvsRoot = [CvsRepository cvsRootPathForDirectory:newPath];
        result=[CvsRepository repositoryWithRoot:cvsRoot];
    }

    [result registerDir:path];

    return result;
}

- (void) enableCvsWrappersOverride:(BOOL)enabled
	/*" This is the method called indirectly whenever the preferences change for
		the preference whose key is OverrideCvsWrappersFileInHomeDirectory. If 
		enabled is YES then this method will create a .cvswrappers link in this 
		repository's support directory to this repository's cvswrappers file in 
		the CVSROOT workarea. It will also create .cvspass, .cvsrc and 
		.cvsignore links in this 
		repository's support directory to this user's home directory if it 
		exists. Then the HOME environment variable will be changed to point to 
		this repository's support directory.

		If enabled is NO then the HOME environment variable will be changed to
		point to this user's home directory.
	"*/
{
	NSString *aCVSROOTWorkAreaPath = nil;
	NSFileManager   *fileManager = nil;
	
	previousOverrideCvsWrappersFileInHomeDirectory = enabled;

	if ( [self isNullRepository] == YES ) return;

	if ( enabled == NO ) {
		[self makeTheUsersHomeTheHomeForThisRepository];
		return;
	}
	
	// Get the directory that contains the cvswappers file.
	aCVSROOTWorkAreaPath = [self CVSROOTWorkAreaPath];
	
	// Check to see if the CVSROOT workarea exist in the 
	// repository support directory.
	fileManager = [NSFileManager defaultManager];
	if ( [fileManager senDirectoryExistsAtPath:aCVSROOTWorkAreaPath] == NO ) {
		[self doCheckout];
		if ( [fileManager senDirectoryExistsAtPath:aCVSROOTWorkAreaPath] == NO ) {
			// If the CVSROOT workarea still does not exist then warn the 
			// user and skip this repository.
			(void)NSRunAlertPanel(@"CVS Wrapper Override Error", 
								  @"Could not create a CVSROOT workarea in the repositories support directory for the repository \"%@\". This repostory will not use the .cvswrappers file in the CVSROOT area of the repository. Instead it will use the .csvwrappers file in your home directory if it exists.",
								  nil, nil, nil, self);
			return;
		}
	}
	
	// Okay; if we get to here then we know that a CVSROOT directory
	// exists for this repository.
	// Link the cvswrappers file in CVSROOT (if it exists) to the .cvswrappers 
	// file in the repository's support directory.
	(void)[self linkCvsWrappersFile];
	// Link the .cvspass file from this user's home directory to the
	// repository's support directory.
	(void)[self linkCvsFile:@".cvspass"];
	(void)[self linkCvsFile:@".cvsrc"];
	(void)[self linkCvsFile:@".cvsignore"];
	// Now change the HOME environment variable for this repository.
	[self makeTheSupportDirectoryTheHomeForThisRepository];
}

- (BOOL)linkCvsWrappersFile
	/*" This is the method called indirectly whenever the preferences change for
		the preference whose key is OverrideCvsWrappersFileInHomeDirectory. This 
		method will create a .cvswrappers link in this	repository's support
		directory to this repository's cvswrappers file in the CVSROOT workarea.
		It is assume here that the CVSROOT workarea already esists.
	"*/
{
	NSString *aCVSROOTWorkAreaPath = nil;
	NSString *aCvsWrappersInCVSROOTPath = nil;
	NSString *theSupportDirectory = nil;
	NSString *aCvsWrappersInSupportDirectoryPath = nil;
	NSFileManager   *fileManager = nil;
	BOOL theFileOrLinkExists = NO;
	BOOL theFileRemoved = NO;
	BOOL linkingResults = NO;
	
	if ( [self isNullRepository] == YES ) return NO;
	// Get the file manager.
	fileManager = [NSFileManager defaultManager];

	// First delete any .cvswrappers file in the support directory just
	// so we know we are starting fresh.
	theSupportDirectory = [self supportDirectory];
	aCvsWrappersInSupportDirectoryPath = [theSupportDirectory 
							stringByAppendingPathComponent:@".cvswrappers"];
	theFileOrLinkExists = [fileManager 
				senFileOrLinkExistsAtPath:aCvsWrappersInSupportDirectoryPath];
	if ( theFileOrLinkExists == YES )  {
		theFileRemoved = [fileManager 
							removeFileAtPath:aCvsWrappersInSupportDirectoryPath
							         handler:nil];
		if ( theFileRemoved == NO ) {
			(void)NSRunAlertPanel(@"CVS Wrapper Override Error", 
								  @"Could not remove the link at \"%@\". This is being done so a new link (possibly the same as this link) can be make to the cvswrappers file in the CVSROOT workarea in this repository's support directory. Will continue, leaving this link in place. This may keep the CVS Wrappers override feature from working correctly. Check the permissions on this link and/or its directory. Then disable and save the override feature and then enable and save the override feature again.",
								  nil, nil, nil, 
								  aCvsWrappersInSupportDirectoryPath);	
			return YES;
		}
	}
	
	// Get the directory that contains the cvswrappers file.
	aCVSROOTWorkAreaPath = [self CVSROOTWorkAreaPath];

	// Check to see if the cvswrappers file exists in CVSROOT.
	aCvsWrappersInCVSROOTPath = [aCVSROOTWorkAreaPath 
							stringByAppendingPathComponent:@"cvswrappers"];
	if ( [fileManager senFileExistsAtPath:aCvsWrappersInCVSROOTPath] ) {
		// Link this file to .cvswrappers in the repository's support directory.
		linkingResults = [fileManager 
				createSymbolicLinkAtPath:aCvsWrappersInSupportDirectoryPath 
							 pathContent:aCvsWrappersInCVSROOTPath];
		if ( linkingResults == NO ) {
			(void)NSRunAlertPanel(@"CVS Wrapper Override Error", 
								  @"Could not create the link at \"%@\". This is being done so a link can be make to the cvswrappers file in the CVSROOT workarea in this repository's support directory. Will skip this link. This may keep the CVS Wrappers override feature from working correctly. Check the permissions on this link and/or its directory. Then disable and save the override feature and then enable and save the override feature again.",
								  nil, nil, nil, 
								  aCvsWrappersInSupportDirectoryPath);
		}
	}
	return linkingResults;
}

- (BOOL)linkCvsFile:(NSString *)filename
	/*" This is the method called indirectly whenever the preferences change for
		the preference whose key is OverrideCvsWrappersFileInHomeDirectory. This 
		method will create a $filename link in this repository's support
		directory to $filename file in this user's home directory.
		It is assume here that the CVSROOT workarea already esists.
	"*/
{
	NSString *theUsersHomeDirectory = nil;
	NSString *aCvsFileInHomeDirectory = nil;
	NSString *theSupportDirectory = nil;
	NSString *aCvsFileInSupportDirectoryPath = nil;
	NSFileManager   *fileManager = nil;
	BOOL theFileExists = NO;
	BOOL theFileOrLinkExists = NO;
	BOOL linkingResults = NO;
	BOOL theFileRemoved = NO;

	if ( [self isNullRepository] == YES ) return NO;
	// Get the file manager.
	fileManager = [NSFileManager defaultManager];
	
	// Get the directory that contains the $filename file.
	theUsersHomeDirectory = NSHomeDirectory();
	
	// Check to see if the $filename file exists in user's home directory.
	aCvsFileInHomeDirectory = [theUsersHomeDirectory 
							stringByAppendingPathComponent:filename];
	if ( [fileManager senFileExistsAtPath:aCvsFileInHomeDirectory] ) {
		theFileExists = YES;
	}		
	if ( theFileExists == YES ) {
		// First see if $filename already exists in the repository's 
		// support directory.
		theSupportDirectory = [self supportDirectory];
		aCvsFileInSupportDirectoryPath = [theSupportDirectory 
							stringByAppendingPathComponent:filename];
		theFileOrLinkExists = [fileManager 
					senFileOrLinkExistsAtPath:aCvsFileInSupportDirectoryPath];
		// Now delete the $filename file in the support directory just
		// so we know we are starting fresh.
		if ( theFileOrLinkExists == YES )  {
			theFileRemoved = [fileManager 
							removeFileAtPath:aCvsFileInSupportDirectoryPath
							         handler:nil];
			if ( theFileRemoved == NO ) {
				(void)NSRunAlertPanel(@"CVS Wrapper Override Error", 
									  @"Could not remove the link at \"%@\". This is being done so a new link (possibly the same as this link) can be make to the %@ file in the user's home directory. Will continue, leaving this link in place. This may keep the CVS Wrappers override feature from working correctly. Check the permissions on this link and/or its directory. Then disable and save the override feature and then enable and save the override feature again.",
									  nil, nil, nil, 
									  aCvsFileInSupportDirectoryPath, filename);	
				return YES;
			}
		}
		// Now Link this file to $filename in the user's home directory.
		linkingResults = [fileManager 
			createSymbolicLinkAtPath:aCvsFileInSupportDirectoryPath 
						 pathContent:aCvsFileInHomeDirectory];	
		if ( linkingResults == NO ) {
			(void)NSRunAlertPanel(@"CVS Wrapper Override Error", 
								  @"Could not create the link at \"%@\". This is being done so a link can be make to the %@ file in the user's home directory. Will continue. This may keep the CVS Wrappers override feature from working correctly. Check the permissions on this link and/or its directory. Then disable and save the override feature and then enable and save the override feature again.",
								  nil, nil, nil, 
								  aCvsFileInSupportDirectoryPath, filename);
		}
	} else {
		// The file $filename does not exists in the user's home directory
		// So we do not need a link. Just return YES.
		return YES;
	}
	return linkingResults;
}


- (void)makeTheSupportDirectoryTheHomeForThisRepository
	/*" This is the method called indirectly whenever the preferences change for
		the preference whose key is OverrideCvsWrappersFileInHomeDirectory is 
		enabled. This method will set the HOME environment variable to point to 
		this repository's support directory.
	"*/
{
	NSString *theSupportDirectory = nil;
	NSMutableDictionary	*newDict = nil;

	theSupportDirectory = [self supportDirectory];
	newDict = [[self environment] mutableCopy];
	[newDict setObject:theSupportDirectory forKey:@"HOME"];
	[self setEnvironment:newDict];
	[newDict release];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"RepositoryChanged" object:self];
}

- (void)makeTheUsersHomeTheHomeForThisRepository
	/*" This is the method called indirectly whenever the preferences change for
		the preference whose key is OverrideCvsWrappersFileInHomeDirectory is 
		disabled. This method will set the HOME environment variable to point to 
		the user's home directory.
	"*/
{
	NSString *theUsersHome = nil;
	NSMutableDictionary	*newDict = nil;
	
	theUsersHome = NSHomeDirectory();
	newDict = [[self environment] mutableCopy];
	[newDict setObject:theUsersHome forKey:@"HOME"];
	[self setEnvironment:newDict];
	[newDict release];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"RepositoryChanged" object:self];
}

- (void)preferencesChanged:(NSNotification *)notification
	/*" This method is called whenever a notification of the name 
		"PreferencesChanged" is posted. This method then checks to see if the 
		preference for overriding the CVSWrappers file in the user's home 
		directory has changed. If it has then this method calls the 
		overrideCvsWrappersFileInHomeDirectory: method to do the actually work 
		of implementing this preference.
	"*/
{
	BOOL overrideCvsWrappersFileInHomeDirectory = NO;
	NSUserDefaults *theUserDefaults = nil;
	
    theUserDefaults = [NSUserDefaults standardUserDefaults];	
    overrideCvsWrappersFileInHomeDirectory = [theUserDefaults 
						boolForKey:@"OverrideCvsWrappersFileInHomeDirectory"];
	if ( overrideCvsWrappersFileInHomeDirectory != previousOverrideCvsWrappersFileInHomeDirectory ) {
		[self enableCvsWrappersOverride:overrideCvsWrappersFileInHomeDirectory];
	}
}

- (id) init
{
	NSUserDefaults *theUserDefaults = nil;
		
    if ( (self = [super init]) ) {
        ignoredPatternDict = [[NSMutableDictionary allocWithZone:[self zone]] initWithCapacity:50];
        wrapperPatternDict = [[NSMutableDictionary allocWithZone:[self zone]] initWithCapacity:20];
        dirsControlled = [[NSMutableSet allocWithZone:[self zone]] initWithCapacity:50];
		
		theUserDefaults = [NSUserDefaults standardUserDefaults];
		previousOverrideCvsWrappersFileInHomeDirectory = [theUserDefaults
						 boolForKey:@"OverrideCvsWrappersFileInHomeDirectory"];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(preferencesChanged:) 
													 name:@"PreferencesChanged" 
												   object:nil];
    }
    
    return self;
}

- (void) dealloc
{
    [baseWrapperWildCardsArray release];
    [baseIgnoreWildCardsArray release];
    [ignoredPatternDict release];
    [wrapperPatternDict release];
    [checkoutRequest release];
    [CVSROOTWorkAreaPath release];
    [root release];
    [dirsControlled release];
    [modules release];
    [environment release];
    [method release];
	[cvsExecutablePath release];
	[path release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

- (CvsRepository *)initNullRepository
{
    if ( (self=[self init]) ) {
        upToDate=YES;
        root=nil;
        CVSROOTWorkAreaPath = nil;
    }
    return self;
}

- (NSString *) environmentKey
{
    return [@"Environment-" stringByAppendingString:[self root]];
}

- initWithMethod:(NSString *)theMethod root:(NSString *)aRepositoryRoot
{
    if ( (self=[self init]) ) {
        NSDictionary	*aDict;
        NSMutableDictionary *mutableDict = [[[NSProcessInfo processInfo] environment] mutableCopy];
        
        method=[theMethod retain];
        upToDate=NO;
        root=[aRepositoryRoot retain];
        environment = [[NSMutableDictionary allocWithZone:[self zone]] init];
        aDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:[self environmentKey]];
        if(aDict)
            [mutableDict addEntriesFromDictionary:aDict];
        [self setEnvironment:mutableDict];
        [mutableDict release];
    }
    return self;
}


+ (NSString*) rootAtPath: (NSString*) aPath
{
    NSString*  currentRoot= [NSString stringWithContentsOfFile:aPath];

    if (currentRoot && [currentRoot length]>0) {
        currentRoot=[currentRoot substringToIndex:[currentRoot length]-1];
    }
    return currentRoot;
}


- initWithProperties:(NSDictionary *)dictionary
{
    NSString *theMethod;
    NSString *aRepositoryRoot;

    theMethod=[dictionary objectForKey:METHOD_KEY];
    aRepositoryRoot=[dictionary objectForKey:ROOT_KEY];

    return [self initWithMethod:theMethod root:aRepositoryRoot];
}

- (NSDictionary *)properties
{
    return [NSDictionary dictionaryWithObjectsAndKeys:method,METHOD_KEY,root,ROOT_KEY,nil];
}

+ (CvsRepository *)repositoryWithWorkAreaAtPath:(NSString *)aPath
	/*" This method returns a instance of CvsRepository which has a root path 
		that has been retrieved from the CVS directory inside the CVSROOT 
		directory given by the argument aPath. For example if aPath is 
		"/Network/Servers/dub/Volumes/dupondt/Users/william/Library/
		Application Support/CVL/Repositories/Repository-1/CVSROOT" 
		then the CvsRepository returned would have a root path of 
		"/Users/Repository".
	"*/
{
    CvsRepository *aCvsRepository;
    NSString *cvsRoot = nil;
    NSString *aSupportDirectory = nil;

    cvsRoot = [CvsRepository cvsRootPathForDirectory:aPath];
    aCvsRepository = [self repositoryWithRoot:cvsRoot];
    if ( aCvsRepository != nil ) {
		aSupportDirectory = [aPath stringByDeletingLastPathComponent];
        [aCvsRepository setSupportDirectory:aSupportDirectory];
        [aCvsRepository setCVSROOTWorkAreaPath:aPath];
    }
    return aCvsRepository;
}

- (BOOL)isLocal
{
    return NO;
}

- (BOOL)needsLogin
{
    return NO;
}

- (BOOL)isRepositoryMarkedForRemoval
	/*" This is the get method for the instance variable named 
		isRepositoryMarkedForRemoval. If isRepositoryMarkedForRemoval is YES 
		then this repository is in use and has been mark for removal when CVL 
		terminates.

		See also #{-isUsed} and #{-setIsRepositoryMarkedForRemoval:}
    "*/
{
    return isRepositoryMarkedForRemoval;
}

- (void)setIsRepositoryMarkedForRemoval:(BOOL)flag
	/*" This is the set method for the instance variable named 
		isRepositoryMarkedForRemoval. If isRepositoryMarkedForRemoval is YES 
		then this repository is in use and has been mark for removal when CVL 
		terminates.

		See also #{-isUsed} and #{-isRepositoryMarkedForRemoval}
    "*/
{
    isRepositoryMarkedForRemoval = flag;
}

- (void) invalidateDir:(NSString *)dirPath
{
	if ( dirPath != nil ) {
		[ignoredPatternDict removeObjectForKey:dirPath];
		[wrapperPatternDict removeObjectForKey:dirPath];
	}
}

- (void) registerDir:(NSString *)dirPath
{
    if (dirPath)
        [dirsControlled addObject:dirPath];
}

- (void)setCVSROOTWorkAreaPath:(NSString *)thePath
	/*" This method sets the path to this repository's CVSROOT workarea to the 
		argument thePath. It should be a subpath of this repository's support 
		directory.
	"*/
{
    [thePath retain];
    [CVSROOTWorkAreaPath release];
    CVSROOTWorkAreaPath = thePath;
}

- (void)setSupportDirectory:(NSString *)aDirectory
	/*" This method sets the path to this repository's support directory. An 
		example would be "~/Library/Application Support/CVL/Repositories/RepositoryA". 
		Note the "~" would be expanded to the full path in this example.
	"*/
{
    [aDirectory retain];
    [supportDirectory release];
    supportDirectory = aDirectory;
}

- (NSString *)supportDirectory
	/*" This method returns the path to this repository's support directory. An 
		example would be "~/Library/Application Support/CVL/Repositories/RepositoryA".
		Where RepositoryA is the last component of this repository's root 
		instance variable. If there exists a support directory with the name 
		RepositoryA then RepositoryA-1 is tried and so on until a path of the 
		form "~/Library/Application Support/CVL/Repositories/RepositoryA-N" is
		found which does not exists where "N" is some integer.
		Note: the "~" would be expanded to the full path in this example.
	"*/
{	
    if ( supportDirectory == nil ) {
        NSString *theRepositoriesSupportDirectory = nil;
        NSString *aName = nil;
        NSString *aFilename = nil;
		
		theRepositoriesSupportDirectory = [[self class] repositoriesSupportDirectory];
		aName = [root lastPathComponent];
		// Cycle thru names such as RepositoryA, RepositoryA-1, RepositoryA-2
		// etc until we find one that does not exist. Return that one.
		// But give up after 10,000 tries.
		aFilename = [NSString uniqueFilenameWithPrefix:aName 
								   inDirectory:theRepositoriesSupportDirectory];
		if ( aFilename != nil ) {
			supportDirectory = [theRepositoriesSupportDirectory 
									stringByAppendingPathComponent:aFilename];
			[supportDirectory retain];
		} else {
			(void)NSRunAlertPanel(@"CVL Repositories", 
								  @"Sorry, could not create a new support directory for the repository \"%@\". Tried 10,000 times and failed. Giving up. Look in directory \"%@\" for the problem.",
								  nil, nil, nil, root, 
								  theRepositoriesSupportDirectory);            
		}
	}
	return supportDirectory;
}

- (NSString *)CVSROOTWorkAreaPath
	/*" This method returns the path to this repository's CVSROOT workarea. It
		will be a subpath of this repository's support directory. For example if
		the support directory is 
		"~/Library/Application Support/CVL/Repositories/RepositoryA" then this 
		method would return 
		"~/Library/Application Support/CVL/Repositories/RepositoryA/CVSROOT". 
		Note the "~" would be expanded to the full path in this example.
	"*/
{
    if ( CVSROOTWorkAreaPath == nil ) {
        NSString *theSupportDirectory = nil;
		
		theSupportDirectory = [self supportDirectory];
		if ( theSupportDirectory != nil ) {
			CVSROOTWorkAreaPath = [theSupportDirectory 
									stringByAppendingPathComponent:@"CVSROOT"];
			[CVSROOTWorkAreaPath retain];
		}
    }

    return CVSROOTWorkAreaPath;
}

- (NSArray *)modulesSymbolicNames
{
    if ([self isUpToDate]) {
        NSEnumerator	*anEnum = [[modules sortedArrayUsingSelector:@selector(compareSymbolicName:)] objectEnumerator];
        CvsModule		*aModule;
        NSMutableArray	*names = [NSMutableArray arrayWithCapacity:[modules count]];

        while ( (aModule = [anEnum nextObject]) ) {
            [names addObject:[aModule symbolicName]];
        }
        return names;
    } else {
        return nil;
    }
}

- (NSArray *) modules
{
    if([self isUpToDate])
        return modules;
    else
        return nil;
}

- (CvsModule *) moduleWithSymbolicName:(NSString *)aName
{
    NSEnumerator	*anEnum = [[self modules] objectEnumerator];
    CvsModule		*aModule;

    while ( (aModule = [anEnum nextObject]) ) {
        if([[aModule symbolicName] isEqualToString:aName])
            return aModule;
    }
    return nil;
}

- (void) appendShellPatternsFromString:(NSString *)string toArray:(NSMutableArray *)patterns
{
    NSArray		*lines = [string lines];
    int			i = 0, max = [lines count];
    NSString	*aLine;

    for(; i < max; i++){
        NSArray		*words;
        int			j = 0, wordMax;
        NSString	*aWord;

        aLine = [lines objectAtIndex:i];
        words = [aLine componentsSeparatedByString:@" "];
        wordMax = [words count];
        for(; j < wordMax; j++){
            aWord = [words objectAtIndex:j];
            if(![aWord isEqualToString:@""]) {
                if([aWord isEqualToString:@"!"])
                    [patterns removeAllObjects];
                else
                    [patterns addObject:aWord];                
            }
        }
    }
}

- (void) appendWrapperShellPatternsFromString:(NSString *)string toArray:(NSMutableArray *)patterns
{
    NSArray		*lines = [string lines];
    int			i = 0, max = [lines count];
    NSString	*aLine;

    for(; i < max; i++){
        int	j = 0;
        int	aLength;

        aLine = [lines objectAtIndex:i];
        aLength = [aLine length];
        for(; j < aLength; j++){
            unichar	aChar = [aLine characterAtIndex:j];

            if(j == 0 && aChar == '#')
                break;
            if(isspace(aChar))
                break;
        }

        if(j != 0)
            [patterns addObject:[aLine substringToIndex:j]];
    }
}

- (NSArray *) baseIgnoreWildCardsArray
{
    if(baseIgnoreWildCardsArray == nil){
        // These wildcards come from src/ignore.c, variable ign_default
        NSString	*repositoryIgnoreString = [[NSString alloc] initWithContentsOfFile:[[self CVSROOTWorkAreaPath] stringByAppendingPathComponent:@"cvsignore"]];
        NSString	*homeIgnoreString = [[NSString alloc] initWithContentsOfFile:[[self homeDirectory] stringByAppendingPathComponent:@".cvsignore"]];
        NSString	*environmentIgnoreString = [[self environment] objectForKey:@"CVSIGNORE"];

        baseIgnoreWildCardsArray = [[NSMutableArray allocWithZone:[self zone]] initWithObjects:@"RCS", @"SCCS", @"CVS", @"CVS.adm", @"RCSLOG", @"cvslog.*", @"tags", @"TAGS", @".make.state", @".nse_depinfo", @"*~", @"#*", @".#*", @",*", @"_$*", @"*$", @"*.old", @"*.bak", @"*.BAK", @"*.orig", @"*.rej", @".del-*", @"*.a", @"*.olb", @"*.o", @"*.obj", @"*.so", @"*.exe", @"*.Z", @"*.elc", @"*.ln", @"core", nil];
        [self appendShellPatternsFromString:repositoryIgnoreString toArray:(NSMutableArray *)baseIgnoreWildCardsArray];
        [self appendShellPatternsFromString:homeIgnoreString toArray:(NSMutableArray *)baseIgnoreWildCardsArray];
        [self appendShellPatternsFromString:environmentIgnoreString toArray:(NSMutableArray *)baseIgnoreWildCardsArray];

        [repositoryIgnoreString release];
        [homeIgnoreString release];
    }

    return baseIgnoreWildCardsArray;
}

- (NSArray *) baseWrapperWildCardsArray
{
    if(baseWrapperWildCardsArray == nil){
        NSString	*repositoryWrapperString = [[NSString alloc] initWithContentsOfFile:[[self CVSROOTWorkAreaPath] stringByAppendingPathComponent:@"cvswrappers"]];
        NSString	*homeWrapperString = [[NSString alloc] initWithContentsOfFile:[[self homeDirectory] stringByAppendingPathComponent:@".cvswrappers"]];
        NSString	*clientEnvironmentWrapperString = [[self environment] objectForKey:@"CVS_CLIENT_WRAPPER_FILE"]; // Dunno whether it's necessary... See src/wrapper.c
        NSString	*environmentWrapperString = [[self environment] objectForKey:@"CVSWRAPPERS"];

        baseWrapperWildCardsArray = [[NSMutableArray allocWithZone:[self zone]] init];
        if(repositoryWrapperString != nil)
            [self appendWrapperShellPatternsFromString:repositoryWrapperString toArray:(NSMutableArray *)baseWrapperWildCardsArray];
        if(homeWrapperString != nil)
            [self appendWrapperShellPatternsFromString:homeWrapperString toArray:(NSMutableArray *)baseWrapperWildCardsArray];
        if(clientEnvironmentWrapperString != nil)
            [self appendWrapperShellPatternsFromString:clientEnvironmentWrapperString toArray:(NSMutableArray *)baseWrapperWildCardsArray];
        if(environmentWrapperString != nil)
            [self appendWrapperShellPatternsFromString:environmentWrapperString toArray:(NSMutableArray *)baseWrapperWildCardsArray];
        
        [repositoryWrapperString release];
        [homeWrapperString release];
    }
    
    return baseWrapperWildCardsArray;
}

- (void) setModulesFromFile:(NSString *)aPath
{
    NSMutableArray	*newModules = [[CvsModule modulesWithContentsOfFile:aPath forRepository:self] retain];
    
    [modules release];
    modules = newModules;
}

- (BOOL) isWrapper:(NSString *)aPath
{
    if(!root)
        return NO;
    else{
        NSString	*currentDirPath = [aPath stringByDeletingLastPathComponent];
        NSArray		*patterns = [[wrapperPatternDict objectForKey:currentDirPath] retain];
        BOOL		result;
        
        if(!patterns){
            // Not build yet, build it now!
            NSString	*currentDirWrapperString = [[NSString alloc] initWithContentsOfFile:[currentDirPath stringByAppendingPathComponent:@".cvswrappers"]];

            patterns = [[NSMutableArray alloc] initWithArray:[self baseWrapperWildCardsArray]];
            if(currentDirWrapperString != nil)
                [self appendWrapperShellPatternsFromString:currentDirWrapperString toArray:(NSMutableArray *)patterns];
            [wrapperPatternDict setObject:patterns forKey:currentDirPath];
            [currentDirWrapperString release];
        }
        result = [[aPath lastPathComponent] cvlFilenameMatchesShellPatterns:patterns];
        [patterns release];

        return result;
    }
} // isWrapper:


- (BOOL) isIgnored:(NSString*) aPath
{
    if(!root)
        return NO;
    else{
        NSString	*currentDirPath = [aPath stringByDeletingLastPathComponent];
        NSArray		*patterns = [[ignoredPatternDict objectForKey:currentDirPath] retain];
        BOOL		result;

        if(!patterns){
            // Not build yet, build it now!
            NSString	*currentDirIgnoreString = [[NSString alloc] initWithContentsOfFile:[currentDirPath stringByAppendingPathComponent:@".cvsignore"]];

            patterns = [[NSMutableArray alloc] initWithArray:[self baseIgnoreWildCardsArray]];
            [self appendShellPatternsFromString:currentDirIgnoreString toArray:(NSMutableArray *)patterns];
            [ignoredPatternDict setObject:patterns forKey:currentDirPath];
            [currentDirIgnoreString release];
        }
        result = [[aPath lastPathComponent] cvlFilenameMatchesShellPatterns:patterns];
        [patterns release];

        return result;
    }
}

- (NSString *)root
{
    return root;
}

- (BOOL) isUpdating
{
    return isUpdating;
}

- (BOOL) isUpToDate_WithoutRefresh
// Does NOT force to be up-to-date; simply returns current status
{
    return upToDate;
}

- (void) doCheckout
{
    if ( isUpdating ) {
		return;
    } else {
        NSString		*theSupportDirectory = nil;
        NSFileManager	*fileManager = [NSFileManager defaultManager];
		BOOL allDirectoriesExists = NO;

        theSupportDirectory = [self supportDirectory];
		allDirectoriesExists = [fileManager 
								createAllDirectoriesAtPath:theSupportDirectory
												attributes:nil];
        if( allDirectoriesExists == YES ) {
            (void)[self checkoutRequest];
        } else {
			(void)NSRunAlertPanel(@"CVL", 
								  @"CVL needs to create support directory %@ and is unable to do so. No repository can be opened!",
								  nil, nil, nil, theSupportDirectory);			
		}
    }
}

- (BOOL)isUpToDate
{
    if(isUpdating)
        return NO;
    if(upToDate)
        return YES;
    [self doCheckout];
    return NO;
}

- (CvsCheckoutRequest *)checkoutRequest
{
    if (upToDate) {
        return nil;
    } else {
        if (!checkoutRequest) {
            isUpdating = YES;
            [[self class] registerRepository:self];
            checkoutRequest=[CvsCheckoutRequest cvsCheckoutRequestForModule:@"CVSROOT" inRepository:self toPath:[self supportDirectory]];
            [[NSNotificationCenter defaultCenter]
                          addObserver:self
                             selector:@selector(checkoutEnded:)
                                 name:@"RequestCompleted"
                               object:checkoutRequest];
            [checkoutRequest setIsQuiet: YES];
            [checkoutRequest schedule];
            [checkoutRequest retain];
        }
        return checkoutRequest;
    }
}

- (void) invalidateCaches
{
    [baseIgnoreWildCardsArray release];
    baseIgnoreWildCardsArray = nil;
    [ignoredPatternDict removeAllObjects];
    [baseWrapperWildCardsArray release];
    baseWrapperWildCardsArray = nil;
    [wrapperPatternDict removeAllObjects];
}

- (void) checkoutEnded:(NSNotification *)notification
{
	NSUserDefaults	*theUserDefaults		= nil;
	NSFileManager	*fileManager			= nil;
	NSString		*aCVSROOTWorkAreaPath	= nil;
	NSString		*aPath					= nil;
	BOOL			 isFileWritten			= NO;
	BOOL			 isDirectoryCreated		= NO;
	BOOL			 overrideCvsWrappersFileInHomeDirectory = NO;

	fileManager = [NSFileManager defaultManager];
	aCVSROOTWorkAreaPath = [self CVSROOTWorkAreaPath];


    if ([notification object]==checkoutRequest) {
        isUpdating = NO;
        [[NSNotificationCenter defaultCenter]
                      removeObserver:self
                             name:@"RequestCompleted"
                           object:checkoutRequest];
        [checkoutRequest release];
        checkoutRequest=nil;
    }
    if ([[notification object] succeeded]) {
        cvsRootCheckoutFailed = NO;
        [self setModulesFromFile:[aCVSROOTWorkAreaPath stringByAppendingPathComponent:@"modules"]];
        [self invalidateCaches];
        upToDate=YES;
        [self invalidateControlledDirs];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RepositoryChanged" object:self];
    }
    else{
        // In case of login on a pserver/remote repository, CVSROOT may be impossible to get.
        // In this case, we can fake to have a CVSROOT with nearly nothing in it.
        // This is a temporary patch.
        cvsRootCheckoutFailed = YES;
		
		// First create the CVSROOT directory if it does not already exists.
		if ( [fileManager senDirectoryExistsAtPath:aCVSROOTWorkAreaPath] == NO ) {
			isDirectoryCreated = [fileManager 
							createAllDirectoriesAtPath:aCVSROOTWorkAreaPath
											attributes:nil];
			if ( isDirectoryCreated == NO ){
				(void)NSRunCriticalAlertPanel(
					  @"CVS Wrapper Override Error", @"Unable to create directory %@. Correct this problem first.", 
					  @"Quit", nil, nil, aCVSROOTWorkAreaPath);
				[NSApp terminate:nil];
			}			
		}
		
		aPath = [aCVSROOTWorkAreaPath stringByAppendingPathComponent:@"cvswrappers"];
        if(![fileManager senFileExistsAtPath:aPath]) {
			isFileWritten = [@"# This is a dummy cvswrappers file, as CVL couldn't get one from the repository\n" writeToFile:aPath atomically:YES];
			if ( isFileWritten == NO ) {
				(void)NSRunAlertPanel(@"CVS Wrapper Override Error", 
					  @"Could not create a cvswrappers file in your CVSROOT workarea in the repositories support directory for the repository \"%@\". Please check on the permissions of the directory \"%@\".",
					  nil, nil, nil, [self root], aCVSROOTWorkAreaPath);	
				return;
			}			
		}
		
        aPath = [aCVSROOTWorkAreaPath stringByAppendingPathComponent:@"modules"];
        if(![fileManager senFileExistsAtPath:aPath]) {
			isFileWritten = [@"# This is a dummy modules file, as CVL couldn't get one from the repository\n" writeToFile:aPath atomically:YES];
			if ( isFileWritten == NO ) {
				(void)NSRunAlertPanel(@"CVS Wrapper Override Error", 
					  @"Could not create a modules file in your CVSROOT workarea in the repositories support directory for the repository \"%@\". Please check on the permissions of the directory \"%@\".",
					  nil, nil, nil, [self root], aCVSROOTWorkAreaPath);	
				return;
			}			
		}
		
        aPath = [aCVSROOTWorkAreaPath stringByAppendingPathComponent:@"cvsignore"];
        if(![fileManager senFileExistsAtPath:aPath]) {
			// Do NOT write comments in this file, because it is NOT allowed by cvs!!!
            isFileWritten = [@"\n" writeToFile:aPath atomically:NO];
			if ( isFileWritten == NO ) {
				(void)NSRunAlertPanel(@"CVS Wrapper Override Error", 
					  @"Could not create a cvsignore file in your CVSROOT workarea in the repositories support directory for the repository \"%@\". Please check on the permissions of the directory \"%@\".",
					  nil, nil, nil, [self root], aCVSROOTWorkAreaPath);
				return;
			}			
		}

        [self setModulesFromFile:[[self CVSROOTWorkAreaPath] stringByAppendingPathComponent:@"modules"]];
        [self invalidateCaches];
        upToDate=YES;
        [self invalidateControlledDirs];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RepositoryChanged" object:self];
    }
	theUserDefaults = [NSUserDefaults standardUserDefaults];	
	overrideCvsWrappersFileInHomeDirectory = [theUserDefaults 
						boolForKey:@"OverrideCvsWrappersFileInHomeDirectory"];
	[self enableCvsWrappersOverride:overrideCvsWrappersFileInHomeDirectory];	
}

- (BOOL) cvsRootCheckoutFailed
{
    return cvsRootCheckoutFailed;
}

- (void)invalidateControlledDirs
{
    id enumerator;
    NSString *aPath;
    CVLFile *file;
    ResultsRepository *resultsReopository=[ResultsRepository sharedResultsRepository];
    
    enumerator=[dirsControlled objectEnumerator];
    [resultsReopository startUpdate];

    while ( (aPath=[enumerator nextObject]) ) {
        file=(CVLFile *)[CVLFile treeAtPath:aPath];
        [file invalidateRepository];
    }

    [resultsReopository endUpdate];
}

- (BOOL)isUsed
{
    return ([dirsControlled count]>0);
}

- (void)cleanUp
{
    NSFileManager *fileManager=[NSFileManager defaultManager];
	NSString *anEnvironmentKey = nil;
	
    [fileManager removeFileAtPath:[self supportDirectory] handler:nil];
	anEnvironmentKey = [self environmentKey];
	if ( anEnvironmentKey != nil ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:anEnvironmentKey];
	}
}

- (BOOL)isReadyForRequests
{
    return YES;
}

- (Request *)gettingReadyRequest
{
    return nil;
}

+ (void)applicationWillTerminate:(NSNotification *)notification
{
    NSEnumerator	*anEnumerator	= nil;
    CvsRepository	*aRepository	= nil;
	NSString		*theRoot		= nil;

    anEnumerator = [repositoriesToRemove objectEnumerator];
    while ( (aRepository = [anEnumerator nextObject]) ) {
        [aRepository cleanUp];
		theRoot = [aRepository root];
		if ( theRoot != nil ) {
			[repositories removeObjectForKey:theRoot];
		}
    }
}

+ (BOOL)disposeRepository:(CvsRepository *)aRepository
{
	NSString	*theRoot	= nil;
	
    if ([aRepository isUsed]) {
        if (!repositoriesToRemove) {
            repositoriesToRemove=[[NSMutableSet alloc] init];
        }
        [repositoriesToRemove addObject:aRepository];
		[aRepository setIsRepositoryMarkedForRemoval:YES];
        return NO;
    } else {
        [aRepository cleanUp]; 
		theRoot = [aRepository root];
		if ( theRoot != nil ) {
			[repositories removeObjectForKey:theRoot];
		}		
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RegisteredRepositoriesChanged" object:self];
        return YES;
    }
}

+ (BOOL) isRepositoryToBeDisposed:(CvsRepository *)repository
{
    if(repositoriesToRemove)
        return [repositoriesToRemove containsObject:repository];
    return NO;
}

- (CvsCheckoutRequest *) checkoutAgain
{
	if(isUpdating)
        return checkoutRequest;
    if(!upToDate)
        (void)[self checkoutRequest];
    else{
        if(!checkoutRequest){
            isUpdating = YES;
            checkoutRequest = [CvsCheckoutRequest cvsCheckoutRequestForModule:@"CVSROOT" inRepository:self toPath:[self supportDirectory]];
            [[NSNotificationCenter defaultCenter]
                              addObserver:self
                                 selector:@selector(checkoutEnded:)
                                     name:@"RequestCompleted"
                                   object:checkoutRequest];
            [checkoutRequest setIsQuiet:YES];
            [checkoutRequest schedule];
            [checkoutRequest retain];
        }
    }
    return checkoutRequest;
}

- (NSDictionary *) environment
{
    return environment;
}

- (void) setEnvironment:(NSDictionary *)aDict
{
    NSMutableDictionary	*customEnv = [NSMutableDictionary dictionary];
    NSEnumerator		*anEnum = [aDict keyEnumerator];
    NSString			*aKey;

    while ( (aKey = [anEnum nextObject]) ) {
        if(![self isInheritedEnvironmentKey:aKey value:[aDict objectForKey:aKey]])
            [customEnv setObject:[aDict objectForKey:aKey] forKey:aKey];
    }
    
    [environment setDictionary:aDict];
    if(![environment objectForKey:@"HOME"])
        // On Windows we absolutely need that variable!
        [environment setObject:NSHomeDirectory() forKey:@"HOME"];
    if([customEnv count])
        [[NSUserDefaults standardUserDefaults] setObject:customEnv forKey:[self environmentKey]];
    else {
		NSString *anEnvironmentKey = nil;

		anEnvironmentKey = [self environmentKey];
		if ( anEnvironmentKey != nil ) {
			[[NSUserDefaults standardUserDefaults] 
				removeObjectForKey:anEnvironmentKey];
		}
	}
}

- (BOOL) isInheritedEnvironmentKey:(NSString *)aKey value:(NSString *)aValue
{
    return [[[[NSProcessInfo processInfo] environment] objectForKey:aKey] isEqualToString:aValue];
}

- (NSString *) homeDirectory
	/*" This method returns the home directory that will be used by the cvs 
		binary when running cvs commands. Usually this is the same as the user's
		home directory but if the override CVS Wrappers preference is enable 
		then the home directory will be this repository's support directory. An 
		example of a support directory is 
		"~/Library/Application Support/CVL/Repositories/Repository-1".
	"*/
{
	NSString *theHomeDirectory = nil;
	
	theHomeDirectory = [[self environment] objectForKey:@"HOME"];
	SEN_ASSERT_NOT_EMPTY(theHomeDirectory);
	
    return theHomeDirectory;
}

- (NSString *) username
	/*" This method returns the user name. For a local repository this is the 
		login name. For a remote repository it will be the cvs login name.
	"*/
{
    return NSUserName();
}

- (NSString *)description
    /*" This method overrides supers implementation. Here we return the root 
		and supers description.
    "*/
{
    return [NSString stringWithFormat:@"%@: root = %@", 
        [super description], [self root]];
}

- (NSNumber *)compressionLevel
	/*" This method returns the compression level for this repository. Valid 
		levels are 1 (high speed, low compression) to 9 (low speed, high 
		compression), or 0 to disable compression (the default). Only has an 
		effect on the CVS client. Compression levels are save in the user 
		defaults on a per repository bases. They can be changed in the 
		repository viewer, not in preferences.
	"*/
{
	NSUserDefaults *theUserDefaults = nil;
	NSDictionary *theRepositoriesCompressionLevels = nil;
	NSString *theSupportDirectory = nil;
	NSString *aName = nil;
    	
	if ( compressionLevel == nil ) {
		theUserDefaults = [NSUserDefaults standardUserDefaults];
		theRepositoriesCompressionLevels = [theUserDefaults 
							dictionaryForKey:@"RepositoriesCompressionLevels"];
		if ( isNotEmpty(theRepositoriesCompressionLevels) ) {
			theSupportDirectory = [self supportDirectory];
			if ( isNotEmpty(theSupportDirectory) ) {
				aName = [theSupportDirectory lastPathComponent];
				if ( isNotEmpty(aName) ) {
					compressionLevel = [theRepositoriesCompressionLevels 
															objectForKey:aName];
					[compressionLevel retain];
				}
			}
		}		
	}
	return compressionLevel;
}

- (void)setCompressionLevel:(NSNumber *)aNewCompressionLevel
	/*" This method sets the compression level for this repository. Valid 
		levels are 1 (high speed, low compression) to 9 (low speed, high 
		compression), or 0 to disable compression (the default). Only has an 
		effect on the CVS client. Compression levels are save in the user 
		defaults on a per repository bases. They can be changed in the 
		repository viewer, not in preferences.
	"*/
{
	NSUserDefaults *theUserDefaults = nil;
	NSDictionary *theRepositoriesCompressionLevels = nil;
	NSMutableDictionary *theNewRepositoriesCompressionLevels = nil;
	NSString *theSupportDirectory = nil;
	NSString *aName = nil;
	
	ASSIGN(compressionLevel, aNewCompressionLevel);
	theUserDefaults = [NSUserDefaults standardUserDefaults];
	theRepositoriesCompressionLevels = [theUserDefaults 
							dictionaryForKey:@"RepositoriesCompressionLevels"];
	if ( isNotEmpty(theRepositoriesCompressionLevels) ) {
		theNewRepositoriesCompressionLevels = [NSMutableDictionary 
					dictionaryWithDictionary:theRepositoriesCompressionLevels];
	} else {
		theNewRepositoriesCompressionLevels = [NSMutableDictionary 
													dictionaryWithCapacity:1];
	}
	theSupportDirectory = [self supportDirectory];
	if ( isNotEmpty(theSupportDirectory) ) {
		aName = [theSupportDirectory lastPathComponent];
		if ( isNotEmpty(aName) ) {
			if ( compressionLevel != nil ) {
				// The compression Level exists.
				[theNewRepositoriesCompressionLevels 
											setObject:compressionLevel 
											   forKey:aName];					
			} else {
				// The compression Level is nil.
				[theNewRepositoriesCompressionLevels removeObjectForKey:aName];
			}
			[theUserDefaults setObject:theNewRepositoriesCompressionLevels 
								forKey:@"RepositoriesCompressionLevels"];
			[theUserDefaults synchronize];			
		}
	}			
}

- (NSString *) cvsExecutablePath
{
	NSUserDefaults	*theUserDefaults = [NSUserDefaults standardUserDefaults];
	NSString		*aName = nil;
	
	if(cvsExecutablePath == nil){
		NSDictionary	*cvsExecutablePaths = [theUserDefaults dictionaryForKey:@"CVSPaths"];
		
		if(isNotEmpty(cvsExecutablePaths)){
			NSString *theSupportDirectory = [self supportDirectory];
			
			if(isNotEmpty(theSupportDirectory)){
				aName = [theSupportDirectory lastPathComponent];
				if(isNotEmpty(aName)){
					cvsExecutablePath = [[cvsExecutablePaths objectForKey:aName] copy];
				}
			}
		}
		
		if(cvsExecutablePath == nil)
			cvsExecutablePath = [[theUserDefaults stringForKey:@"CVSPath"] copy];
	}

	return cvsExecutablePath;
}

- (void) setCvsExecutablePath:(NSString *)value
{
	ASSIGN(cvsExecutablePath, value);

	if(cvsExecutablePath != nil){
		NSUserDefaults		*theUserDefaults = [NSUserDefaults standardUserDefaults];
		NSDictionary		*thePaths = [theUserDefaults dictionaryForKey:@"CVSPaths"];
		NSMutableDictionary	*theNewPaths = nil;
		NSString			*theSupportDirectory = [self supportDirectory];
		
		if(isNotEmpty(thePaths)){
			theNewPaths = [NSMutableDictionary dictionaryWithDictionary:thePaths];
		}
		else{
			theNewPaths = [NSMutableDictionary dictionaryWithCapacity:1];
		}
		theSupportDirectory = [self supportDirectory];
		if(isNotEmpty(theSupportDirectory)){
			NSString	*aName = [theSupportDirectory lastPathComponent];
			
			if(isNotEmpty(aName)){
				if(cvsExecutablePath != nil){
					[theNewPaths setObject:cvsExecutablePath forKey:aName];					
					[theUserDefaults setObject:theNewPaths forKey:@"CVSPaths"];
					[theUserDefaults synchronize];			
				}
			}
		}		
	}	
}

- (NSString *)path
	/*" This is the get method for the instance variable named 
		path. The path is the absolute path to the repository.

		See also #{-setPath:}
	"*/
{
    return path;
}

- (void)setPath:(NSString *)newPath
	/*" This is the set method for the instance variable named 
		path. The path is the absolute path to the repository.

		See also #{-path}
	"*/

{
	ASSIGN(path,newPath);
}


@end
