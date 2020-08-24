
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsRequest.h"
#import <CvsRepository.h>
#import "NSArray.SenCategorize.h"
#import "ResultsRepository.h"
#import "CVLFile.h"
#import <AppKit/AppKit.h>
#import "CVLDelegate.h"
#import "NSFileManager_CVS.h"
#import <SenFoundation/SenFoundation.h>
#import "NSString+SenPathComparison.h"

static NSString* cvsCmds[CVS_CMD_COUNT];
static int maxRequestsCount= 0;


NSString* CvsRequestNewLinePattern= @"\\n";
NSString* CvsRequestLineOfEqualsOrMinusPattern= @"=+\\n|-+\\n";
NSString* CvsExistingTagsPattern = @"\\s+Existing Tags:\\n";
NSString* CvsTagsPattern = @"\\t+(.*)\\s+\\((.*):\\s+(.*)\\)";
NSString* CvsLeadingWhiteSpacePattern = @"\\s+$";

//----------------------------------------------------------------------------------------------------------------------

@interface CvsRequest (Private)
+ (void)preferencesChanged:(NSNotification *)notification;
- (void)repositoryChanged:(NSNotification *)notification;
- (void)restart;
@end

//----------------------------------------------------------------------------------------------------------------------

@implementation CvsRequest
+ (void)initialize
{
    cvsCmds[CVS_STATUS_CMD_TAG]=@"status";
    cvsCmds[CVS_LOG_CMD_TAG]=@"log";
    cvsCmds[CVS_UPDATE_CMD_TAG]=@"update";
    cvsCmds[CVS_REMOVE_CMD_TAG]=@"remove";
    cvsCmds[CVS_DIFF_CMD_TAG]=@"diff";
    cvsCmds[CVS_OBJCOMMENT_CMD_TAG]=@"admin";
    cvsCmds[CVS_NOKEYWDEXP_CMD_TAG]=@"admin";
    cvsCmds[CVS_COMMIT_CMD_TAG]=@"commit";
    cvsCmds[CVS_TAG_CMD_TAG]=@"tag";
    cvsCmds[CVS_IMPORT_CMD_TAG]=@"import";
    cvsCmds[CVS_CHECKOUT_CMD_TAG]=@"checkout";
    cvsCmds[CVS_ADD_CMD_TAG]=@"add";
    cvsCmds[CVS_UNIX_CMD_TAG]=@"UNIX";
    cvsCmds[CVS_VERSION_TAG]=@"version";
    cvsCmds[CVS_INIT_CMD_TAG]=@"init";
    cvsCmds[CVS_QUICK_STATUS_CMD_TAG]=@"update";
    cvsCmds[CVS_RELEASE_CMD_TAG]=@"release";
    cvsCmds[CVS_EDITORS_CMD_TAG]=@"editors";
    cvsCmds[CVS_WATCHERS_CMD_TAG]=@"watchers";
    cvsCmds[CVS_WATCH_CMD_TAG]=@"watch";
    cvsCmds[CVS_EDIT_CMD_TAG]=@"edit";
    cvsCmds[CVS_UNEDIT_CMD_TAG]=@"unedit";
    cvsCmds[CVS_GET_ALL_TAGS_CMD_TAG]=@"status";
    

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesChanged:) name:@"PreferencesChanged" object:nil];
    [self preferencesChanged:nil];
}

