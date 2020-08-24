//
//  CVLVersionInspector.m
//  CVL
//
//  Created by William Swats on Mon May 17 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

/*" This class is an abstract superclass for VLLogInspector and VLTagInspector. 
    These two subclasses had much in common and hence were duplicating a lot of
    code. Thus that code has now become the basis for this superclass.
"*/

#import "CVLVersionInspector.h"

#import <ResultsRepository.h>
#import "WorkAreaViewer.h"
#import <NSArray_RevisionComparison.h>
#import <CVLOpendiffRequest.h>
#import <CvsUpdateRequest.h>
#import <SelectorRequest.h>
#import <AppKit/AppKit.h>
#import "CVLFile.h"
#import <SenFoundation/SenFoundation.h>
#import <CvsTag.h>
#import <RetrievePanelController.h>
#import <CVLDelegate.h>


@implementation CVLVersionInspector


- (void) awakeFromNib
    /*" The double action and target are set for the NSTableView here. The 
        column positions and sizes are set to be autosaved. The version array is 
        created with spaces for 100 entries. And a mutable array is created to 
        hold the last selected versions.
    "*/
{    
    [table setDoubleAction:@selector(showDifference:)];
    [table setTarget:self];
    [table setAutosaveTableColumns:YES];
    
    versionArray = [NSMutableArray arrayWithCapacity:100];
    [versionArray retain];
    
    lastSelectedObjects = [[NSMutableArray alloc] initWithCapacity:2];
}

- (void) compareLeftKey:(NSString *)lkey value:(NSString *)lvalue withRightKey:(NSString *)rkey value:(NSString *)rvalue
    /*" This method does an comparison between two different versions of the
        currently inspected workarea file by launching opendiffRequest.
    "*/
{
    NSMutableDictionary	*currentParams = [NSMutableDictionary dictionary];
    CVLOpendiffRequest	*aRequest;
    CVLFile *aFile = nil;
    NSString *aPath = nil;

    [currentParams setObject:lvalue forKey:lkey];
    if(rvalue)
        [currentParams setObject:rvalue forKey:rkey];

    aPath = [self firstInspectedFile];
    if ( isNotEmpty(aPath) ) {
        aFile= (CVLFile *)[CVLFile treeAtPath:aPath];
        aRequest = [[CVLOpendiffRequest alloc] initWithFile:aFile parameters:currentParams];
        [aRequest schedule];
        [aRequest release];        
    }
}

- (IBAction) showDifference:(id)sender
    /*" This action method is implemented by subclasses. This method does an 
        comparison between two different versions of the currently inspected 
        workarea file by calling the method #{compareLeftKey:value:withRightKey:value:}.
         See the subclasses for more information.
    "*/
{
    SEN_SUBCLASS_RESPONSIBILITY;
}

- (IBAction )select:sender
{
}

- (void) selectVersionOfInspectedCVLFile
    /*" This method selects the version of the currently inspected workarea file
        in the table view and then scrolls the table view so that the selected 
        version is visible.
    "*/
{
    id theVersionOfInspectedCVLFile = nil;
    unsigned int anIndex = 0;
    
    if ( isNotEmpty(versionArray) ) {
        theVersionOfInspectedCVLFile = [self versionInArrayMatchingInspectedCVLFile];
        [table deselectAll:nil]; // If selected index does not change, no notif will be sent => deselect then reselect every time
        if ( theVersionOfInspectedCVLFile != nil) {  // select this row in table
            anIndex = [versionArray indexOfObject:theVersionOfInspectedCVLFile];

            if ( anIndex != NSNotFound ) {
                [table selectRow:anIndex byExtendingSelection:NO];
                [table scrollRowToVisible:anIndex];
            }
        }
    }
    [self select:nil];
}

- (NSString *) versionStringIn:(id)aVersion
    /*" This method is implemented by subclasses. This method returns a string 
        representation of aVersion. 
    "*/
{
    SEN_SUBCLASS_RESPONSIBILITY;
    return nil;
}

