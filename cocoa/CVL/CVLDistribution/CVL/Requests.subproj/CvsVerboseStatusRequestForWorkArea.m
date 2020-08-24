//
//  CvsVerboseStatusRequestForWorkArea.m
//  CVL
//
//  Created by William Swats on Mon Apr 05 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import "CvsVerboseStatusRequestForWorkArea.h"
#import "CvsStatusRequest.h"
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>
#import <CvsTag.h>


@implementation CvsVerboseStatusRequestForWorkArea


+ (CvsVerboseStatusRequestForWorkArea *)cvsVerboseStatusRequestForWorkArea:(NSString *)aWorkAreaPath
    /*" This class method returns an instance of this class that will request 
        all the tags in the repository for the workarea given in the 
        aWorkAreaPath argument.
    "*/
{
    return [self requestWithCmd:CVS_GET_ALL_TAGS_CMD_TAG 
                          title:@"get all tags in workarea" 
                           path:aWorkAreaPath 
                          files:nil];
}

- (void)dealloc
{
    RELEASE(parsingBuffer);
    RELEASE(result);

    [super dealloc];
}

- (NSArray *)cvsCommandOptions
    /*" This method returns the command options for the CVS Verbose Status 
        Request For WorkArea request. This consist of an array of one object, a 
        string of "-v". This overrides supers implementation. This requests a 
        verbose status report on the whole workarea.  
    "*/
{
    return [NSArray arrayWithObject: @"-v"];
}

- (NSArray *)cvsCommandArguments
    /*" This method returns the command arguments for the CVS Verbose Status
        Request For WorkArea request. There are none for this request so we 
        return an empty array. This overrides supers implementation.
    "*/
{
    return [NSArray array];
}

- (NSString *)cvsWorkingDirectory
    /*" This method returns the working directory. In this case it is the same
        as the instance variable named path (i.e. the current directory in the 
        CVL Browser). This overrides supers implementation.
    "*/
{
    return [self path];
}

-(NSDictionary *)result
    /*" This method returns the results of this CVS request in the form of a
        dictionary. This dictionary has one key represented by string 
        "workAreaTagsKey" and its value is a set of tags.
    "*/
{
  return result;
}

- (void)initResult
    /*" This method only does one thing. It initializes the instance variable
        named result as an empty NSMutableDictionary;
    "*/
{
    result = [[NSMutableDictionary alloc] init];
}

- (BOOL)setUpTask
    /*" This method calls supers implementation and if that returns YES then 
        this method finishes the setup of this task. If supers implementation
        returns NO then this method returns NO;
    "*/
{
    if ( [super setUpTask] == YES ) {

        parsingBuffer=[[NSMutableString alloc] init];

        if (!result) {
            [self initResult];
        }
        parseByLine=NO;

        return YES;
    } else {
        return NO;
    }
}