+ (NSDictionary*) canonicalizePath: (NSString*) aPath andFiles: (NSArray*) someFiles
    /*" This method returns a dictionary with one entry. The key of this 
        dictionary is the common path to the files in the array someFiles. The
        value of this key is an array of relative pathnames of the files in 
        someFiles which are relative to the key value of this dictionary. 
        Normally all the files in someFiles are in the same directory so what 
        gets returned in this case is the filenames in an array as the 
        dictionary value and the path to this directory as the key in this 
        dictionary. 

        Note: The pathnames in the argument someFiles are relative to the path
        in the argument aPath.
    "*/
{
    NSString* commonPath= aPath;
    unsigned int aCount = 0;

    if ( isNotEmpty(someFiles) ) {
        NSMutableDictionary* subpathsDict = nil;
        NSArray* allTheKeys = nil;

        subpathsDict = [[someFiles categorizeUsingMethod: @selector(stringByDeletingLastPathComponent)] mutableCopy];

        allTheKeys = [subpathsDict allKeys];
        aCount = [allTheKeys count];
        if ( aCount > 1) {
            // Case 1: There are subpaths in the files to be returned.
            NSString *theLongestCommonPath = nil;
            NSEnumerator *fileEnum = nil;
            NSString *currentPath = nil;
            NSString *lastPathComponents = nil;
            NSMutableArray *filesWithoutPath = nil;
            NSRange aPrefixRange;
            
            theLongestCommonPath = [NSString longestCommonPathOfPaths:allTheKeys];
            SEN_ASSERT_NOT_NIL(theLongestCommonPath);

            fileEnum = [someFiles objectEnumerator];
            filesWithoutPath = [NSMutableArray arrayWithCapacity:[someFiles count]];
            while ( (currentPath = [fileEnum nextObject]) ) {
                aPrefixRange = [currentPath rangeOfString:theLongestCommonPath 
                                                  options:NSAnchoredSearch];
                lastPathComponents = [currentPath substringFromIndex:aPrefixRange.length];
                // Remove a leading slash if any.
                if ( [lastPathComponents hasPrefix:@"/"] == YES ) {
                    lastPathComponents = [lastPathComponents substringFromIndex:1];
                }
                [filesWithoutPath addObject:lastPathComponents];
            }
            commonPath = [aPath stringByAppendingPathComponent:theLongestCommonPath];
            [subpathsDict release];
            return [NSDictionary dictionaryWithObject:filesWithoutPath 
                                               forKey:commonPath];            
        } else if ( aCount == 1) {
            // Case 2: There are no subpaths in the files to be returned.
            NSEnumerator* fileEnum= [someFiles objectEnumerator];
            NSString* currentPath= nil;
            NSMutableArray* filesWithoutPath= [NSMutableArray arrayWithCapacity: [someFiles count]];

            while ( (currentPath= [fileEnum nextObject]) )
            {
                [filesWithoutPath addObject: [currentPath lastPathComponent]];
            }
            commonPath= [aPath stringByAppendingPathComponent: [[subpathsDict allKeys] objectAtIndex: 0]];
            [subpathsDict release];
            return [NSDictionary dictionaryWithObject: filesWithoutPath forKey: commonPath];
        } else {
            // Case 3: There entries in the files to be returned are the same as
            // in the argument someFiles. The common path is the same as the 
            // argument aPath. Should never enter this case.
            [subpathsDict release];
            return [NSDictionary dictionaryWithObject: someFiles forKey: commonPath];
        }
    } else {
        // Case 4: There are no entries in the files to be returned. The common
        // path is the same as the argument aPath. An empty array is returned as
        // the object value for the key.
        return [NSDictionary dictionaryWithObject: [NSArray array] forKey: commonPath];
    }
}


+ requestWithCmd:(unsigned int)aCmd title:(NSString *)cmdString path:(NSString *)aPath files:(NSArray *)someFiles
{
    return [[[self alloc] initWithCmd:aCmd title:cmdString path:aPath files:someFiles] autorelease];
}

+ (void)preferencesChanged:(NSNotification *)notification
{
    maxRequestsCount= MAX (1, [[NSUserDefaults standardUserDefaults] integerForKey: @"MaxParallelRequestsCount"]);
}

- initWithCmd:(unsigned int)aCmdTag title:(NSString *)cmdString path:(NSString *)aPath files:(NSArray *)someFiles
{
    cmdTag = aCmdTag;
    self=[self initWithTitle: cmdString];
    [self setPath:aPath];
    [self setFiles:someFiles];
    [self setRepository:[CvsRepository repositoryForPath:aPath]];

    [[NSNotificationCenter defaultCenter]
                addObserver:self
                   selector:@selector(requestReceivedData:)
                       name:@"RequestReceivedData"
                     object:self];
    
    return self;
}

-(void)dealloc
{
    RELEASE(repository);
    RELEASE(path);
    RELEASE(files);

    [super dealloc];
}

- (CvsRepository *)repository
{
    return repository;
}

- (void)setRepository:(CvsRepository *)aRepository
{
    if (repository) {
        [[NSNotificationCenter defaultCenter] removeObserver:self                                                                    name:@"RepositoryChanged" object:repository];
    }
    ASSIGN(repository, aRepository);
    if (repository) {
        [[NSNotificationCenter defaultCenter] addObserver:self                                                                    selector:@selector(repositoryChanged:) name:@"RepositoryChanged" object:repository];
    }
}

