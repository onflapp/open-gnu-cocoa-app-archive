/* VLTagInspector.m created by vincent on Wed 20-May-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "VLTagInspector.h"
#import <ResultsRepository.h>
#import "WorkAreaViewer.h"
#import <AppKit/AppKit.h>
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>
#import <CvsTag.h>
#import <RetrievePanelController.h>


@implementation VLTagInspector


- (NSString *) versionStringIn:(id)aVersion
    /*" This method is implemented by this subclass. This method returns a string 
        representation of a tag. In this case it is the tag's title.
    "*/
{
    NSString *aRevision = nil;
    
    SEN_ASSERT_CLASS(aVersion, @"CvsTag");

    aRevision = [(CvsTag *)aVersion tagTitle];
    return aRevision;
}

- (NSString *) versionStringOfInspectedCVLFile
    /*" This method returns the tag of the inspected workarea file as a
        string or nil if the inspected workarea file has no tag. If there
        is no inspected workarea file then nil is returned. If there is more 
        than one inspected workarea file then the first one is used.
    "*/
{
    NSString *aPath = nil;
    CVLFile *aCVLFile = nil;
    NSString *aTagString = nil;
    
    aPath = [self firstInspectedFile];
    if ( isNotEmpty(aPath) ) {
        aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];
        aTagString = [aCVLFile strippedStickyTag];
    }
    return aTagString;
}

- (IBAction) showDifference:(id)sender
    /*" This action method is implemented by subclasses. This method does an 
        comparison between two different tags of the currently inspected 
        workarea file by calling the method 
        #{compareLeftKey:value:withRightKey:value:}.
    "*/
{
    unsigned int    firstRow = 0;
    unsigned int    nextRow = 0;
    NSIndexSet      *anIndexSet = nil;
    
    anIndexSet = [table selectedRowIndexes];
    if ( [anIndexSet count] > 2 ) {
        (void)NSRunAlertPanel(@"Tags Inspector",
                              @"You have selected %d tags. The show differences can only take two arguments. One of these can default to the workarea file. So select either one or two of the tags.", 
                              nil, nil, nil, [anIndexSet count]); 
        return;
    }
    firstRow = [anIndexSet firstIndex];
    if ( firstRow != NSNotFound ) {
        NSString	*lvalue;
        NSString	*rvalue = nil;

        lvalue = [[versionArray objectAtIndex:firstRow] tagTitle];
        
        nextRow = [anIndexSet indexGreaterThanIndex:firstRow];
        if ( nextRow != NSNotFound ) {
            rvalue = [[versionArray objectAtIndex:nextRow] tagTitle];
            [self compareLeftKey:@"LeftTag" value:lvalue 
                    withRightKey:@"RightTag" value:rvalue];
        } else {
            [self compareLeftKey:@"LeftTag" value:lvalue 
                    withRightKey:nil value:nil];
        }
    } else {
        NSBeep();
    }
}


- (void) update
{
    ResultsRepository* resultsRepository = nil;
    NSString* aPath = nil;
    NSArray *newVersionArray = nil;
    
    resultsRepository = [ResultsRepository sharedResultsRepository];
    aPath = [self firstInspectedFile];
    [resultsRepository startUpdate];
    if ( isNotEmpty(aPath) ) {
        newVersionArray=[(CVLFile *)[CVLFile treeAtPath:aPath] tags];    
    }
    if (versionArray != newVersionArray) {
        [self setVersionArray:newVersionArray];
        [table reloadData];
        [self selectVersionOfInspectedCVLFile];
    }
    [resultsRepository endUpdate];
}

- (IBAction) copyTag:(id)sender
{
    NSArray         *pbTypes = [NSArray arrayWithObject:NSStringPboardType];
    NSPasteboard    *pb = [NSPasteboard generalPasteboard];
    
    [pb declareTypes:pbTypes owner:nil];
    [pb addTypes:pbTypes owner:nil];
    [pb setString:[self selectedVersionString] forType:NSStringPboardType];
}

- (BOOL) validateMenuItem:(id <NSMenuItem>)menuItem
{
    if([menuItem action] == @selector(copyTag:))
        return ([table numberOfSelectedRows] == 1);
    else
        return [super validateMenuItem:menuItem];
}

@end

@implementation VLTagInspector (NSTableViewDelegate)

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    CvsTag *aCvsTag = nil;
    NSColor	*textColor = nil;

    SEN_ASSERT_CONDITION((tableView == table));

    if ( [cell isKindOfClass:[NSTextFieldCell class]] == YES ) {
        textColor = [NSColor controlTextColor];
        aCvsTag = [versionArray objectAtIndex:row];
        if ( [aCvsTag isABranchTag] == YES ) {
            textColor = [NSColor blueColor];
        }
        [(NSTextFieldCell *)cell setTextColor:textColor];
    }
}


@end


//-------------------------------------------------------------------------------------

@implementation VLTagInspector (NSTableDataSource)


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    NSString *theValue = @"";
    NSString *anIdentifier = nil;
    CvsTag *aCvsTag = nil;
    
    anIdentifier = [tableColumn identifier];
    aCvsTag = [versionArray objectAtIndex:row];
    
  if (tableView == table) {
      if ( [anIdentifier isEqualToString:@"tagRevision"] ) {
          theValue = [aCvsTag tagRevision];
      } else if ( [anIdentifier isEqualToString:@"tagTitle"] ) {
          theValue = [aCvsTag tagTitle];
      } else if ( [anIdentifier isEqualToString:@"isABranchTagAsANumber"] ) {
          if ( [aCvsTag isABranchTag] == YES ) {
              theValue = @"branch";
          } else {
              theValue = @"revision";
          }
      }
    return theValue;
  }
  return nil;
}


@end

