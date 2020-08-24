/* NSArray+CVLUtilities.h created by stephane on Tue 30-Nov-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>

@interface NSArray(CVLUtilities)

- (NSArray *) cvlRevisionTree;
// self must contain revision strings that will be ordered in arrays to show the branches and leaves
// ready for an outlineView

@end