- (void)repositoryChanged:(NSNotification *)notification
{
#ifdef JA_PATCH
    [self updateState];
#else
    if (state!=STATE_RUNNING) {
        if (![repository isReadyForRequests]) {
            if (![self canContinue]) {
                [self setState:STATE_WAITING];
            } else {
                [self setState:STATE_READY];
            }
        }
    }
#endif
}

-(unsigned int)cmdTag
{
    return cmdTag;
}

- (NSArray *)cvsOptions
{
    // WORKAROUND:
    // It happens that repository has not been found out (BUG)
    // To avoid a totally invalid command, we check that CVSROOT
    // has been set, else we don't pass it as parameter.
    if([[repository root] length])
        return [NSArray arrayWithObjects:@"-d",[repository root],nil];
    else
        return [NSArray array];
}

- (NSString *)cvsCommand
{
    SEN_ASSERT_CONDITION((cmdTag < CVS_CMD_COUNT));
    return cvsCmds[cmdTag];
}

#ifndef JA_PATCH
- (void) resumeNow
{
    switch (internalState) {
        case INTERNAL_STATE_CVS_RETRY_AFTER_LOGIN:
            [self taskCleanUp];
            if ([self startTask]) {
                [self setState:STATE_RUNNING];
            } else {
                success=NO;
                [self endConditionReached];
            }
                break;

        default:
            [super resumeNow];
            break;
    }
}
#endif

- (NSArray *)cvsCommandOptions
{
  // this switch will disappear when all requests will be real classes
    switch (cmdTag) {

        case CVS_OBJCOMMENT_CMD_TAG:
            return [NSArray arrayWithObject:@"-c"];
            break;

        case CVS_NOKEYWDEXP_CMD_TAG:
            return [NSArray arrayWithObject:@"-ko"];
            break;

        default:
            return nil;
            break;
    }
}

- (NSString *)cvsWorkingDirectory
{
    return nil;
}

- (NSArray *)cvsCommandArguments
{
    if ((cmdTag == CVS_OBJCOMMENT_CMD_TAG) || (cmdTag == CVS_NOKEYWDEXP_CMD_TAG))
    {	// cmds without arguments
        return [NSArray arrayWithObject:[self path]];
    } else if (cmdTag == CVS_TAG_CMD_TAG)
    {
        NSMutableArray *cmdArgs=[NSMutableArray arrayWithArray:[self files]];
        [cmdArgs addObject:[self path]];

        return cmdArgs;
    }
    return [self files];
}

- (void)setPath:(NSString *)value
{
    NSString *aStandardizedPath = nil;
    
    aStandardizedPath = [value stringByStandardizingPath];
    ASSIGN(path, aStandardizedPath);
}

-(NSString *)path
{
    return path;
}


-(NSString *)summary
{
    if ([[self files] count] == 1)
    {
        return [[self files] objectAtIndex: 0];
    }
    else
    {
        return [[self path] lastPathComponent];
    }
}


- (void)setFiles:(NSArray *)value
    /*" This is the set method for the instance variable named files. However
        before setting files to the array named value the file paths in the
        array are standardized,
    "*/
{    
    NSString *aRelativeFilePath = nil;
    NSString *aStandardizedRelativeFilePath = nil;
    NSEnumerator *aRelativeFilePathEnumerator = nil;
    NSMutableArray *standardizedFilePathArray = nil;
    unsigned int aCount = 0;

    if ( isNotEmpty(value) ) {
        aCount = [value count];
        standardizedFilePathArray = [NSMutableArray arrayWithCapacity:aCount];
        aRelativeFilePathEnumerator =  [value objectEnumerator];
        while ( (aRelativeFilePath = [aRelativeFilePathEnumerator nextObject]) ) {
            aStandardizedRelativeFilePath = [aRelativeFilePath stringByStandardizingPath];
            [standardizedFilePathArray addObject:aStandardizedRelativeFilePath];
        }
    }    
    ASSIGN(files, standardizedFilePathArray);
}

-(NSArray *)files
{
    return files;
}

- (NSString *)singleFile
	/*" This method returns the single file in the files array. If there is more
		than one file in this array or if the array is empty or nil then nil is 
		returned.
	"*/
{
	NSString *aFile = nil;
	
	if ( (files != nil) && ([files count] == 1) ) {
		aFile = [files objectAtIndex:0];
	}
	return aFile;
}

