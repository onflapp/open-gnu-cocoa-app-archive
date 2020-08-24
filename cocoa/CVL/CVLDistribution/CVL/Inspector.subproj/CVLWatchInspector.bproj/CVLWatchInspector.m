//
//  CVLWatchInspector.m
//  CVL
//
//  Created by Isa Kindov on Tue Jul 09 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import "CVLWatchInspector.h"
#import "CVLFile.h"
#import <ResultsRepository.h>
#import <SenFoundation/SenFoundation.h>

#import <CvsEditor.h>
#import <CvsWatcher.h>



@implementation CVLWatchInspector


- (void) update
{
    // I assume the inspected array contains only one element
    CVLFile *aCVLFile;
    ResultsRepository* resultsRepository = [ResultsRepository sharedResultsRepository];
    NSString* element;
    
    [resultsRepository startUpdate];
    element=(NSString*) [inspected objectAtIndex: 0];
    aCVLFile=(CVLFile *)[CVLFile treeAtPath:element];

    [cachedEditors release];
    cachedEditors = [[aCVLFile cvsEditors] copy];
    [editorTableView reloadData];
    [cachedWatchers release];
    cachedWatchers = [[aCVLFile cvsWatchers] copy];
    [watcherTableView reloadData];

    [resultsRepository endUpdate];
}

- (int) numberOfRowsInTableView:(NSTableView *)tableView
{
    if ( tableView == watcherTableView ) {
        return [cachedWatchers count];
    } else if ( tableView == editorTableView ) {
        return [cachedEditors count];
    }
    
    SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
        @"A NSTableView \"%@\" should be one of watcherTableView \"%@\"  or editorTableView \"%@\" but it is not!", 
        tableView, watcherTableView, editorTableView]));
    
    return 0;
}

- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    CvsWatcher *aWatcher = nil;
    CvsEditor *anEditor = nil;
    NSString *anIdentifier = nil;
    id aValue = nil;
    SEL aSelector;
    
    if ( tableView == watcherTableView ) {
        aWatcher = [cachedWatchers objectAtIndex:row];
        anIdentifier = [tableColumn identifier];
        SEN_ASSERT_NOT_EMPTY(anIdentifier);
        aSelector = NSSelectorFromString(anIdentifier);
        SEN_ASSERT_CONDITION([aWatcher respondsToSelector:aSelector]);
        
        aValue = [aWatcher performSelector:aSelector];
        // Append the string "(temporary)" to the username if it is temporary.
        if ( [anIdentifier isEqualToString:@"username"] ) {
            if ( [[aWatcher isTemporary] boolValue] ) {
                aValue = [NSString stringWithFormat:@"%@ (temporary)", aValue];
            }
        }
        if ( (tableColumn == editTableColumn) ||
             (tableColumn == uneditTableColumn) ||
             (tableColumn == commitTableColumn) ) {
            if ( [aValue boolValue] == YES ) {
                aValue = aCheckMark;
            } else {
                aValue = nil;
            }
        }        
        return aValue;
        
    } else if ( tableView == editorTableView ) {
        anEditor = [cachedEditors objectAtIndex:row];
        anIdentifier = [tableColumn identifier];
        SEN_ASSERT_NOT_EMPTY(anIdentifier);
        aSelector = NSSelectorFromString(anIdentifier);
        SEN_ASSERT_CONDITION_MSG(([anEditor respondsToSelector:aSelector]),
                                 ([NSString stringWithFormat:
                                     @"A CvsEditor object does not respond to the selector -%@", 
                                     anIdentifier]));
        
        aValue = [anEditor performSelector:aSelector];
        return aValue;
    }
    
    SEN_ASSERT_CONDITION_MSG((NO), ([NSString stringWithFormat:
        @"A NSTableView \"%@\" should be one of watcherTableView \"%@\"  or editorTableView \"%@\" but it is not!", 
        tableView, watcherTableView, editorTableView]));
    
    return nil;
}

- (void) awakeFromNib
{
    NSImageCell *anEditImageCell = nil;
    NSImageCell *anUneditImageCell = nil;
    NSImageCell *anCommitImageCell = nil;
    
    SEN_ASSERT_NOT_NIL(editorTableView);
    SEN_ASSERT_NOT_NIL(watcherTableView);
    SEN_ASSERT_NOT_NIL(editTableColumn);
    SEN_ASSERT_NOT_NIL(uneditTableColumn);
    SEN_ASSERT_NOT_NIL(commitTableColumn);

    aCheckMark = [NSImage imageNamed:@"check.tiff"];
    [aCheckMark retain];
    anEditImageCell = [[NSImageCell alloc] initImageCell:nil];
    anUneditImageCell = [[NSImageCell alloc] initImageCell:nil];
    anCommitImageCell = [[NSImageCell alloc] initImageCell:nil];
    [editTableColumn setDataCell:anEditImageCell];
    [uneditTableColumn setDataCell:anUneditImageCell];
    [commitTableColumn setDataCell:anCommitImageCell];
    
    [view retain];
}

@end
