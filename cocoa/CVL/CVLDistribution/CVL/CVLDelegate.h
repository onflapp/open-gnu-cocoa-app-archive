// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class ResultsRepository;
@class NSString;
@class NSMutableString;
@class NSMutableArray;
@class NSMutableDictionary;
@class Request;
@class WorkAreaViewer;
@class CVLFile;
@class SenSelection;
@class NSTextView;

#define CVL_ERROR_DOMAIN @"CVLErrorDomain"


@interface CVLDelegate:NSObject
{
    id (activeViewer);
    IBOutlet NSMenu *fileMenu;
    IBOutlet NSMenuItem *startEditingMenuItem;
    IBOutlet NSMenuItem *cancelEditingMenuItem;
    IBOutlet NSMenuItem *startWatchingMenuItem;
    IBOutlet NSMenuItem *stopWatchingMenuItem;
    IBOutlet NSMenuItem *workAreaDrawerMenuItem;
    NSMutableDictionary *savedWorkAreaViewersState;
    NSMutableDictionary *currentWorkAreaViewers; // Key is workArea path => avoid to open two viewers for same workArea path
    ResultsRepository *resultsRepository;
    SenSelection *globalSelection;
    NSConnection	*cvlEditorClientConnection;
    IBOutlet NSTextView *helpView;
    NSMutableSet *processRequests;
    NSTimeInterval startTime;
    NSTimeInterval endTime;    
    BOOL processStarted;
    BOOL processEnded;
    BOOL isLongRunningProcessAlertActivated;
    BOOL isApplicationTerminating;
}

+ (NSString*) resourceDirectory;

	/*" Action Methods "*/
- (IBAction) openModule:(id)sender;

- (WorkAreaViewer *)viewerShowingFile:(CVLFile *)aFile;
- (WorkAreaViewer *)newViewerShowingFile:(CVLFile *)aFile;
- (WorkAreaViewer *)viewerWithRootFile:(CVLFile *)aFile; // returns an existing viewer


//- doRepositoryImport: sender;
//- doModuleCvsCheckout: sender;

- (id) viewerForPath:(NSString *)aPath; // Will create viewer only if necessary

- (SenSelection *)globalSelection;
- (void)preferencesChanged:(NSNotification *)aNotification;
- (NSString *)pathToCVLEditor;
- (void) showViewer:(WorkAreaViewer *)aViewer;
- (BOOL) isApplicationTerminating;
- (void) openInTemporaryDirectory:(NSString *)aPath withVersion:(NSString *)aVersion orDateString:(NSString *)aDateString withHead:(BOOL)useHead;
- (int) save:(NSString *)aPath withVersion:(NSString *)aVersion orDateString:(NSString *)aDateString withHead:(BOOL)useHead;

@end

@interface CVLDelegate(RequestObserver)
- (void)activateLongRunningProcessAlert;
- (void)showAlertTimeDisplay:(NSDictionary *)aUserInfo;

@end

@interface CVLDelegate (ApplicationDelegate)

- (IBAction) showHelp:(id)sender;
- (IBAction) showReleaseNotes:(id)sender;
- (IBAction) showLicense:(id)sender;
- (IBAction) showInspectorPanel:(id)sender;
- (IBAction) showProgressPanel:(id)sender;
- (IBAction) showRepositoryViewer:(id)sender;
- (BOOL) saveViewerState;
- (id)activeViewer;
- (void)setActiveViewer:(id)aViewer;

@end