- (NSString *) selectedVersionString;
    /*" This method returns the selected version as a string. Uses the method 
        #versionStringIn: to obtain the version string from subclasses.
    "*/
{
    NSString        *aRevisionString = nil;
    id              aVersion;
    int             aRow = 0;
    
    aRow = [table selectedRow];
    if ( aRow >= 0 ) {
        if ( aRow < (int)[versionArray count] ) {
            aVersion = [versionArray objectAtIndex:aRow];
            aRevisionString = [self versionStringIn:aVersion];
        }
    }
    return aRevisionString;    
}

- (NSString *) versionStringOfInspectedCVLFile
    /*" This method is implemented by subclasses. The subclasses return a string
        that represents the version of the CVLfile being inspected. See the
        subclasses for more information.
    "*/
{
    SEN_SUBCLASS_RESPONSIBILITY;
    return nil;
}

- (id) versionInArrayMatchingInspectedCVLFile
    /*" This method returns the version in the versionArray that matches the 
        version in the currently inspected workarea file or nil if there is not 
        one. It is up to the subclass to determine what class of object is to be
        returned. See the subclass implementations for more information.
    "*/
{
    NSString *aVersionString = nil;
    NSString *aVersionStringOfInspectedCVLFile = nil;
    NSString *versionInArrayMatchingInspectedCVLFile = nil;
    id aVersion = nil;
    NSEnumerator *anEnumerator = nil;
    
    if ( isNotEmpty(versionArray) ) {
        aVersionStringOfInspectedCVLFile = [self versionStringOfInspectedCVLFile];
        if ( isNotEmpty(aVersionStringOfInspectedCVLFile) ) {
            anEnumerator = [versionArray objectEnumerator];
            while ( (aVersion = [anEnumerator nextObject]) ) {
                aVersionString = [self versionStringIn:aVersion];
                if ( [aVersionString isEqualToString:aVersionStringOfInspectedCVLFile] ) {
                    versionInArrayMatchingInspectedCVLFile = aVersion;
                    [[versionInArrayMatchingInspectedCVLFile retain] autorelease];
                    break;
                }
            }            
        }
    }        
    return versionInArrayMatchingInspectedCVLFile;
}

- (NSMutableArray *)versionArray
    /*" This is the get method for the instance variable named versionArray. 
        This mutable array contains the versions associated with the currently 
        inspected workarea file. This would be either an array of CvsTags or an 
        array of dictionaries containing log information.

        See Also #setVersionArray:.
    "*/
{
	return versionArray;
}

- (void)setVersionArray:(NSArray *)newVersionArray
    /*" This is the set method for the instance variable named versionArray. 
        This mutable array contains the versions associated with the currently 
        inspected workarea file. This would be either an array of CvsTags or an 
        array of dictionaries containing log information. This method adds the 
        entries in the newVersionArray into the versionArray. It does not retain 
        the newVersionArray. Also before adding them it sorts the entries using 
        the table view sort descriptors.

        See Also #versionArray.
    "*/
{
    NSArray *someSortDescriptors = nil;
    NSArray *theTableColumns = nil;
    NSSortDescriptor *aSortDescriptor = nil;
    NSTableColumn *aTableColumn = nil;
    
    [versionArray removeAllObjects];
    if ( newVersionArray != nil ) {
        SEN_ASSERT_CLASS(newVersionArray, @"NSArray");

        [versionArray addObjectsFromArray:newVersionArray];
                        
        someSortDescriptors = [table sortDescriptors];
        if ( isNotEmpty(someSortDescriptors ) ) {
            aSortDescriptor = [someSortDescriptors objectAtIndex:0]; 
        }
        if ( aSortDescriptor == nil ) {
            theTableColumns = [table tableColumns];    
            aTableColumn = [theTableColumns objectAtIndex:0];
            aSortDescriptor = [aTableColumn sortDescriptorPrototype];            
        }
        if ( aSortDescriptor != nil ) {
            someSortDescriptors = [NSArray arrayWithObject:aSortDescriptor];
            [versionArray sortUsingDescriptors:someSortDescriptors];
        }
    }
}

- (IBAction) replaceWorkAreaFile:(id)sender
    /*" This action method will replace the currently inspected workarea file 
        with the version selected in the table view. Only one version is allowed
        to be selected for this method to be enable. This method calls 
        #retrieveWorkAreaFileForAction:CVL_RETRIEVE_REPLACE to do the actually
        work. The replace method does not change any sticky attributes. It does 
        not add any nor removes any.
    "*/
{
    [self retrieveWorkAreaFileForAction:CVL_RETRIEVE_REPLACE];
}

