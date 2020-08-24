//
//  CVLWatchInspector.h
//  CVL
//
//  Created by Isa Kindov on Tue Jul 09 2002.
//  Copyright (c) 2002 Sen:te. All rights reserved.
//

#import <CVLInspector.h>


@interface CVLWatchInspector : CVLInspector
{
    IBOutlet NSTableView	*watcherTableView;
    IBOutlet NSTableView	*editorTableView;
    IBOutlet NSTableColumn	*editTableColumn;
    IBOutlet NSTableColumn	*uneditTableColumn;
    IBOutlet NSTableColumn	*commitTableColumn;
    NSImage                 *aCheckMark;
    NSArray					*cachedEditors;

    NSArray					*cachedWatchers;
}

@end
