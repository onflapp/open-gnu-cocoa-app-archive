// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ResultsRepository.h"
#import <SenBrowserCell.h>
#import "DirectoryContentsFilterProvider.h"

@class NSMutableDictionary;
@class ResultsRepository;
@class NSString;
@class NSArray;
@class NSBrowserCell;

@interface BrowserController:NSObject
{
	IBOutlet NSBrowser	*browser;
		
	ResultsRepository* resultsRepository;
    CVLFile *rootFile;
	int		updateCount;
    SenBrowserCell *cellPrototypes[ECInvalidFile+1];
    DirectoryContentsFilterProvider *filterProvider;
    NSMutableArray *filters;

    NSSize requestedBrowserSize;
    id delegate;
	CvsRepository *cvsRepository;
	NSMutableArray *rightSizeArray;
	BOOL isRightSizeColumnJustSet;
}

+ (BrowserController*) browserForPath: (NSString*) aPath;
+ setImageDict:(NSArray *)dict;

- initForPath: (NSString*) pathString;

- (void)selectFiles:(NSSet *)someFiles;
- (void)select:(id)sender;
- (void)doubleSelect:(id)sender;

- (void)setDelegate:(id)aDelegate;
- (void)setFilterProvider:(id)aProvider;
- (NSSize) viewerWillResizetoSize: (NSSize) frameSize;

- view;
- (NSString*) rootPath;
- (NSString *)cvsFullRepositoryPath;
- (CvsRepository *)cvsRepository;

-(NSArray *)relativeSelectedPaths;
-(NSArray *)selectedPaths;
-(BOOL)selectionIsOneDir;
- (NSArray *) relativePathsFromSelectedCVLFilesUnrolledAndFiltered;
- (NSArray *) relativePathsFromSelectedCVLFilesUnrolled;
- (NSArray *) relativePathsFromCVLFiles:(NSArray *)someCVLFiles;
- (NSString *) relativePathFromCVLFile:(CVLFile *)aCVLFile;
- (NSString *) relativePathFromPath:(NSString *)aPath;
- (NSArray *) selectedCVLFiles;
- (CVLFile *) selectedCVLFile;
- (NSArray *) selectedCVLFilesUnrolled;
- (NSArray *) selectedCVLFilesUnrolledAndFiltered;
- (NSArray *) filteredCVLFiles:(NSArray *)someCVLFiles;
- (NSArray *) unrollCVLFiles:(NSArray *)someCVLFiles;
- (NSArray *)directoriesInCVLFiles:(NSArray *)someCVLFiles unrolled:(BOOL)isUnrolled;


- (void) reloadData;

@end

#if 0
@interface NSObject (BrowserControllerDelegate)
- (void)viewerFrameSizeChanged:(id)sender;
@end
#endif
