/* CvsCommitRequest.m created by vincent on Mon 24-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsCommitRequest.h"

#import <CVLDelegate.h>
#import "NSArray.SenCategorize.h"
#import <SenFoundation/SenFoundation.h>

@implementation CvsCommitRequest

+ (id) cvsCommitRequestForFiles:(NSArray *)someFiles inPath:(NSString *)aPath message:(NSString *)mesgString
    /*" Note: The array named somefiles contains NSStrings representing file 
        paths.
    "*/
{
    NSArray *checkedFiles=nil;
    NSDictionary* pathDict;
    NSString* commonPath;
    CvsCommitRequest *newRequest;

    if (someFiles) {
        pathDict=[[self class] canonicalizePath: aPath andFiles: someFiles];
        commonPath= [[pathDict allKeys] objectAtIndex: 0];
        checkedFiles= [pathDict objectForKey: commonPath];
    } else {
        commonPath=aPath;
    }

    newRequest=[self requestWithCmd:CVS_COMMIT_CMD_TAG 
                              title:@"commit" 
                               path:commonPath 
                              files:checkedFiles];
    [newRequest setMessage: mesgString];
  return newRequest;
}

- (void)dealloc
{
  RELEASE(message);
  [super dealloc];
}

- (void) setMessage: (NSString*) aString
{
    ASSIGN(message, aString);
}

- (void) setRevision:(NSString*)aString
{
    ASSIGN(revision, aString);
}


- (NSArray *)cvsCommandOptions
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"UseCvsTemplates"]){
        if(revision)
            return [NSArray arrayWithObjects:@"-r", revision, nil];
        else
            return [NSArray array];
    }
    else{
        if(revision)
            return [NSArray arrayWithObjects:@"-r", revision, @"-m", message, nil];
        else
            return [NSArray arrayWithObjects:@"-m", message, nil];
    }
}


- (NSArray *)cvsOptions
{
    NSString *thePathToCVLEditor = nil;

    // Get and check the path to cvlEditor.
    thePathToCVLEditor = [[NSApp delegate] pathToCVLEditor];
    if( thePathToCVLEditor != nil ) {
        return [[super cvsOptions] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"-e", thePathToCVLEditor, nil]];
    } else {
        return [super cvsOptions];
    }
}

- (NSString *)cvsWorkingDirectory
{
    return [self path];
}

@end
