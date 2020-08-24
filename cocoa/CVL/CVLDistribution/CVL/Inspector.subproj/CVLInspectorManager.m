
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLInspectorManager.h"
#import "NoInspector.h"
#import "NSView_SenAdditions.h"
#import "NSView_SenAdditions.h"
#import "CVLFile.h"
#import <CVLDelegate.h>
#import <NSFileManager_CVS.h>
#import <ResultsRepository.h>
#import <SenFoundation/SenFoundation.h>
#import <NSBundle_CVLAdditions.h>
#import <SenBundleLibrarian.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "CVLFileIconWell.h"
#import "CVLFileIconWellCell.h"


#define SHOW_INSPECTOR_PREFERENCE @"ShowInspector"
#define FRAME_NAME_PREFERENCE     @"Inspector"
#define TOOLS_MENU_ITEM_TAG			854
#define INSPECTOR_MENU_ITEM_TAG		855


static NSString *BundleTypeKey = @"SenBundleType";
static NSString *InspectorType = @"CVLInspector";

static NSString *InspectorNameKey = @"name";
static NSString *InspectorTitleKey = @"title";
static NSString *InspectorKeyEquivalentKey = @"key";


@interface CVLInspectorManager (_Private)
- (void) update;
- (void) updateFields;
- (void) updateInspector;
- (BOOL) canRename;
@end


@interface NSBundle (InspectorOrdering)
- (NSComparisonResult) compareForMenuOrdering:(NSBundle *)other;
@end


@implementation NSBundle (InspectorOrdering)
- (NSComparisonResult) compareForMenuOrdering:(NSBundle *)other
{
    NSString *selfKey = [self objectForKey:InspectorKeyEquivalentKey];
    NSString *otherKey = [other objectForKey:InspectorKeyEquivalentKey];
    return [selfKey compare:otherKey];
}
@end


@implementation CVLInspectorManager
+ (void) initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"NO", SHOW_INSPECTOR_PREFERENCE, nil]];
}


+ (CVLInspectorManager *) sharedInspector
{
    static id theInspector = nil;
    if (!theInspector) {
        theInspector = [[self alloc] init];
    }
    return theInspector;
}

- (IBAction) showWindow:(id)sender
{
    [[self window] makeKeyAndOrderFront:sender];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SHOW_INSPECTOR_PREFERENCE];
}

- (void) setupInspectorDictionary
{
    NSArray *inspectorBundleArray = [SenBundleLibrarian bundlesWithValue:InspectorType forString:BundleTypeKey];
    NSEnumerator *inspectorBundleEnumerator = [inspectorBundleArray objectEnumerator];
    NSBundle *inspectorBundle = nil;
    NSString *inspectorBundleName = nil;
    BOOL cvsEditorsAndWatchersEnabled = NO;

    cvsEditorsAndWatchersEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"CvsEditorsAndWatchersEnabled"];
    
    inspectorDictionary = [[NSMutableDictionary alloc] init];
    while ( (inspectorBundle = [inspectorBundleEnumerator nextObject]) ) {
        inspectorBundleName = [inspectorBundle objectForKey:InspectorNameKey];
        // Only add the EditorsAndWatchers inspector if it has been
        // enabled in the preferences.
        if ( [inspectorBundleName isEqualToString:@"EditorsAndWatchers"] ) {
            if ( cvsEditorsAndWatchersEnabled == YES ) {
                [inspectorDictionary setObject:inspectorBundle 
                                        forKey:inspectorBundleName];
            }
        } else {
            [inspectorDictionary setObject:inspectorBundle 
                                    forKey:inspectorBundleName];
        }
    }
}


- (void) setupPopUpMenu
{
    NSArray *orderedInspectors = [[inspectorDictionary allValues] sortedArrayUsingSelector:@selector(compareForMenuOrdering:)];
    NSEnumerator *inspectorEnumerator = [orderedInspectors objectEnumerator];
    NSBundle *inspectorBundle = nil;
    NSMenu		*inspectorMenu = [[[[[NSApp mainMenu] itemWithTag:TOOLS_MENU_ITEM_TAG] submenu] itemWithTag:INSPECTOR_MENU_ITEM_TAG] submenu];
    NSString *aTitle = nil;
    NSString *aKeyEquivalent = nil;
    NSMenuItem *aPopupMenuItem = nil;
    NSMenuItem *aMenuItem = nil;
    
    [inspectorPopup removeAllItems];
    while ( (inspectorBundle = [inspectorEnumerator nextObject]) ) {        
        aTitle = [inspectorBundle objectForKey:InspectorTitleKey];
        [inspectorPopup addItemWithTitle:aTitle];
        aPopupMenuItem = (NSMenuItem *)[inspectorPopup itemWithTitle:aTitle];
        [aPopupMenuItem setRepresentedObject:inspectorBundle];
        // We cannot set the same keyEquivalents in more than one menuItem, thus we put it only in the main menu
        // and no longer in the popup menu.

        aKeyEquivalent = [inspectorBundle objectForKey:InspectorKeyEquivalentKey];
        aMenuItem = (NSMenuItem *)[inspectorMenu 
                    addItemWithTitle:aTitle 
                              action:@selector(setInspectorFromMenuItem:) 
                       keyEquivalent:aKeyEquivalent];
		[aMenuItem setTarget:self];
        [aMenuItem setMnemonicLocation:0]; // In fact, it should be defined in bundle dict...
        [aMenuItem setRepresentedObject:inspectorBundle];
    }
    [inspectorPopup setTarget:self];
    [inspectorPopup setAction:@selector(setInspectorFromPopup:) ];
    
    [inspectorMenu removeItemAtIndex:0]; // Was dummy item
}