-(BOOL)setUpTask
{ // (120) some code is duplicated in super class, some cleaning is required on both..
    NSMutableArray *taskArgs= [NSMutableArray array];

    if ([super setUpTask])
    {
        CvsRepository   *aRepository = [self repository];
        NSDictionary	*environment;
		NSString		*cvsPath;

        if(aRepository){
            environment = [aRepository environment];
            cvsPath = [aRepository cvsExecutablePath];
        }
        else{
            cvsPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"CVSPath"];
            environment = nil;
        }
        
        [taskArgs addObjectsFromArray:[self cvsOptions]];
        if([self cvsCommand]){
            // We need to check this for the special case where we ask --version! There is no cvs command...
            NSArray	*cmdArgs;
            
            [taskArgs addObject:[self cvsCommand]];
            [taskArgs addObjectsFromArray:[self cvsCommandOptions]];
            cmdArgs = [self cvsCommandArguments];
            if(cmdArgs && [cmdArgs count])
                [taskArgs addObject:@"--"]; // Mark the end of the options, else we have problems with filenames starting with a dash -
            [taskArgs addObjectsFromArray:cmdArgs];
        }
        if(environment)
            [task setEnvironment:environment];
        if ((cvsPath) && ([cvsPath cStringLength])) {
            [task setLaunchPath:cvsPath];
        } else {
            [NSApp sendAction: @selector(showPreferences:) to: nil from: self];
            (void)NSRunAlertPanel(@"Cvs problem", @"No path set for the cvs binary, please set it in the preferences panel.", nil, nil, nil);
            return NO;
        }

        {
            NSString *workingDirectory;

            if ( (workingDirectory=[self cvsWorkingDirectory]) ) {
                NSFileManager *fileManager = [NSFileManager defaultManager];

                if([fileManager senDirectoryExistsAtPath:workingDirectory]){
                    [task setCurrentDirectoryPath:workingDirectory];
                } else {
                    return NO;
                }
            }
        }

        if (cmdTag == CVS_ADD_CMD_TAG)
        {
            NSPipe *aPipe=[NSPipe pipe];
            NSFileHandle *input=[aPipe fileHandleForWriting];

            [task setStandardInput:aPipe];
            
      // [input writeData:[NSData dataWithBytesNoCopy:"y\n" length:2]]; //gives malloc-error 5 !
      //      [input writeData:[NSData dataWithBytes:"y\n" length:2]];
            [input writeData: [[@"y" stringByAppendingString: RequestNewLineString] dataUsingEncoding:NSASCIIStringEncoding
                                                                                 allowLossyConversion:YES]];
            [input closeFile];
        }

        if (cmdTag == CVS_COMMIT_CMD_TAG){
            if([[NSUserDefaults standardUserDefaults] boolForKey:@"UseCvsTemplates"])
                {
                // In case of user cancelling commit, cvs waits for an answer from its stdin:
                // let's reply we want to _a_bort the operation.
                NSPipe			*aPipe = [NSPipe pipe];
                NSFileHandle	*input = [aPipe fileHandleForWriting];

                [task setStandardInput:aPipe];

                [input writeData:[[@"a" stringByAppendingString: RequestNewLineString] dataUsingEncoding:NSASCIIStringEncoding
                                                                                    allowLossyConversion:YES]];
                [input closeFile];
                }
        }

        [task setArguments:taskArgs];
        return YES;
    }
    else
    {
        return NO;
    }
}

#ifndef JA_PATCH
- (void)taskEnded
{
    if (internalState==INTERNAL_STATE_CVS_TRY_LOGIN) {
        internalState=INTERNAL_STATE_CVS_RETRY_AFTER_LOGIN;
        if (![self canContinue]) {
            [self setState:STATE_WAITING];
        } else {
            [self setState:STATE_READY];
        }
    } else {
        [self endConditionReached];
    }
}

- (BOOL) canContinue
{
    if ([repository isReadyForRequests]) {
        return [super canContinue];
    } else {
        [self addPrecedingRequest:(Request *)[repository gettingReadyRequest]];
    }
    return NO;
}
#endif

