/* CVLRenameController.m created by stephane on Wed 20-Oct-1999 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLRenameController.h"

#ifdef PANTHER
#import <SenOpenPanelController.h>
#import <CvsAddRequest.h>
#import <CvsCommitRequest.h>
#import <CvsRemoveRequest.h>
#else
#import <SenOpenPanelController.h>
#import <Requests/CvsAddRequest.h>
#import <Requests/CvsCommitRequest.h>
#import <Requests/CvsRemoveRequest.h>
#endif
#import "CVLFile.h"
#import "CVLWaitController.h"
#import <AppKit/AppKit.h>


@interface CVLFile(RemoveCVSDirectory)
- (void) removeCVSDirectory;
@end

@interface CVLRenameController(Private)
- (void) doRename;
- (void) doRenameTo:(NSString *)newFullPathName byCopying:(BOOL)doCopy;
- (void) removeRequestCompleted:(NSNotification *)aNotif;
@end

@implementation CVLRenameController

/*
	Renaming
 	It should be avoided, in most cases, because it breaks history and logs.
 	See cvs documentation (Moving and renaming files).

 	User has choice to delete current file/folder, and to apply the same revision number to
 	the renamed file/folder as the old one's.

 	After asking user for the new name/location of the file/folder, we copy/move the old one
 	to the new location. Then we call <cvs add NEW>, followed by <cvs remove OLD>, <cvs commit NEW>,
 	and finally <cvs commit OLD>
 */

+ (id) sharedInstance
{
    static CVLRenameController	*sharedInstance = nil;

    if(!sharedInstance)
        sharedInstance = [[self alloc] init];

    return sharedInstance;
}

- (id) init
{
    if ( (self = [super init]) ) {
        NSAssert([NSBundle loadNibNamed:@"CVLRename" owner:self], @"Unable to load CVLRename nib");
        [accessoryView retain];
        [[accessoryView window] release];
    }

    return self;
}

- (void) dealloc
{
    [accessoryView release];
    [savePanelController release];
    [workAreaRootPath release];
    [oldPathName release];
    [newPathName release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[super dealloc];
}

- (void) finishRenaming
{
    renaming = NO;
    [oldPathName release];
    oldPathName = nil;
    [newPathName release];
    newPathName = nil;
    [workAreaRootPath release];
    workAreaRootPath = nil;
}

- (void) waitRevision:(NSNotification *)aNotif
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[aNotif name] object:[aNotif object]];
    if([[aNotif object] waitCancelled]){
        [self finishRenaming];
        return;
    }
    [self doRename];
}

- (void) renameFileNamed:(NSString *)aName fromWorkArea:(NSString *)rootFilePath
{
    CVLFile	*sourceFile;

    if(renaming)
        return;

    sourceFile = (CVLFile *)[CVLFile treeAtPath:[rootFilePath stringByAppendingPathComponent:aName]];
    oldPathName = [aName copy];
    workAreaRootPath = [[rootFilePath stringByStandardizingPath] copy];

    renaming = YES;

    if([sourceFile isLeaf] && [sourceFile hasBeenRegisteredByRepository] && ![sourceFile revisionInRepository]){
        // We need to get the current revision of the file
        CVLWaitController	*waitController = [CVLWaitController waitForConditionTarget:sourceFile selector:@selector(revisionInRepository) cancellable:YES userInfo:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(waitRevision:) name:CVLWaitConditionMetNotification object:waitController];
        [waitController setWaitMessage:[NSString stringWithFormat:@"Retrieving '%@' version...", aName]];
    }
    else
        [self doRename];
}

- (void) doRename
{
    NSString	*oldFullPathName = [workAreaRootPath stringByAppendingPathComponent:oldPathName];
    CVLFile		*sourceFile = [CVLFile treeAtPath:oldFullPathName];

    // Warn user only if file has been committed at least once
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"DoNotWarnOnRename"] && [sourceFile hasBeenRegisteredByRepository])
        if(NSRunAlertPanel(@"Rename", @"Renaming a file or directory is not a good idea... ", @"Cancel", @"Rename", nil) == NSAlertDefaultReturn){
            [self finishRenaming];
            return;
        }

    [commitButtonCell setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"CommitOnRename"]];
    [savePanelController setStringValue:oldFullPathName];

    if(![savePanelController senOpenPanel])
        [self finishRenaming];
    else
        [self doRenameTo:[[savePanelController stringValue] stringByStandardizingPath] byCopying:YES];
}

