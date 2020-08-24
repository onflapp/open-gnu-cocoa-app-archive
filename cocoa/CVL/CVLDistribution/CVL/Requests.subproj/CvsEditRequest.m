//
//  CvsEditRequest.m
//  CVL
//
//  Created by Isa Kindov on Wed Jul 10 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import "CvsEditRequest.h"
#import <Foundation/Foundation.h>
#import "ResultsRepository.h"
#import "CVLFile.h"
#import "NSArray.SenCategorize.h"
#import <SenFoundation/SenFoundation.h>


@implementation CvsEditRequest


+ (CvsEditRequest *) editRequestForFiles:(NSArray *)theFiles inPath:(NSString *)thePath
    /*" This class method returns an instance of this class that will request 
        all the files in the array named theFiles who are in the
        directory specified by thePath have their editor set to the current user.

        NB: The files in theFiles array are all NSStrings.
    "*/
{
    CvsEditRequest	*aRequest = nil;
    
    aRequest = (CvsEditRequest *)[self requestWithCmd:CVS_EDIT_CMD_TAG 
                                                title:@"edit" 
                                                 path:thePath 
                                                files:theFiles];
    [aRequest setIsQuiet:YES];

    return aRequest;
}

+ (CvsEditRequest *) uneditRequestForFiles:(NSArray *)theFiles inPath:(NSString *)thePath
    /*" This class method returns an instance of this class that will request 
        all the files in the array named theFiles who are in the
        directory specified by thePath have their editor for the current user
        unset (i.e. removed).

        In addition, if a file in question has been modified, then
        CVS will ask if we want to revert the file to its state before we 
        issued the CVS edit command. This object will ask the user what he wants
        to do in these cases. Caution:  the state the file is returned to is the
        one in existence when the edit command was issued for this file; not the
        state of the file in the CVS repository. So if the file has been 
        modified and then the edit command is issued and then more modifications
        are made and then unedit is issued, then only the modifications since the
        edit command was issued are lost. This can be most confusing for the
        user.

        NB: The files in theFiles array are all NSStrings.
    "*/
{
    CvsEditRequest	*aRequest = nil;
    aRequest = (CvsEditRequest *)[self requestWithCmd:CVS_UNEDIT_CMD_TAG 
                                                title:@"unedit" 
                                                 path:thePath 
                                                files:theFiles];
    [aRequest setIsQuiet:YES];

    return aRequest;
}

- (void) dealloc
{
    [parsingBuffer release];
    
    [super dealloc];
}

- (BOOL) setUpTask
    /*" This method calls supers implementation and if that returns YES then 
        this method finishes the setup of this task. If supers implementation
        returns NO then this method returns NO;

        In case of unedit, if the file in question is modified then, 
        cvs will ask if we want to revert the file to its state before we 
        issued the CVS edit command. CVS then waits for an answer on its 
        stdin:  Let's reply yes to this question.
        In addition this question will be asked each time a modified file
        is encountered so to be safe we will put a "yes" in standard
        input for each file in this request.
    "*/
{
    NSString    *aYesWithNewline = nil;
    NSData      *aYesWithNewlineData = nil;
    NSArray     *myfiles = nil;
    unsigned int aCount = 0;
    unsigned int anIndex = 0;
    
    if([super setUpTask]){
        parsingBuffer = [[NSMutableString alloc] init];   
        
        if (cmdTag == CVS_UNEDIT_CMD_TAG){
            NSPipe			*aPipe = [NSPipe pipe];
            NSFileHandle	*input = [aPipe fileHandleForWriting];
            
            [task setStandardInput:aPipe];
            aYesWithNewline = [@"yes" stringByAppendingString: RequestNewLineString];
            aYesWithNewlineData = [aYesWithNewline 
                                        dataUsingEncoding:NSASCIIStringEncoding
                                     allowLossyConversion:YES];
            myfiles = [self files];
            if ( isNotEmpty(myfiles) ) {
                aCount = [myfiles count];
                for ( anIndex = 0; anIndex < aCount; anIndex++ ) {
                    [input writeData:aYesWithNewlineData];
                }                
            }
            [input closeFile];
        }
        return YES;        
    }
    return NO;
}

- (NSArray *) cvsCommandOptions
    /*" This method returns the command options for the CVS edit or unedit request. 
        This consist of an array of one object, a string of "-R". This 
        overrides supers implementation.
        This requests the edit command to be recursive.  
    "*/
{
    return [NSArray arrayWithObject: @"-R"];
}

- (NSArray *) cvsCommandArguments
    /*" This method returns the command arguments for the CVS edit or unedit request. 
        This consist of an array of files which we want to edit or unedit. This 
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
        changed by invalidating the editors, watchers and statuses of the files 
        involved.
    "*/
{
    // It is not necessary to invalidate all file info. 
    // We can invalidate only necessary info
    ResultsRepository	*resultsRepository=[ResultsRepository sharedResultsRepository];
    CVLFile				*aCVLFile;
    NSArray             *myFiles = nil;

    [resultsRepository startUpdate];

    myFiles = [self files];
    if (isNotEmpty(myFiles) ) {
        NSEnumerator	*enumerator = [myFiles objectEnumerator];
        NSString		*aPath;
        
        while ( (aPath = [enumerator nextObject]) ) {
            aPath = [[self path] stringByAppendingPathComponent:aPath];
            aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];
            [aCVLFile traversePostorder:@selector(invalidateCvsEditors)];
            [aCVLFile traversePostorder:@selector(invalidateCvsWatchers)];
            [aCVLFile traversePostorder:@selector(invalidateStatus)];
            [aCVLFile traversePostorder:@selector(invalidateCumulatedStatuses)];
        }        
    } else {
        aCVLFile = (CVLFile *)[CVLFile treeAtPath:[self path]];
        [aCVLFile traversePostorder:@selector(invalidateCvsEditors)];
        [aCVLFile traversePostorder:@selector(invalidateCvsWatchers)];
        [aCVLFile traversePostorder:@selector(invalidateStatus)];
        [aCVLFile traversePostorder:@selector(invalidateCumulatedStatuses)];
    }

    [resultsRepository endUpdate];
}

- (void) parseOutput:(NSString *)data
    /*" This method appends the string named data to the mutable string named
        parsingBuffer.
    "*/
{
    [parsingBuffer appendString:data];
}

- (void) end
    /*" This method is called upon completion of this task. This method does 
        some cleanup and then calls the method #{-updateFileInfos} to update the
        GUI based on the results of this CVS request. Then finnally calls supers
        implementation of #{-endWithoutInvalidation}.
    "*/
{
    [parsingBuffer release];
    parsingBuffer = nil;

    [self updateFileInfos];
    [super endWithoutInvalidation];
}

@end
