//
//  CvsWatchersRequest.m
//  CVL
//
//  Created by Isa Kindov on Tue Jul 09 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import "CvsWatchersRequest.h"
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>
#import <NSString+Lines.h>
#import <CvsWatcher.h>


@implementation CvsWatchersRequest

+ (CvsWatchersRequest *) watchersRequestForFiles:(NSArray *)theFiles inPath:(NSString *)thePath
    /*" This class method returns an instance of this class that will request 
        all the watchers for the files in the array named theFiles who are in the
        directory specified by thePath.

        NB: The files in theFiles array are all NSStrings.
    "*/
{
    return [self requestWithCmd:CVS_WATCHERS_CMD_TAG 
                          title:@"get cvsWatchers" 
                           path:thePath 
                          files:theFiles];
}

- (void) dealloc
{
    [result release];
    [parsingBuffer release];

    [super dealloc];
}

- (NSDictionary *) result
    /*" This method returns the results of this CVS request in the form of a
        dictionary. This dictionary has keys represented by pathname strings and
        values of arrays of CvsWatchers.
    "*/
{
    return result;
}

- (NSArray *) cvsCommandOptions
    /*" This method returns the command options for the CVS watchers request. 
        This consist of an array of one object, a string of "-l". This 
        overrides supers implementation.
        This requests watchers for files in current directory only.  
    "*/
{
    return [NSArray arrayWithObject: @"-l"];
}

- (NSArray *) cvsCommandArguments
    /*" This method returns the command arguments for the CVS watchers request. 
        This consist of an array of files whose watchers we are requesting. This 
        overrides supers implementation.
    "*/
{
    return [self files];
}

- (NSString *) cvsWorkingDirectory
    /*" This method returns the working directory. In this case it is the same
        as the instance variable named path (i.e. the current directory in the 
        CVL Browser). This overrides supers implementation.
    "*/
{
    return [self path];
}

- (void) initResult
    /*" This method only does one thing. It initializes the instance variable
        named result as an empty NSMutableDictionary;
    "*/
{
    result = [[NSMutableDictionary alloc] init];
}

- (BOOL) setUpTask
    /*" This method calls supers implementation and if that returns YES then 
        this method finishes the setup of this task. If supers implementation
        returns NO then this method returns NO;
    "*/
{
    if([super setUpTask]){
        parsingBuffer = [[NSMutableString alloc] init];

        if(!result)
            [self initResult];

        return YES;
    }
    else
        return NO;
}

