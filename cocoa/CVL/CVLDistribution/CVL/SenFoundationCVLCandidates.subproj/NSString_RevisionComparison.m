/* NSString_RevisionComparison.m created by vincent on Fri 22-May-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSString_RevisionComparison.h"
#import <Foundation/Foundation.h>

@implementation NSString (RevisionComparison)

int keySort(id dict1, id dict2, void *context)
{
  NSString	*sortKey = ((struct CVLSortedRevisionArrayWithKeyContext *)context)->key;
  BOOL	ascendingOrder = ((struct CVLSortedRevisionArrayWithKeyContext *)context)->ascendingOrder;
  NSString* v1 = [dict1 objectForKey: sortKey];
  NSString* v2 = [dict2 objectForKey: sortKey];
  NSComparisonResult	result;

  if ([sortKey isEqualToString: @"revision"])
  {
    result = [v1 compareRevision: v2];
  }
  else if ([sortKey isEqualToString: @"modifs"])
      result = [v1 compareModifs: v2];
  else result = [v1 compare: v2];

  if(!ascendingOrder)
      result = -result;
  return result;
}


- (NSComparisonResult) compareRevision: (NSString*) aString
{
  NSEnumerator* myEnum= [[self componentsSeparatedByString: @"."] objectEnumerator];
  NSEnumerator* anEnum= [[aString componentsSeparatedByString: @"."] objectEnumerator];
  NSString* mySub= [myEnum nextObject];
  NSString* aSub= [anEnum nextObject];
  NSComparisonResult lastCompare= NSOrderedSame;

  while ((lastCompare == NSOrderedSame) && mySub && aSub)
  {
    int myValue= [mySub intValue];
    int aValue= [aSub intValue];

    lastCompare= (myValue == aValue ? NSOrderedSame : (myValue < aValue ? NSOrderedAscending : NSOrderedDescending));
    mySub= [myEnum nextObject];
    aSub= [anEnum nextObject];
  }
  if (lastCompare == NSOrderedSame)
  {
    if ((!mySub) && (!aSub))
    {
      return lastCompare;
    }
    else if (!mySub)
    {
      return NSOrderedAscending;
    }
    else return NSOrderedDescending;
  }
  return lastCompare;
}

- (NSComparisonResult) compareModifs: (NSString*) aString
{
    // Strings are in the format: "+XX - YY",
    // where XX and YY are numbers.
    // We compare the first numbers, then the seconds
    // if first are equal.
    if([self length] == 0)
        if([aString length] == 0)
            return NSOrderedSame;
        else
            return NSOrderedAscending;
    else{
        if([aString length] == 0)
            return NSOrderedDescending;
        else{
            NSArray	*myValues = [self componentsSeparatedByString:@" "];
            NSArray	*itsValues = [aString componentsSeparatedByString:@" "];
            int		anInt = [[myValues objectAtIndex:0] intValue];
            int		anotherInt = [[itsValues objectAtIndex:0] intValue];

            if(anInt < anotherInt)
                return NSOrderedAscending;
            else if(anInt > anotherInt)
                return NSOrderedDescending;
            else{
                anInt = [[myValues objectAtIndex:1] intValue];
                anotherInt = [[itsValues objectAtIndex:1] intValue];

                if(anInt < anotherInt)
                    return NSOrderedAscending;
                else if(anInt > anotherInt)
                    return NSOrderedDescending;
                else
                    return NSOrderedSame;
            }
        }
    }
}

@end