- init
{
    self = [super init];
    [NSBundle loadNibNamed:@"InspectorManager" owner:self];

    [[NSNotificationCenter defaultCenter]
                addObserver:self
                   selector:@selector(selectionDidChange:)
                       name:SenSelectionDidChangeNotification
                     object:[(CVLDelegate *)[[NSApplication sharedApplication] delegate] globalSelection]];

    [[NSNotificationCenter defaultCenter]
                addObserver:self
                   selector:@selector(resultsChanged:) 
                       name:@"ResultsChanged"
                     object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewerWillClose:) name:@"ViewerWillClose" object:nil];

    // We should also be observer of NSWindowDidBecomeMainNotification, to handle some cases (unhide of app and insp is key!)

    [self setupInspectorDictionary];
    [self setupPopUpMenu];
    [(CVLFileIconWellCell *)[fileIconWell cell] setImageScaling:NSScaleToFit];
    [fileIconWell setDelegate:self];
    [fileIconWell setTarget:self];
    [fileIconWell setDoubleAction:@selector(iconWellWasDoubleClicked:)];

    currentInspector = nil;
    [multiView setAutoresizesSubviews:YES];
    [self updateFields]; //needed here to force the NoInspector to be known
    [self updateInspector]; // (this feature disappared because update is done only when window is visible)
	
    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE(currentInspector);
    RELEASE(inspectedObjects);
    RELEASE(inspectorDictionary);
    [super dealloc];
}


- (NSWindow *) window
{
    return window;
}


- (void) updateFields
{
    NSString *filePath = @"";
    NSString *filename = @"No selection";
    int numberOfInspectedObjects = [inspectedObjects count];

    if (numberOfInspectedObjects > 0) {
        NSString *fullPath = [inspectedObjects objectAtIndex:0];
        filePath = [fullPath stringByDeletingLastPathComponent];
        if (numberOfInspectedObjects == 1)
            filename = [fullPath lastPathComponent];
        else
            filename = [NSString stringWithFormat:@"%d items", numberOfInspectedObjects];
    }
    [fileIconWell reloadData];
    [fullPathTextField setStringValue:[filePath stringByAbbreviatingWithTildeInPath]];
    [filenameTextField setStringValue:filename];
    [filenameTextField setEditable:[self canRename]];
}


- (CVLInspector *) currentInspector
{
    return currentInspector;
}


- (void) detachCurrentInspector
{
    if (currentInspector) {
        NSView *currentView = [currentInspector view];
        [currentView removeFromSuperview];
        RELEASE(currentInspector);
    }
}


- (void) attachInspector:(CVLInspector *) anInspector
{
    ASSIGN(currentInspector, anInspector);
    {
        NSView *neededView = [currentInspector view];
        [multiView addSubview:neededView isFilling:YES];
        [multiView setNeedsDisplay:YES];
        [window makeFirstResponder:neededView];
    }
}


- (void) setCurrentInspector:(CVLInspector *) anInspector
{
    if ([self currentInspector] != anInspector) {
        [self detachCurrentInspector];
        [self attachInspector:anInspector];
    }
}


- (void) updateInspector
{
    int numberOfInspectedObjects = [inspectedObjects count];
    CVLInspector *neededInspector = [NoInspector sharedInstance];
    NSMenuItem *theSelectedItem = nil;
    NSBundle *inspectorBundle = nil;

    if (numberOfInspectedObjects == 1) {        
        theSelectedItem = (NSMenuItem *)[inspectorPopup selectedItem];
        inspectorBundle = [theSelectedItem representedObject];
        neededInspector = [[inspectorBundle principalClass] sharedInstance];

        SEN_ASSERT_NOT_NIL(neededInspector);
        SEN_ASSERT_CLASS(neededInspector, @"CVLInspector");
    }
    
    [self setCurrentInspector:neededInspector];
}


- (void) update
{
    [self updateFields];
    [self updateInspector];
    [[self currentInspector] setInspected:inspectedObjects];
    //[window setNeedsDisplay:YES];
}


- (void) selectionDidChange:(NSNotification *) notification
{
    // We don't need to check if [notification object] is nil; 
	// it could happen and means there is nothing to inspect
    [self setInspected:[[notification object] selectedObjects]];
}


- (void) resultsChanged:(NSNotification *) notification
{
    if (([inspectedObjects count] == 1) && ([[notification object] hasChanged]) ) {
        if ([[[notification object] changedFiles] containsObject:[CVLFile treeAtPath:[inspectedObjects objectAtIndex:0]]]) {
            if ([window isVisible]) [self update];
        }
    }
}