- (IBAction) restoreWorkAreaFile:(id)sender
    /*" This action method will restore the currently inspected workarea file 
        with the version selected in the table view. Only one version is allowed
        to be selected for this method to be enable. This method calls 
        #retrieveWorkAreaFileForAction:CVL_RETRIEVE_RESTORE to do the actually
        work. The restore method either adds or changes the sticky attributes of
        the currently inspected workarea files to version selected in the table 
        view.
    "*/
{
    [self retrieveWorkAreaFileForAction:CVL_RETRIEVE_RESTORE];
}

- (void)retrieveWorkAreaFileForAction:(int)anActionType
    /*" This method will either replace or restore the contents of the selected
        workarea file(s) with the version specified. They will be replaced if 
        anActionType is CVL_RETRIEVE_REPLACE and they will be restored if anActionType is 
        CVL_RETRIEVE_RESTORE. This method calls 
        #retrieveWorkAreaFiles:inDirectory:withVersion:withDate:withHead:forAction: 
        to do most of the work.
    "*/
{
    NSString        *aVersion = nil;
    NSString        *aFilename = nil;
    NSString        *aPath = nil;
    NSString        *theSelectedDirectory = nil;
    NSArray         *theSelectedFilenames = nil;
    RetrievePanelController *aController = nil;
    
    // Beep and return if more than one row is selected.
    if ( [table numberOfSelectedRows] != 1 ) {
        NSBeep();    
        return;
    }
    
    // Get the selected tag, file name and directory path of the file,
    // then replace the version in the workarea with this one.
    aVersion = [self selectedVersionString];
    aPath = [self firstInspectedFile];
    SEN_ASSERT_NOT_EMPTY(aPath);
    aFilename = [aPath lastPathComponent];
    SEN_ASSERT_NOT_EMPTY(aFilename);
    
    aController=[RetrievePanelController sharedRetrievePanelController];
    SEN_ASSERT_NOT_NIL(aController);
    theSelectedFilenames = [NSArray arrayWithObject:aFilename];
    theSelectedDirectory = [aPath stringByDeletingLastPathComponent];
    (void)[aController retrieveWorkAreaFiles:theSelectedFilenames 
                                 inDirectory:theSelectedDirectory 
                                 withVersion:aVersion 
                                    withDate:nil 
                                    withHead:NO 
                                   forAction:anActionType];    
}

- (IBAction) openVersionInTemporaryDirectory:(id)sender
    /*" This action method will copy the version specified of the currently 
        inspected workarea file into the temporary directory and then open it. 
    "*/
{
    NSString        *aFilename = nil;
    NSString        *aVersion = nil;
    NSString        *aPath = nil;
    
    // Beep and return if more than one row is selected.
    if ( [table numberOfSelectedRows] != 1 ) {
        NSBeep();    
        return;
    }
    
    // Get the selected tag, file name and directory path of the file,
    // then open the version in the temporary directory.
    aVersion = [self selectedVersionString];
    SEN_ASSERT_NOT_EMPTY(aVersion);
    aPath = [self firstInspectedFile];
    SEN_ASSERT_NOT_EMPTY(aPath);
    aFilename = [aPath lastPathComponent];
    SEN_ASSERT_NOT_EMPTY(aFilename);

    [[NSApp delegate] openInTemporaryDirectory:aPath 
                                   withVersion:aVersion 
                                  orDateString:nil
                                      withHead:NO];
}

