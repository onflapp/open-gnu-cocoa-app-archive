
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.


#import "VLStatusInspector.h"

#import <ResultsRepository.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "CVLFile.h"


//-------------------------------------------------------------------------------------

@implementation VLStatusInspector


- (void) setField:vField withObject:(id) anObject
{
  if ([[vField delegate] respondsToSelector: @selector(setTextColor:)])
  {
   if (anObject && [[anObject description] length])
    {
     [[vField delegate] setTextColor: [NSColor controlTextColor]];
      [vField setObjectValue: anObject];
    }
    else
    {
      [[vField delegate] setTextColor: [NSColor darkGrayColor]];
      [vField setStringValue: @""];
    }
  }
#ifdef DEBUG
  else
  {  // sometimes, the delegate is not actually an NSTextField uh -?
      NSString *aMsg = [NSString stringWithFormat:
          @"uh-- field %@ with string %@ has bad delegate", 
          vField, [anObject description]];
      SEN_LOG(aMsg);
  }
#endif
}


- (void) update
{
    // I assume the inspected array contains only one element
    CVLFile *aCVLFile;
    ResultsRepository* resultsRepository= [ResultsRepository sharedResultsRepository];
    NSString* element;

    [resultsRepository startUpdate];
    element=(NSString*) [inspected objectAtIndex: 0];
    aCVLFile=(CVLFile *)[CVLFile treeAtPath:element];

    [self setField: statusField withObject: [aCVLFile statusString]];
    [self setField: versionField withObject: [aCVLFile revisionInWorkArea]];
    [self setField: repVersionField withObject: [aCVLFile revisionInRepository]];
    [self setField: stickyTagField withObject: [aCVLFile stickyTag]];
    if ( [aCVLFile isABranch] == YES ) {
        [stickyTagField setTextColor:[NSColor blueColor]];
    } else {
        [stickyTagField setTextColor:[NSColor textColor]];
    }
    [self setField: stickyDateField withObject: [aCVLFile stickyDate]];
    [self setField: stickyOptionField withObject: [aCVLFile stickyOptions]];
    [self setField: lastCheckoutedClock withObject: [aCVLFile dateOfLastCheckout]];
    [self setField: lastModifiedClock withObject: [aCVLFile modificationDate]];
    [resultsRepository endUpdate];
}


@end