- (void) readTagsFrom: (NSString*) aString
    /*" This method takes the output of this request, a string at a time where 
        each string represents the verbose status of a file in the workarea and 
        converts it into dictionary where the value is a set of tags and the key 
        is the string "workAreaTagsKey".
    "*/
{
    NSMutableSet *workAreaTags = nil;
    NSArray* matchArray = nil;
    NSArray *anotherMatchArray = nil;
    NSAutoreleasePool *aSubpool = nil;
    NSString *tagsPart = nil;
    NSArray *linesArray = nil;
    NSString *aLine = nil;
    int anIndex= 0;
    
    // We are using an autorelease pool here so that when the Restore WorkArea 
    // Panel is closed then CVL does not have to spend a lot of time releasing 
    // these objects. Otherwise it appears that CVL is hanging for about 10 or 
    // 20 seconds.
    aSubpool = [[NSAutoreleasePool alloc] init];

    workAreaTags = [result objectForKey:@"workAreaTagsKey"];
    if ( workAreaTags == nil ) {
        workAreaTags = [NSMutableSet setWithCapacity:10];
    }
    // Split string into two parts. The part before and after the line
    // with string "Existing Tags:" on it.
    matchArray = [aString splitStringWithPattern:CvsExistingTagsPattern 
                                         options:0];
    if ( [matchArray count] == 2 ) {
        // Get the part after the line with "Existing Tags:" on it.
        tagsPart = [matchArray objectAtIndex:1];
        // Split it inot lines.
        linesArray = [tagsPart splitStringWithPattern:CvsRequestNewLinePattern 
                                              options:0];
        // Examine each line looking for the part before any "(".
        anIndex = [linesArray count];
        while ( anIndex > 0 ) {
            anIndex--;
            aLine = [linesArray objectAtIndex:anIndex];
            // Throw away any blank lines. this is quick than running them thru
            // regex library.
            if ( [aLine length] == 0 ) continue;

            // Break it down into words. The first one will be the tag.
            anotherMatchArray = [aLine 
                            findAllSubPatternMatchesWithPattern:CvsTagsPattern 
                                                        options:0];
            if ( [anotherMatchArray count] >= 3 ) {
                CvsTag *aCvsTag = [[CvsTag alloc] init];

                NSString* aMatchedObject= [anotherMatchArray objectAtIndex:0];
                NSString* currentTag = [aMatchedObject replaceMatchesOfPattern:CvsLeadingWhiteSpacePattern 
                                                          withString:@"" 
                                                    options:AGRegexMultiline];
                NSString* tagKind= [anotherMatchArray objectAtIndex: 1];
                NSString* revision= [anotherMatchArray objectAtIndex: 2];

                [aCvsTag setTagTitle:currentTag];
                if ( [tagKind isEqualToString:@"branch"] ) {
                    [aCvsTag setIsABranchTag:YES];
                } else {
                    [aCvsTag setIsABranchTag:NO];
                }
                [aCvsTag setTagRevision:revision];
                
                [workAreaTags addObject:aCvsTag];
            }
        }
    }
    [result setObject:workAreaTags forKey:@"workAreaTagsKey"];
    
    [aSubpool release];
}

- (void)parseOutput:(NSString *)data
    /*" First this method appends the string named data to the mutable string 
        named parsingBuffer. Then it looks for the breaking pattern of "===" or
        "---" that lies between the status reports for each file in the 
        repository. When it finds one of these then it strips that part of the 
        parsing buffer off and sends that string to the method -readTagsFrom: 
        which will parse out the tags from the string sent.
    "*/
{
    NSRange sentinelRange;
    NSArray *matchArray = nil;
    NSString *aString = nil;
    int rCount = 0;
    int j = 0;

    [parsingBuffer appendString:data];
    // A sentinel to avoid deleting last split pattern
    sentinelRange.length= 2;
    [parsingBuffer appendString:@"xx"];

    // Split on ==== or on ---
    matchArray = [parsingBuffer 
                    splitStringWithPattern:CvsRequestLineOfEqualsOrMinusPattern
                                   options:0];
    rCount = [matchArray count];
    for (j = 0; j < (rCount - 1); j++) {	
        // Send each available string to the reader (i.e parser).
        aString = [matchArray objectAtIndex: j];
        if ( [aString length] > 0 ) {
            [self readTagsFrom:aString];
        }
    }
    // Remove from the parsing buffer all the strings sent to the reader.
    [parsingBuffer setString:[matchArray objectAtIndex:(rCount - 1)]];
    
    // Now delete the sentinel that was added above.
    sentinelRange.location = [parsingBuffer length] - sentinelRange.length;
    [parsingBuffer deleteCharactersInRange:sentinelRange];
}

- (void)end
    /*" This method is called upon completion of this task. This method then
        calls the method #{-readTagsFrom:} to parse the last results of
        this CVS request. Then some cleanup and then finally calls supers
        implementation of #{-endWithoutInvalidation}.
    "*/
{
    // Read the last of the parsing buffer.
    [self readTagsFrom:parsingBuffer];

    RELEASE(parsingBuffer);
    parsingBuffer = nil;

    if (!result) {
        [self initResult];
    }
    [super endWithoutInvalidation];
}


@end
