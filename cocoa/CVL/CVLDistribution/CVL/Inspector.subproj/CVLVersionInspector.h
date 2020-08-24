//
//  CVLVersionInspector.h
//  CVL
//
//  Created by William Swats on Mon May 17 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import <CVLInspector.h>
#import <AppKit/AppKit.h>


@interface CVLVersionInspector:CVLInspector
{
    IBOutlet NSTableView *table;
    NSMutableArray *versionArray;
    NSMutableArray	*lastSelectedObjects;
    BOOL	ascendingOrder;
}

- (IBAction ) select:sender;
- (IBAction) showDifference:(id)sender;
- (IBAction) replaceWorkAreaFile:(id)sender;
- (IBAction) restoreWorkAreaFile:(id)sender;
- (void)retrieveWorkAreaFileForAction:(int)anActionType;
- (IBAction) openVersionInTemporaryDirectory:(id)sender;
- (IBAction) saveVersionAs:(id)sender;

- (void) compareLeftKey:(NSString *)lkey value:(NSString *)lvalue withRightKey:(NSString *)rkey value:(NSString *)rvalue;
- (NSString *) selectedVersionString;
- (NSMutableArray *)versionArray;
- (void)setVersionArray:(NSArray *)newVersionArray;
- (void) selectVersionOfInspectedCVLFile;
- (id) versionInArrayMatchingInspectedCVLFile;
- (NSString *) versionStringOfInspectedCVLFile;
- (NSString *) versionStringIn:(id)aVersion;

/*" NSTableDataSource methods "*/
- (int)numberOfRowsInTableView:(NSTableView *)tableView;
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors;

    /*" NSTableViewDelegate methods "*/
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (void) tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn;


@end

@interface CVLVersionInspector (MenuValidation)

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem;

@end