- (IBAction) saveVersionAs:(id)sender
    /*" This action method will save the version specified of the currently 
        inspected workarea file with the name and path given in the Save Panel 
        that will appear after clicking the SaveAs button. 
    "*/
{
    NSString        *aVersion = nil;
    NSString        *aPath = nil;
    
    // Beep and return if more than one row is selected.
    if ( [table numberOfSelectedRows] != 1 ) {
        NSBeep();    
        return;
    }
    
    // Get the selected tag, file name and directory path of the file,
    // then open the version in the temporary directory.
    aVersion = [self selectedVersionString];
    SEN_ASSERT_NOT_EMPTY(aVersion);
    aPath = [self firstInspectedFile];
    SEN_ASSERT_NOT_EMPTY(aPath);
    
    (void)[[NSApp delegate] save:aPath 
                     withVersion:aVersion 
                    orDateString:nil 
                        withHead:NO];
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
    /*" This is one of the NSTableDataSource methods. It returns the number of 
        rows in the table view. Here we are returning the count of the
        versionArray.
    "*/
{
    unsigned int aCount = 0;
    
    if (tableView == table) {
        aCount = [versionArray count];
    }
    return aCount;
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
    /*" This is one of the NSTableDataSource methods. It tells us when the sort 
        descriptors changed. Mostly due to the user clicking on a column heading.
        This tells the UI to sort the table rows based on that column or to 
        change the order of the sort if that column is already being used as the
        sort column.

        Based on which column has been selected (Note: column selection must be 
        enabled) and on the array of oldDescriptors this method determines how 
        to sort the versionArray. The sorting of versionArray determines the 
        sort order displayed via of the table view to the user.
    "*/
{
    NSArray *someSortDescriptors = nil;
    NSArray *theTableColumns = nil;
    NSSortDescriptor *aSortDescriptor = nil;
    NSSortDescriptor *aReversedSortDescriptor = nil;
    NSSortDescriptor *useSortDescriptor = nil;
    NSSortDescriptor *anOldSortDescriptor = nil;
    NSTableColumn *aTableColumn = nil;
    int theSelectedColumn = -1;
    unsigned int aCount = 0;
    unsigned int anIndex = 0;
    
    SEN_ASSERT_CONDITION((tableView == table));
    
    theTableColumns = [tableView tableColumns];
    // Note: We need to check the "Column Selection" checkbox in the nib for this
    // next statement to return the selected column; otherwise we will always
    // get -1 for theSelectedColumn. Hence we would never get any sorting.
    SEN_ASSERT_CONDITION(([tableView allowsColumnSelection]));
    
    theSelectedColumn = [tableView selectedColumn];
    if ( theSelectedColumn >= 0 ) {
        aTableColumn = [theTableColumns objectAtIndex:theSelectedColumn];
        aSortDescriptor = [aTableColumn sortDescriptorPrototype];
        
        if ( aSortDescriptor != nil ) {
            // The code below is solely to figure out the direction of the sort
            // since we have all the other information we need in aSortDescriptor.
            aReversedSortDescriptor = [aSortDescriptor reversedSortDescriptor];
            // If the sort descriptor for this column has not been saved in the
            // user defaults then we used what is in the nib.
            useSortDescriptor = aSortDescriptor;
            aCount = [oldDescriptors count];
            for ( anIndex = 0; anIndex < aCount; anIndex++ ) {
                anOldSortDescriptor = [oldDescriptors objectAtIndex:anIndex];
                // For an index equal to zero. 
                // Note: This index contains the last used sort descriptor; so
                // if it is the same as the one in the currently selected
                // column (ignoring the sort direction) then we reversed the
                // sort direction.
                if ( anIndex == 0 ) {
                    if ( [aSortDescriptor isEqual:anOldSortDescriptor] == YES ) {
                        useSortDescriptor = aReversedSortDescriptor;
                        break;
                    }
                    if ( [aReversedSortDescriptor isEqual:anOldSortDescriptor] == YES ) {
                        useSortDescriptor = aSortDescriptor;
                        break;
                    }                    
                }
                // For an index greater than  zero.
                // Note: These indices do not contain the last used sort 
                // descriptor; so we use the same sort direction as the previous 
                // sort on this column.
                else {
                    if ( [aSortDescriptor isEqual:anOldSortDescriptor] == YES ) {
                        useSortDescriptor = aSortDescriptor;
                        break;
                    }
                    if ( [aReversedSortDescriptor isEqual:anOldSortDescriptor] == YES ) {
                        useSortDescriptor = aReversedSortDescriptor;
                        break;
                    }                    
                }                
            }
            // The code above is solely to figure out the direction of the sort.
            
            someSortDescriptors = [NSArray arrayWithObject:useSortDescriptor];
            [versionArray sortUsingDescriptors:someSortDescriptors];
            [table reloadData];
        }        
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
    /*" This is one of the NSTableViewDelegate methods. It tells us when the 
        table view selection changed. Here we are updating the 
        lastSelectedObjects array.
    "*/
{
    unsigned int    aRow = 0;
    unsigned int    aCount = 0;
    NSIndexSet      *anIndexSet = nil;
    id              aVersion = nil;
    
    anIndexSet = [table selectedRowIndexes];
    if ( [anIndexSet count] > 0 ) {
        [lastSelectedObjects removeAllObjects]; 
        aCount = [versionArray count];
        aRow = [anIndexSet firstIndex];
        while ( aRow != NSNotFound ) {
            if ( aRow < aCount ) {
                aVersion = [versionArray objectAtIndex:aRow];
                if ( aVersion != nil ) {
                    [lastSelectedObjects addObject:aVersion];
                }                
            }
            aRow = [anIndexSet indexGreaterThanIndex:aRow];
        }            
    }
    [self select:nil];
}

- (void) tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
    /*" This is one of the NSTableViewDelegate methods. It tells us when the 
        user clicks on a table view column. Here we are re-selecting the last 
        known selected rows before the rows were re-sorted. The rows are 
        re-sorted because the user clicked on a column heading. This works only 
        because the method #{-tableView:sortDescriptorsDidChange:} is called 
        before this method. The method #{-tableView:sortDescriptorsDidChange:} 
        is the one that does the re-sorting.
    "*/
{
    NSMutableIndexSet   *anIndexSet = nil;
    id                  aVersion = nil;
    NSEnumerator        *anEnumerator = nil;
    unsigned int        anIndex = 0;
    unsigned int        aCount = 0;

    SEN_ASSERT_CONDITION((tableView == table));

    if ( isNotEmpty(lastSelectedObjects) ) {
        aCount = [tableView numberOfRows];
        anIndexSet = [NSMutableIndexSet indexSet];
        anEnumerator = [lastSelectedObjects objectEnumerator];
        while ( (aVersion = [anEnumerator nextObject]) ) {
            anIndex = [versionArray indexOfObject:aVersion];
            if ( anIndex < aCount ) {
                [anIndexSet addIndex:anIndex];
            }
        }
        if ( [anIndexSet count] > 0 ) {
            [tableView selectRowIndexes:anIndexSet 
                   byExtendingSelection:NO];
            [table scrollRowToVisible:[anIndexSet firstIndex]];            
        }
    }
}


@end


//-------------------------------------------------------------------------------------

@implementation CVLVersionInspector (MenuValidation)

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
    /*" Implemented to override the default action of enabling or disabling 
        menuItem. The object implementing this method must be the target of 
        menuItem. It returns YES to enable menuItem, NO to disable it. You can 
        determine which menu item menuItem is by querying it for its title, tag,
        or action.

        This method validates the menu items:
            _{1. Compare using FileMerge}
            _{2. Open Version in Temporary Directory}
            _{3. Replace WorkArea File with Version}
            _{4. Restore WorkArea File with Version}
            _{5. Save Version As...}
    "*/
{
    SEL anAction = NULL;
    NSString *anActionString= nil;
    
    anAction = [menuItem action];
    anActionString= NSStringFromSelector(anAction);
    
    // For menu item "Compare using FileMerge"
    if ( [anActionString isEqualToString:@"showDifference:"] ) {
        if ( ([table numberOfSelectedRows] == 1) ||
             ([table numberOfSelectedRows] == 2) ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Open Version in Temporary Directory"
    if ( [anActionString isEqualToString:@"openVersionInTemporaryDirectory:"] ) {
        if ( [table numberOfSelectedRows] == 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Replace WorkArea File with Version"
    if ( [anActionString isEqualToString:@"replaceWorkAreaFile:"] ) {
        if ( [table numberOfSelectedRows] == 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Restore WorkArea File with Version"
    if ( [anActionString isEqualToString:@"restoreWorkAreaFile:"] ) {
        if ( [table numberOfSelectedRows] == 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // For menu item "Save Version As..."
    if ( [anActionString isEqualToString:@"saveVersionAs:"] ) {
        if ( [table numberOfSelectedRows] == 1 ) {
            return YES;
        }
        return NO;        
    }
    
    // All others.
    return YES;
}

@end