- (void)parseError:(NSString *)data
{
    if ([repository needsLogin]) {
        if ([data rangeOfString:@"to log in first"].length) {
#ifdef JA_PATCH
            noLogin=YES;
#else
            internalState=INTERNAL_STATE_CVS_TRY_LOGIN;
#endif
            [repository setIsLoggedIn:NO];
        } else if ([data rangeOfString:@"authorization failed:"].length) {
#ifdef JA_PATCH
            noLogin=YES;
#else
            internalState=INTERNAL_STATE_CVS_TRY_LOGIN;
#endif
            [repository setIsLoggedIn:NO];
        }
    }

    return;
}

-(void)updateFileStatuses
{
    ResultsRepository *resultsRepository=[ResultsRepository sharedResultsRepository];
    CVLFile *file;
    NSArray *myFilePaths = nil;

    [resultsRepository startUpdate];

    myFilePaths = [self files];
    if ( isNilOrEmpty(myFilePaths) ) {
        [(CVLFile *)[CVLFile treeAtPath:[self path]] traversePostorder:@selector(invalidateAll)];
    } else {
        id enumerator=[myFilePaths objectEnumerator];
        NSString *aPath;

        while ( (aPath=[enumerator nextObject]) ) {
            aPath=[[self path] stringByAppendingPathComponent:aPath];
            file=(CVLFile *)[CVLFile treeAtPath:aPath];
            [file traversePostorder:@selector(invalidateAll)];
            /*
             fileFlags=[file flags];
             if (!fileFlags.isDir || fileFlags.isWrapper) {
                 [file invalidateAll];
             } else {
                 [[CVLFile treeAtPath:[self path]] traversePostorder:@"invalidateAll"];
                 [resultsRepository invalidateResultsForDirWithPath:aPath recursively:YES];
             }
             */
        }
    }
    [resultsRepository endUpdate];
}

#ifdef JA_PATCH
-(void)endWithSuccess
{
    [self updateFileStatuses];
}

-(void)endWithFailure
{
    [self updateFileStatuses];
}
#else
-(void)end
{
    [self updateFileStatuses];
    [self reportError];

    [super end];
}

- (void) endWithoutInvalidation
{
    [super end];
}
#endif

- (NSMutableDictionary *)descriptionDictionary
    /*" This method returns a description of this instance in the form of a 
        dictionary. The keys are the names of the instance variables and the 
        values are the values of those instance variables. The keys return here 
        the keys from super's implementation plus path, args and errorString.

        See also #{descriptionDictionary} in superclass TaskRequest.
    "*/
{
    NSMutableDictionary* dict = nil;
    
    dict = [super descriptionDictionary];
    [dict setObject: ((path != nil) ? path : @"") forKey: @"path"];
    [dict setObject: ([files count] ? [files description] : @"") forKey: @"args"];
    [dict setObject: ((errorString != nil) ? errorString : @"") forKey: @"errorString"];
        
    return dict;
}

- (BOOL) canRunAgainstRequests:(NSSet *)runningRequests
{
    id enumerator;
    CvsRequest *aRequest;
    int requestCount=0;

    enumerator=[runningRequests objectEnumerator];
    while ( (aRequest=[enumerator nextObject]) ) {
        if ([aRequest isKindOfClass:[CvsRequest class]]) {
            requestCount++;
            if (requestCount>=maxRequestsCount) return NO;
            if (![self canRunAgainstRequest:aRequest]) return NO;
        }

    }

    return YES;
}

- (BOOL) canRunAgainstRequest:(Request *)runningRequest
{
    //  ResultsRepository* resultsRepository= [ResultsRepository sharedResultsRepository];

    if ([(CvsRequest *)runningRequest path]) { //(NO) was here, but locks reappeared !
        return !([path isEqualToString:[(CvsRequest *)runningRequest path]]);
        //                ([[resultsRepository repositoryPathForPath: path] isEqualToString: [resultsRepository repositoryPathForPath: [(CvsRequest *)runningRequest path]]])) ;
    } else {
        return YES;
    }
}

#ifdef JA_PATCH
+(State *)initialState
{
    static BOOL triedInitialState=NO;
    static State *initialState=nil;

    if (!triedInitialState) {
        ASSIGN(initialState, [State initialStateForStateFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"CvsTask" ofType:@"fsm"]]);
        triedInitialState=YES;
    }
    return initialState;
}

- (BOOL)readyForCvsTask
{
    return !noLogin;
}

- (BOOL)repositoryIsReady
{
    return [[self repository] isReadyForRequests];
}

