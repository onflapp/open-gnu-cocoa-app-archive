/* CVLFileIconWellCell.h created by stephane on Tue 07-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@class NSControl;

@interface CVLFileIconWellCell : NSImageCell
{
    id			dataSource;
    NSControl	*_iconWellControlView;
    id			_target;
    SEL			_doubleAction;
}

- (void) setDataSource:(id)aDataSource; // DataSource must respond to CVLFileIconWellCellDataSource informal protocol
- (id) dataSource;

- (NSString *) filename; // When there is more than one filename, the first one is returned
- (NSArray *) filenames;

- (NSImage *) image;
    // Overridden to get it dynamically from dataSource

- (void) reloadData;

- (unsigned int) draggingSourceOperationMaskForLocal:(BOOL)flag;
- (NSControl *) controlView;

- (id) target;
- (void) setTarget:(id)anObject;

- (SEL) doubleAction;
- (void) setDoubleAction:(SEL)aSelector;

@end

@interface NSView(CVLFileIconWellCellControlView)

// ControlView MUST implement this method!
- (NSArray *) filenamesForFileIconWellCell:(CVLFileIconWellCell *)aFileIconWellCell;

@end
