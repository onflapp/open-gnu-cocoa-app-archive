/* CvsModule.h created by stephane on Wed 08-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>


@class NSArray, NSMutableArray, NSMutableDictionary, NSDictionary, CvsRepository;


@interface CvsModule : NSObject
{
    CvsRepository		*repository; // Not retained, because module is retained (owned) by repository
    NSString			*symbolicName;
    NSArray				*aliases; // -a
    NSString			*directory;
    NSMutableArray		*files;
    NSMutableArray		*additionalModuleNames;
    NSMutableDictionary	*options;
}

+ (NSArray *) parseModuleDescription:(NSString *)moduleDescription forRepository:(CvsRepository *)aRepository errors:(NSArray **)moduleErrorsPtr;

+ (CvsModule *) parseModuleLine:(NSString *)lineString forRepository:(CvsRepository *)aRepository errors:(NSMutableArray *)moduleErrors;

+ (NSArray *) modulesWithContentsOfFile:(NSString *)filename forRepository:(CvsRepository *)aRepository;

+ (NSArray *) modulesWithModuleDescription:(NSString *)aModuleDescription forRepository:(CvsRepository *)aRepository errors:(NSArray **)moduleErrorsPtr;

+ (BOOL) checkModuleDescription:(NSString *)moduleDescription forRepository:(CvsRepository *)aRepository;

- (CvsRepository *) repository;
- (void) setRepository:(CvsRepository *)aRepository;

- (NSString *) symbolicName;
- (void) setSymbolicName:(NSString *)aSymbolicName;

- (NSArray *) aliases;
- (void) setAliases:(NSArray *)names;

- (NSString *) directory;
- (void) setDirectory:(NSString *)aDirectory;

- (NSArray *) files;
- (void) setFiles:(NSArray *)names;

- (NSArray *) additionalModuleNames;
- (void) setAdditionalModuleNames:(NSArray *)names;

- (NSString *) outputDirectoryName;
- (void) setOutputDirectoryName:(NSString *)anOutputDirectoryName;

- (NSString *) statusOption;
- (void) setStatusOption:(NSString *)aStatus;

- (NSDictionary *) options;
- (void) setOptions:(NSDictionary *)someOptions;

- (NSComparisonResult) compareSymbolicName:(CvsModule *)aModule;

@end