- (void) doRenameTo:(NSString *)newFullPathName byCopying:(BOOL)doCopy
{
    NSString		*oldFullPathName = [workAreaRootPath stringByAppendingPathComponent:oldPathName];
    CVLFile			*sourceFile = [CVLFile treeAtPath:oldFullPathName];
    CvsAddRequest	*addRequest;
    CvsRemoveRequest		*removeRequest = nil;
    NSRange			aRange;
    CvsRequest		*childRequest;

    if([newFullPathName isEqualToString:workAreaRootPath] || [newFullPathName isEqualToString:oldFullPathName] || [newFullPathName hasPrefix:oldFullPathName]){
        (void)NSRunAlertPanel(@"Rename", @"Impossible to use specified path name.", nil, nil, nil);
        [self finishRenaming];
        return;
    }

    aRange = [newFullPathName rangeOfString:workAreaRootPath options:NSLiteralSearch | NSAnchoredSearch];
    if(aRange.location != 0){
        (void)NSRunAlertPanel(@"Rename", @"New path must be in the same work area as the old one.", nil, nil, nil);
        [self finishRenaming];
        return;
    }
    else{
        NSAssert([newFullPathName characterAtIndex:aRange.length] == '/', @"Did not find prefixing /");
        newPathName = [[newFullPathName substringFromIndex:aRange.length + 1] retain]; // Add 1 for prefixing '/'
    }

    // We don't need to delete the oldFullPathName; normally cvs remove handles this (but it has a problem with wrappers...)
//    if(doCopy && ![[NSFileManager defaultManager] copyPath:oldFullPathName toPath:newFullPathName handler:nil]){
	// cvs does not remove directories...
    if(doCopy && ![[NSFileManager defaultManager] movePath:oldFullPathName toPath:newFullPathName handler:nil]){
        (void)NSRunAlertPanel(@"Rename", @"Unable to rename '%@' to '%@'.", nil, nil, nil, oldPathName, newPathName);
        [self finishRenaming];
        return;
    }
    else if(![sourceFile isLeaf])
        [(CVLFile *)[CVLFile treeAtPath:newFullPathName] removeCVSDirectory];

    addRequest = [CvsAddRequest cvsAddRequestAtPath:workAreaRootPath files:[NSArray arrayWithObject:newPathName]];
    NSAssert1(addRequest != nil, @"Could not create CvsAddRequest for %@", newPathName);
    childRequest = addRequest;

    // Check that file was recorded by cvs; it it wasn't, do not try to remove it from cvs control, or request will fail
#warning (Stephane) Does test work for directories?
    if([sourceFile flags].isInCVSEntries){
        removeRequest = [CvsRemoveRequest removeRequestAtPath:workAreaRootPath files:[NSArray arrayWithObject:oldPathName]];

        NSAssert1(removeRequest != nil, @"Could not create CvsRequest for %@", oldPathName);
        [removeRequest addPrecedingRequest:addRequest];
        childRequest = removeRequest;
    }

    if([commitButtonCell state]){
        NSString			*commitMessage = [NSString stringWithFormat:@"Moved from %@ to %@", oldPathName, newPathName];
        CvsCommitRequest	*commitRequest = nil;

        // Check that file was recorded by cvs repository; it it wasn't, do not try to commit it, or request will fail
        if([sourceFile hasBeenRegisteredByRepository]){
            if([sourceFile isLeaf]){
                NSAssert([sourceFile revisionInRepository] != nil, @"Has no revision but in repository!");
                commitMessage = [commitMessage stringByAppendingFormat:@" (was revision %@)", [sourceFile revisionInRepository]];
            }
            commitRequest = [CvsCommitRequest cvsCommitRequestForFiles:[NSArray arrayWithObjects:newPathName, oldPathName, nil] inPath:workAreaRootPath message:commitMessage];
        }
        else
            commitRequest = [CvsCommitRequest cvsCommitRequestForFiles:[NSArray arrayWithObject:newPathName] inPath:workAreaRootPath message:commitMessage];

        NSAssert1(commitRequest != nil, @"Could not create CvsCommitRequest for %@", newPathName);
        if ( removeRequest != nil ) {
            [commitRequest addPrecedingRequest:removeRequest];
        } else {
            [commitRequest addPrecedingRequest:addRequest];
        }
        childRequest = commitRequest;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renameCompleted:) name:@"RequestCompleted" object:childRequest];
    [childRequest schedule];

    // If we don't revalidate parents, 'add' will not see content of newly added directories
    [[[CVLFile treeAtPath:oldFullPathName] parent] invalidateAll];
    [[[CVLFile treeAtPath:newFullPathName] parent] invalidateAll];
    (void)[(CVLFile *)[[CVLFile treeAtPath:oldFullPathName] parent] status];
    (void)[(CVLFile *)[[CVLFile treeAtPath:newFullPathName] parent] status];
}

- (void) renameCompleted:(NSNotification *)aNotif
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[aNotif name] object:[aNotif object]];
    [self finishRenaming];
    if(![[aNotif object] succeeded]){
        // We could warn user
    }
}

@end

@implementation CVLFile(RemoveCVSDirectory)

- (void) removeCVSDirectory
{
    NSDirectoryEnumerator	*dirEnum;
    NSFileManager			*fileManager = [NSFileManager defaultManager];
    NSString				*aSubpath;

    (void)[fileManager removeFileAtPath:[[self path] stringByAppendingPathComponent:@"CVS"] handler:nil];
    dirEnum = [fileManager enumeratorAtPath:[self path]];
    while ( (aSubpath = [dirEnum nextObject]) ) {
        [(CVLFile *)[CVLFile treeAtPath:[[self path] stringByAppendingPathComponent:aSubpath]] removeCVSDirectory];
    }
}

@end