- (void) endEditings
{
    [window makeFirstResponder:window];
}

- (void) setInspected:(NSArray *) anArray
{
    if (anArray!=inspectedObjects) {
        if ((!anArray) || (![anArray isEqual:inspectedObjects])) {
            [self endEditings];
            [inspectedObjects autorelease];
            inspectedObjects = [anArray copy];
            if ([window isVisible]) [self update];
        }
    }
}


- (IBAction) setInspectorFromPopup:(id)sender
{
    NSString *inspectorTitle = [[sender selectedCell] title];
    NSBundle *inspectorBundle = nil;
    NSMenuItem *theSelectedItem = nil;
    
    theSelectedItem = (NSMenuItem *)[sender selectedItem];
    inspectorBundle = [theSelectedItem representedObject];
    SEN_ASSERT_NOT_NIL(inspectorBundle);
    [inspectorPopup setTitle:inspectorTitle];
    [window setTitle:[inspectorBundle objectForKey:InspectorTitleKey]];

    [self update];
    [window orderFront:self];
}

- (IBAction) setInspectorFromMenuItem:(id)sender
{
    NSString *inspectorTitle = [sender title];
    NSBundle *inspectorBundle = nil;

    inspectorBundle = [sender representedObject];
    SEN_ASSERT_NOT_NIL(inspectorBundle);
    [inspectorPopup setTitle:inspectorTitle];
    [window setTitle:[inspectorBundle objectForKey:InspectorTitleKey]];

    [self update];
    [self showWindow:sender];
}

- (NSArray *) filenamesForFileIconWell:(CVLFileIconWell *)aFileIconWell
{
    return inspectedObjects;
}

- (BOOL) iconWellShouldStartDragging:(CVLFileIconWell *)aFileIconWell
{
    if([inspectedObjects count] == 1 && [(CVLFile *)[CVLFile treeAtPath:[inspectedObjects lastObject]] flags].type == ECAbsentFile)
        return NO;
    else
        return YES;
}

- (void) iconWellWasDoubleClicked:(id)sender
{
    int	aCount = [inspectedObjects count];

    if(aCount == 0)
        return;
    if(aCount == 1 && [(CVLFile *)[CVLFile treeAtPath:[inspectedObjects lastObject]] flags].type == ECAbsentFile)
        return;
    // Will not work when console or repository list is mainwindow
    [NSApp sendAction:@selector(openFilesInWS:) to:nil from:self];
}

- (BOOL) canRename
{
    CVLFile *inspectedFile=nil;

    if ([inspectedObjects count]==1) {
        inspectedFile=(CVLFile *)[CVLFile treeAtPath:[inspectedObjects objectAtIndex:0]];
        if ([inspectedFile have].flags) {
            if ([inspectedFile flags].isInWorkArea) {
                return YES;
            }
        }
    }
    return NO;
}

- (IBAction) nameEdited:(id)sender
{
    if ([inspectedObjects count]==1) {
        CVLFile *inspectedFile=nil;
        NSFileManager *fileManager=[NSFileManager defaultManager];
        NSString *oldPath;
        NSString *newPath=nil;
        NSString *newName;
        ResultsRepository *resultsRepository=[ResultsRepository sharedResultsRepository];
        BOOL success=NO;

        [resultsRepository startUpdate];

        oldPath=[inspectedObjects objectAtIndex:0];
        inspectedFile=(CVLFile *)[CVLFile treeAtPath:oldPath];
        newName=[sender stringValue];

        if ([newName length]) {
            newPath=[[oldPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName];

            if ([fileManager movePath:oldPath toPath:newPath handler:nil]) {
                if (![inspectedFile isLeaf]) {
                    [fileManager moveCVSAdministrativeFilesFromPath:newPath to:oldPath];
                }
                success=YES;
            }
        }

        if (success) {
            [(CVLFile *)[CVLFile treeAtPath:[oldPath stringByDeletingLastPathComponent]] invalidateChildren];
            [inspectedFile traversePostorder:@selector(invalidateAll)];
            [(CVLFile *)[CVLFile treeAtPath:newPath] traversePostorder:@selector(invalidateAll)];
        } else {
            [filenameTextField setStringValue:[oldPath lastPathComponent]];
        }
        [resultsRepository endUpdate];
    }
}

- (void) viewerWillClose:(NSNotification *)notification
{
    [self selectionDidChange:nil];
}

@end


@implementation CVLInspectorManager (WindowDelegationNotification) 
- (void) windowWillClose:(NSNotification *) notification;
{
    if([[NSApplication sharedApplication] isRunning]) // On MOXS, method also is called when app is terminating!
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SHOW_INSPECTOR_PREFERENCE];
}

- (NSSize) windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    // To avoid resizing problems (centering of elements),
    // let's force resizing on even values
    proposedFrameSize.height = ((int)proposedFrameSize.height / 2) * 2;
    proposedFrameSize.width = ((int)proposedFrameSize.width / 2) * 2;

    return proposedFrameSize;
}

@end
