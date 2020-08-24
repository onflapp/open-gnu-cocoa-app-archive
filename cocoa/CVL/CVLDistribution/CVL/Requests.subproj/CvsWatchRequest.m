//
//  CvsWatchRequest.m
//  CVL
//
//  Created by Isa Kindov on Wed Jul 10 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import "CvsWatchRequest.h"
#import <Foundation/Foundation.h>
#import "ResultsRepository.h"
#import "CVLFile.h"
#import "NSArray.SenCategorize.h"
#import <SenFoundation/SenFoundation.h>


@implementation CvsWatchRequest


+ (CvsWatchRequest *) watchRequestForFiles:(NSArray *)theFiles inPath:(NSString *)thePath forAction:(CvsWatchActionTag)anActionTag
    /*" This class method returns an instance of this class that will request 
        all the files in the array named theFiles who are in the
        directory specified by thePath have their watch set to according to 
        value of anActionTag. 

        NB: The files in theFiles array are all NSStrings.
    "*/
{
    CvsWatchRequest	*aRequest = nil;
    
    aRequest = (CvsWatchRequest *)[self requestWithCmd:CVS_WATCH_CMD_TAG 
                                                 title:@"watch" 
                                                  path:thePath 
                                                 files:theFiles];
    [aRequest setActionTag:anActionTag];
    [aRequest setIsQuiet:YES];

    return aRequest;
}

- (NSArray *) cvsCommandOptions
    /*" This method returns the command options for the CVS watch request. 
        This consist of an array of objects depending on the action requested.
        This method overrides supers implementation.
    "*/
{
    switch(actionTag){
        case CvsWatchEditActionTag:
            return [NSArray arrayWithObjects:@"add", @"-a", @"edit", @"-R", nil];
        case CvsWatchUneditActionTag:
            return [NSArray arrayWithObjects:@"add", @"-a", @"unedit", @"-R", nil];
        case CvsWatchCommitActionTag:
            return [NSArray arrayWithObjects:@"add", @"-a", @"commit", @"-R", nil];
        case CvsWatchAllActionsTag:
            return [NSArray arrayWithObjects:@"add", @"-a", @"all", @"-R", nil];
        case CvsWatchNoActionTag:
            return [NSArray arrayWithObjects:@"add", @"-a", @"none", @"-R", nil];
        case CvsUnwatchEditActionTag:
            return [NSArray arrayWithObjects:@"remove", @"-a", @"edit", @"-R", nil];
        case CvsUnwatchUneditActionTag:
            return [NSArray arrayWithObjects:@"remove", @"-a", @"unedit", @"-R", nil];
        case CvsUnwatchCommitActionTag:
            return [NSArray arrayWithObjects:@"remove", @"-a", @"commit", @"-R", nil];
        case CvsUnwatchAllActionsTag:
            return [NSArray arrayWithObjects:@"remove", @"-a", @"all", @"-R", nil];
        case CvsWatchOnTag:
            return [NSArray arrayWithObjects:@"on", @"-R", nil];
        case CvsWatchOffTag:
            return [NSArray arrayWithObjects:@"off", @"-R", nil];
        default:
            // Should never happen
            SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
                @"The actionTag (%d) in CvsWatchRequest does not have any corresponding Cvs command options.", 
                actionTag]));
            
            return nil;
    }
}

- (NSArray *) cvsCommandArguments
    /*" This method returns the command arguments for the CVS watch request. 
        This consist of an array of files which we want to watch or unwatch. This 
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

- (void) updateFileInfos
    /*" This method forces GUI updates to all the files that this request
        changed by invalidating the watchers of the files involved.
    "*/
{
    // It is not necessary to invalidate all file info. We can invalidate only necessary info
    ResultsRepository	*resultsRepository=[ResultsRepository sharedResultsRepository];
    CVLFile				*aCVLFile;
    NSArray             *myFiles = nil;

    [resultsRepository startUpdate];

    myFiles = [self files];
    if ( isNotEmpty(myFiles) ) {
        NSEnumerator	*enumerator = [myFiles objectEnumerator];
        NSString		*aPath;
        
        while ( (aPath = [enumerator nextObject]) ) {
            aPath = [[self path] stringByAppendingPathComponent:aPath];
            aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];
            [aCVLFile traversePostorder:@selector(invalidateCvsWatchers)];
        }        
    } else {
        aCVLFile = (CVLFile *)[CVLFile treeAtPath:[self path]];
        [aCVLFile traversePostorder:@selector(invalidateCvsWatchers)];
    }

    [resultsRepository endUpdate];
}

- (void) end
    /*" This method is called upon completion of this task. This method does 
        some cleanup and then calls the method #{-updateFileInfos} to update the
        GUI based on the results of this CVS request. Then finnally calls supers
        implementation of #{-endWithoutInvalidation}.
    "*/
{
    [self updateFileInfos];
    [super endWithoutInvalidation];
}

- (CvsWatchActionTag) actionTag
    /*" This is the get method for the actionTag. The values of anActionTag have
        the following meanings:

    _{  CvsWatchEditActionTag  10
    CvsWatchUneditActionTag  20
    CvsWatchCommitActionTag  30
    CvsWatchAllActionsTag  40
    CvsWatchNoActionTag  50
    CvsUnwatchEditActionTag  -10
    CvsUnwatchUneditActionTag  -20
    CvsUnwatchCommitActionTag  -30
    CvsUnwatchAllActionsTag  -40
    CvsWatchOnTag  100
    CvsWatchOffTag  -100    }


    See also #{-setActionTag:}
    "*/
{
    return actionTag;
}

- (void) setActionTag:(CvsWatchActionTag)newActionTag
    /*" This is the set method for the actionTag.

    See also #{-actionTag}
    "*/
{
    actionTag = newActionTag;
}

@end