- (BOOL)repositoryIsNotReady
{
    return ![[self repository] isReadyForRequests];
}

- (BOOL)repositoryFailed
{
    return (!repositoryRequest && ![[self repository] isReadyForRequests]);
}

- (BOOL)taskFailedBecauseOfAccess
{
    return noLogin;
}

- (BOOL)startTask
{
    noLogin=NO;
    return [super startTask];
}

- (void)waitForRepository
{
    ASSIGN(repositoryRequest, [[self repository] gettingReadyRequest]);
    if (repositoryRequest) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repositoryDone:) name:@"RequestCompleted" object:repositoryRequest];
    } else {
        [self updateState];
    }
}

- (void)repositoryDone:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"RequestCompleted" object:repositoryRequest];
    RELEASE(repositoryRequest);
    [self updateState];
}
#endif

- (NSArray *) modifiedFiles
{
    NSMutableArray	*modifiedFiles = [NSMutableArray array];
    NSEnumerator	*anEnum = [[self files] objectEnumerator];
    NSString		*aFilename;

    while ( (aFilename = [anEnum nextObject]) ) {
        [modifiedFiles addObject:[[self path] stringByAppendingPathComponent:aFilename]];
    }

    if([modifiedFiles lastObject])
        return modifiedFiles;
    else
        return nil;
}

- (void)taskTerminated:(NSNotification *)aNotification
{
    int aTerminationStatus = 0;
    NSTask *aTask = nil;
    BOOL taskTracingEnabled = NO;
    
    aTask = [aNotification object];
    taskTracingEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"TaskTracingEnabled"];
    if( taskTracingEnabled ) {
        NSString *aMsg = [NSString stringWithFormat:
            @"In taskTerminated: (aTask pid = %d), (task pid = %d) aNotification = %@!",
            [aTask processIdentifier], [task processIdentifier], aNotification];
        SEN_LOG(aMsg);        
    }
    
    if ( aTask != task ) return; // Not my task, ignore!
    
    SEN_ASSERT_CONDITION(([task isRunning] != YES));
    aTerminationStatus = [task terminationStatus];
    if ( aTerminationStatus != 0 ) {
        success = NO; 
    } else {
        success = YES;
    }

    [super taskTerminated:aNotification];
}

- (void) requestReceivedData:(NSNotification *)aNotification
{
    NSDictionary *someUserInfo = nil;
    NSString *receivedString = nil;
    CvsRequest *aRequest = [aNotification object];

    if ( aRequest != self ) return; // Not me, ignore!

    if ( [aRequest isKindOfClass:[CvsRequest class]] ) {
        someUserInfo = [aNotification userInfo];

        if ([[someUserInfo objectForKey:@"ErrorStream"] isEqual:@"YES"]) {
            receivedString = [someUserInfo objectForKey:@"RequestNewData"];
            [errorString release];
            errorString = [receivedString copy];
        }
    }
    return;
}

- (void)reportError
    /*" This method reports CVS error messages to the user via of alert panels.
        A lot of CVS errors are not really errors but are warnings, so we are
        only showing errors in the code below by comparing some phrases against
        the error message.
    "*/
{
    NSString *someAdditionInformation = nil;
    NSString    *aTitle = nil;
    BOOL displayCvsErrors = NO;
    BOOL showError = NO;
    BOOL showWarning = NO;
    
    displayCvsErrors = [[NSUserDefaults standardUserDefaults] boolForKey:@"DisplayCvsErrors"];
    if ( displayCvsErrors == NO ) return;
        
    if ( isNotEmpty(completeErrorMsgString) ) {
		showError = [self didGenerateAnError];
		showWarning = [self didGenerateAWarning];
         
        if ( (showError == YES) || (showWarning == YES)) {
            someAdditionInformation = [NSString stringWithFormat:
                @"occurred for files: %@ \rin directory: \"%@\".",
                files, path];
                                    
            if ( showWarning == YES ) {
                aTitle = @"CVS Warning";
            } else {
                aTitle = @"CVS Problem";
            }
            
            if ( isNotEmpty(completeErrorMsgString) ) {
                if ( isNotEmpty(someAdditionInformation) ) {
                    NSRunAlertPanel(aTitle, 
                                    @"%@\r%@",
                                    @"OK", nil, nil,
                                    completeErrorMsgString, 
                                    someAdditionInformation);            
                } else {
                    NSRunAlertPanel(aTitle, 
                                    @"%@",
                                    @"OK", nil, nil,
                                    completeErrorMsgString);            
                }
            }            
        }
    }
}

