
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "VLLogInspector.h"
#import <ResultsRepository.h>
#import "WorkAreaViewer.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>
#import <CvsTag.h>
#import <RetrievePanelController.h>


@implementation VLLogInspector


- (IBAction) showDifference:(id)sender
    /*" This action method is implemented by subclasses. This method does an 
        comparison between two different revsisons of the currently inspected 
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
        
        lvalue = [[versionArray objectAtIndex:firstRow] objectForKey:@"revision"];

        nextRow = [anIndexSet indexGreaterThanIndex:firstRow];
        if ( nextRow != NSNotFound ) {
            rvalue = [[versionArray objectAtIndex:nextRow] objectForKey:@"revision"];
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

- (NSString *) versionStringIn:(id)aVersion
    /*" This method is implemented by this subclass. This method returns a string 
        representation of a revision. 
    "*/
{
    NSString *aRevision = nil;
    
    SEN_ASSERT_CLASS(aVersion, @"NSDictionary");

    aRevision = [(NSDictionary *)aVersion objectForKey:@"revision"];
    return aRevision;
}

- (IBAction) showLog:sender
{
}

- (IBAction )select:sender
{
    NSString *logMsg = @"";
    NSDictionary *logDict = nil;
    int theNumberOfSelectedRows = 0;
    int theSelectedRow = 0;
    
    theNumberOfSelectedRows = [table numberOfSelectedRows];
    if ( theNumberOfSelectedRows == 1 ) {
        theSelectedRow = [table selectedRow];
        if ( theSelectedRow != -1 ) {
            if ( [versionArray count] > theSelectedRow ) {
                logDict = [versionArray objectAtIndex:theSelectedRow];
                logMsg = [logDict objectForKey:@"msg"];
            }                    
        }
    }
    [logField setString:[[logMsg copy] autorelease]];
}

- (NSString *) versionStringOfInspectedCVLFile
    /*" This method returns the revision of the inspected workarea file as a
        string or "N/A" if the inspected workarea file has no revision. If there
        is no inspected workarea file then nil is returned. if there is more 
        than one inspected workarea file then the first one is used.
    "*/
{
    NSString *aPath = nil;
    CVLFile *aCVLFile = nil;
    NSString *aRevision = nil;
    
    aPath = [self firstInspectedFile];
    if ( isNotEmpty(aPath) ) {
        aCVLFile = (CVLFile *)[CVLFile treeAtPath:aPath];
        aRevision = [aCVLFile revisionInWorkArea];
    }    
    return aRevision;
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
        newVersionArray=[(CVLFile *)[CVLFile treeAtPath:aPath] log];    
    }
    if (versionArray != newVersionArray) {
        [self setVersionArray:newVersionArray];
        [table reloadData];
        [self selectVersionOfInspectedCVLFile];
    }
    [resultsRepository endUpdate];
}


@end

//-------------------------------------------------------------------------------------

@implementation VLLogInspector (NSTableViewDelegate)

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if([cell isKindOfClass:[NSTextFieldCell class]]){
        NSColor	*textColor = [NSColor controlTextColor];

        if([[[[self versionArray] objectAtIndex:row] objectForKey:@"state"] isEqualToString:@"dead"]){
            // State <dead> means that file has been removed from cvs and committed
            static NSColor	*myRedColor = nil;

            if(!myRedColor)
                ASSIGN(myRedColor, [NSColor colorWithCalibratedRed:0.74 green:0.0 blue:0.0 alpha:1.0]);
            textColor = myRedColor;
        }
        [(NSTextFieldCell *)cell setTextColor:textColor];
    }
}


@end

//-------------------------------------------------------------------------------------


@implementation VLLogInspector (NSTableDataSource)


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
  if (tableView == table)
  {
    id theValue = [[[self versionArray] objectAtIndex: row] objectForKey: [tableColumn identifier]];
    if ( (theValue == nil) || (theValue == [NSNull null]) )
    {
      return @""; 
    }
    return theValue;
  }
  return nil;
}


@end
