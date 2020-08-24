//
//  PXPalette.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Wed Jun 09 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//
#import <AppKit/AppKit.h>

@interface PXPalette : NSObject <NSCoding, NSCopying>
{
	id name;
	id usedColors;
	id delegate;
}
- initWithName:aName;
- initWithName:aName colors:someColors;
- (void)setDelegate:anObject;
- (int)addColor:color;
- colorAtIndex:(unsigned)index;
- (void)setColor:color atIndex:(unsigned)index;
- (void)removeDuplicatesOfColorAtIndex:(unsigned)index;
- colors;
- (void)setColors:newColors;
- name;
- (void)setName:newName;
@end
