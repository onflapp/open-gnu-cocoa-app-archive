/* CVLFileIconWell.h created by stephane on Tue 07-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

// Currently this class allows only dragging from the view, but does not accept files to be dropped onto.

@interface CVLFileIconWell : NSControl
{
    IBOutlet id	_delegate;
}

- (void) setDataSource:(id)aDataSource; // Forwarded to cell
- (id) dataSource; // Comes from cell

- (NSString *) filename; // Comes from cell; when there is more than one filename, the first one is returned
- (NSArray *) filenames; // Comes from cell

- (void) reloadData;

- (void) setDelegate:(id)delegate;
- (id) delegate;

- (id) target;
- (void) setTarget:(id)anObject;

- (SEL) doubleAction;
- (void) setDoubleAction:(SEL)aSelector;

@end

@interface NSObject(CVLFileIconWellDataSource)

- (NSArray *) filenamesForFileIconWell:(CVLFileIconWell *)aFileIconWell;

@end

@interface NSObject(CVLFileIconWellDelegate)

- (BOOL) iconWellShouldStartDragging:(CVLFileIconWell *)aFileIconWell;

@end