- (NSString *)moreInfoString
    /*" This is a method that returns more information about this request.
        Mainly we are talking about the instance variables some of which have 
        been converted to informational strings. This is mostly used for 
        debugging purposes but also appears in the processes panel.
    "*/
{    
    NSString *moreInfoString = nil;
    
    moreInfoString = [NSString stringWithFormat:
          @"%@\nPath: %@", 
        [super moreInfoString], ((path != nil) ? path : @"")];
    
    return moreInfoString;
}

- (BOOL)didGenerateAnError
    /*" This method returns a YES if this request generated an error; otherwise 
		a NO is returned. To determine if an error has been generated the
		messages returned from cvs are checked for certain phrases. This is not 
		fool proof. See the code for the phrases that are being used to return 
		YES.
    "*/
{
    BOOL anError = NO;
    
    if ( isNotEmpty(completeErrorMsgString) ) {
        // Show as an error "correct above errors first"!
        if ( [completeErrorMsgString rangeOfString:
            @"correct above errors first"].length > 0 ) {
            anError = YES;
        } else if ( [completeErrorMsgString rangeOfString:
            @"correct the above errors first"].length > 0 ) {
            anError = YES;
        } else if ( [completeErrorMsgString rangeOfString:
            @"No such file or directory"].length > 0 ) {
            anError = YES;
        }
    }
	return anError;
}

- (BOOL)didGenerateAWarning
    /*" This method returns a YES if this request generated an warning; otherwise 
		a NO is returned. To determine if an warning has been generated the
		messages returned from cvs are checked for certain phrases. This is not 
		fool proof. See the code for the phrases that are being used to return 
		YES.
    "*/
{
    BOOL anError = NO;
    
    if ( isNotEmpty(completeErrorMsgString) ) {
		if ( [completeErrorMsgString rangeOfString:
						 @"cvs remove: scheduling"].length > 0 ) {
            anError = YES;
        }
    }
	return anError;
}

- (void)displayCvswappersAlertPanel:(NSString *)aString
{
	NSString *aName = nil;
	NSUserDefaults *theUserDefaults = nil;
	BOOL overrideCvsWrappersFileInHomeDirectory = NO;
		
	aName = [[self repository] root];
	theUserDefaults = [NSUserDefaults standardUserDefaults];	
	overrideCvsWrappersFileInHomeDirectory = [theUserDefaults 
						boolForKey:@"OverrideCvsWrappersFileInHomeDirectory"];
	if ( overrideCvsWrappersFileInHomeDirectory == NO ) {
		(void)NSRunAlertPanel(@"CVS pserver Error", 
							  @"The CVS server at \"%@\" does not handle the .cvswrappers file that you have in your home directory. CVL will not work properly until this is fixed. Try one of the following:\n\n1. Go to Preferences > General tab. Check the checkbox labeled \"Override the .cvswrappers file...\". This is the recommended method.\n2. if running Tiger or later in the Available Repositories Panel select the repository in question and change the CVS executable to /usr/bin/ocvs (an older version of CVS that handles CVS wrappers).\n3. Copy the .cvswrappers file in the CVSROOT directory in the repository in question to your home directory.\n4. Or remove the .cvswrappers file in your home directory. \n\nThe error message received from the cvs was:\n\n%@",
							  nil, nil, nil, aName, aString);   
	} else {
		(void)NSRunAlertPanel(@"CVS pserver Error", 
							  @"The CVS server at \"%@\" does not handle the .cvswrappers file that you have in your CVL support directory. Your CVL support directory is ~/Library/Application Support/CVL. CVL will not work properly until this is fixed. Try the following if running Tiger or later:\n\nIn the Available Repositories Panel select the repository in question and change the CVS executable to /usr/bin/ocvs (an older version of CVS that handles CVS wrappers).\n\nThe error message received from the cvs was:\n\n%@",
							  nil, nil, nil, aName, aString);   
	}
}

@end

//----------------------------------------------------------------------------------------------------------------------

@implementation CvsRequest (TemporaryHereWaitingForProperClasses)

- (NSString *)shortDescription
{
    return [NSString stringWithFormat: @"%@ in %@\n", [self cmdTitle], [self path]];
}

@end
