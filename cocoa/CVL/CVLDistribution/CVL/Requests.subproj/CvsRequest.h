
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <TaskRequest.h>


@class NSArray, NSDictionary, CvsRepository;


#define CVS_STATUS_CMD_TAG          0
#define CVS_LOG_CMD_TAG             1
#define CVS_UPDATE_CMD_TAG          2
#define CVS_REMOVE_CMD_TAG          3
#define CVS_DIFF_CMD_TAG            4
#define CVS_OBJCOMMENT_CMD_TAG      5
#define CVS_NOKEYWDEXP_CMD_TAG      6
#define CVS_COMMIT_CMD_TAG          7  // first of cmds with argument
#define CVS_TAG_CMD_TAG             8
#define CVS_IMPORT_CMD_TAG          9  // queue contains dir where to 'cd'
#define CVS_CHECKOUT_CMD_TAG       10
#define CVS_ADD_CMD_TAG            11  // special cmdTag
#define CVS_UNIX_CMD_TAG           12
#define CVS_GET_TAGS_CMD_TAG       13
#define CVS_VERSION_TAG            14
#define CVS_INIT_CMD_TAG           15
#define CVS_QUICK_STATUS_CMD_TAG   16
#define CVS_RELEASE_CMD_TAG        17
#define CVS_EDITORS_CMD_TAG        18
#define CVS_WATCHERS_CMD_TAG       19
#define CVS_WATCH_CMD_TAG          20
#define CVS_EDIT_CMD_TAG           21
#define CVS_UNEDIT_CMD_TAG         22
#define CVS_GET_ALL_TAGS_CMD_TAG   23
#define CVS_CMD_COUNT              24  // (120) UNIX added 


extern NSString* CvsRequestNewLinePattern;
extern NSString* CvsRequestLineOfEqualsOrMinusPattern;
extern NSString* CvsExistingTagsPattern;
extern NSString* CvsTagsPattern;
extern NSString* CvsLeadingWhiteSpacePattern;


@interface CvsRequest : TaskRequest
{
    unsigned int cmdTag;
    NSString *path;
    NSArray *files;
    CvsRepository *repository;
    NSString *errorString;
    BOOL needsLogin;
#ifdef JA_PATCH
    BOOL noLogin;
    CvsRequest *repositoryRequest;
#endif
}

+ (NSDictionary*) canonicalizePath: (NSString*) aPath andFiles: (NSArray*) someFiles;
    // remove any subpath from files and return common dir as key and files as value (only one common path is allowed)

+ requestWithCmd:(unsigned int)aCmd title:(NSString *)cmdString path:(NSString *)thePath files:(NSArray *)someFiles;
- initWithCmd:(unsigned int)aCmd title:(NSString *)cmdString path:(NSString *)thePath files:(NSArray *)someFiles;

- (void)setPath:(NSString *)value;
- (NSString *)path;
- (void)setFiles:(NSArray *)value;
- (NSArray *)files;

- (CvsRepository *)repository;
- (void)setRepository:(CvsRepository *)aRepository;

- (unsigned int)cmdTag;

- (NSArray *)cvsOptions;
- (NSString *)cvsCommand;
- (NSArray *)cvsCommandOptions;

- (void)updateFileStatuses;
#ifndef JA_PATCH
- (void)endWithoutInvalidation;
#endif


- (void)reportError;
- (NSString *)singleFile;

- (BOOL)didGenerateAnError;
- (BOOL)didGenerateAWarning;

- (void)displayCvswappersAlertPanel:(NSString *)aString;


@end
