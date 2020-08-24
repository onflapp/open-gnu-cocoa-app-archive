/*
	$id$
*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>

@class NSString;
@class NSArray;

@interface WorkAreaListViewer:NSObject
{
  id window;
  id browser;

  NSString* rootPath;
  int updateCount;
}

+ (WorkAreaListViewer*) listViewerForPath: (NSString*) aPath;

- initForPath: (NSString*) aPath;

- view;

- (NSString*) rootPath;
- (NSArray *) selectedPaths;

@end
//-------------------------------------------------------------------------------------