- (void) parseCvsWatchersFromString:(NSString *)aString
    /*" This method takes the output of the CVS watchers command (in the form of
        a string) and converts it into dictionary where the values are arrays
        of CvsWatchers and keys are the paths of the files that are in the 
        CVL browser.
    "*/
{
    // Scans 'aString' and updates watcher info, if any
    NSMutableArray	*anArrayOfWatchers = nil;
    NSString *aFilename = nil;
    NSString *aFilePath = nil;
    NSString *aPathname = nil;
    NSString        *aUsername = nil;
    CvsWatcher       *aCvsWatcher = nil;
    NSArray	*lines = [aString lines];
    NSArray	*actions = nil;
    NSArray *anActionsArray = nil;
    NSNumber *watchesEdit = nil;
    NSNumber *watchesUnedit = nil;
    NSNumber *watchesCommit = nil;
    NSNumber *isTemporary = nil;    
    unsigned int anIndex = 0;
    unsigned int aFileCount = 0;
    unsigned int aLineCount = 0;
    unsigned int aWordCount = 0;
    BOOL watchesEditState = NO;
    BOOL watchesUneditState = NO;
    BOOL watchesCommitState = NO;
    
    
    anActionsArray = [NSArray arrayWithObjects:
        @"edit", @"unedit", @"commit", @"tedit", @"tunedit", @"tcommit", nil];

    // Command lists only files which have watchers; other files are not listed
    // We need to know that these files have no watchers!
    // So first we loop thru all the files in this request, not just the ones that
    // have watchers.
    aFilePath = [self path];
    aFileCount = [[self files] count];
    for(anIndex = 0; anIndex < aFileCount; anIndex++){
        anArrayOfWatchers = [[NSMutableArray alloc] initWithCapacity:1];
        
        aFilename = [[self files] objectAtIndex:anIndex];
        aPathname = [aFilePath stringByAppendingPathComponent:aFilename];
        [result setObject:anArrayOfWatchers forKey:aPathname];
        [anArrayOfWatchers release];
    }
    
    // Now we loop thru only the ones that have watchers.
    aLineCount = [lines count];
    for(anIndex = 0; anIndex < aLineCount; anIndex++){
        NSArray	*words = [[lines objectAtIndex:anIndex] componentsSeparatedByString:@"\t"];
        
        watchesEditState = NO;
        watchesUneditState = NO;
        watchesCommitState = NO;
        
        aWordCount = [words count];
        if(aWordCount >= 3){
            // Get the filename first. It is in the first position on the first 
            // line. We are depending on the -lines method to return the lines
            // in the same order as they are in aString.
            aFilename = [words objectAtIndex:0];
            // check to make sure we have an filename at the beginning.
            if ( anIndex == 0 ) {
                SEN_ASSERT_NOT_EMPTY(aFilename);
            }
            if ( isNotEmpty(aFilename) ) {
                aPathname = [aFilePath stringByAppendingPathComponent:aFilename];
            }
            SEN_ASSERT_NOT_EMPTY(aPathname);
            anArrayOfWatchers = [result objectForKey:aPathname];
            SEN_ASSERT_NOT_NIL(anArrayOfWatchers);
            aUsername = [words objectAtIndex:1];
            SEN_ASSERT_NOT_EMPTY(aUsername);

            actions = [words subarrayWithRange:NSMakeRange(2, aWordCount - 2)];
            
            // Check for permenant watches.
            watchesEditState = [actions containsObject:@"edit"];
            watchesUneditState = [actions containsObject:@"unedit"];
            watchesCommitState = [actions containsObject:@"commit"];
            if ( (watchesEditState == YES) ||
                 (watchesUneditState == YES) ||
                 (watchesCommitState == YES) ) {
                watchesEdit = [NSNumber numberWithBool:watchesEditState];
                watchesUnedit = [NSNumber numberWithBool:watchesUneditState];
                watchesCommit = [NSNumber numberWithBool:watchesCommitState];
                isTemporary = [NSNumber numberWithBool:NO];
                
                aCvsWatcher = [[CvsWatcher alloc] initWithUsername:aUsername 
                                                       watchesEdit:watchesEdit 
                                                     watchesUnedit:watchesUnedit 
                                                     watchesCommit:watchesCommit 
                                                       isTemporary:isTemporary];
                [anArrayOfWatchers addObject:aCvsWatcher];                
            }
            
            // Check for temporary watches.
            watchesEditState = [actions containsObject:@"tedit"];
            watchesUneditState = [actions containsObject:@"tunedit"];
            watchesCommitState = [actions containsObject:@"tcommit"];
            if ( (watchesEditState == YES) ||
                 (watchesUneditState == YES) ||
                 (watchesCommitState == YES) ) {
                watchesEdit = [NSNumber numberWithBool:watchesEditState];
                watchesUnedit = [NSNumber numberWithBool:watchesUneditState];
                watchesCommit = [NSNumber numberWithBool:watchesCommitState];
                isTemporary = [NSNumber numberWithBool:YES];
                
                aCvsWatcher = [[CvsWatcher alloc] initWithUsername:aUsername 
                                                       watchesEdit:watchesEdit 
                                                     watchesUnedit:watchesUnedit 
                                                     watchesCommit:watchesCommit 
                                                       isTemporary:isTemporary];
                [anArrayOfWatchers addObject:aCvsWatcher];                
            }            
        }
    }
}


- (void) parseOutput:(NSString *)data
    /*" This method appends the string named data to the mutable string named
        parsingBuffer.
    "*/
{
    [parsingBuffer appendString:data];
}

- (void) end
    /*" This method is called upon completion of this task. This method then
        calls the method #{-parseCvsEditorsFromString:} to parse the results of
        this CVS request. then does some cleanup and then finnally calls supers
        implementation of #{-endWithoutInvalidation}.
    "*/
{
    [self parseCvsWatchersFromString:parsingBuffer];
    [parsingBuffer release];
    parsingBuffer = nil;

    if(!result)
        [self initResult];

    [super endWithoutInvalidation];
}

@end
