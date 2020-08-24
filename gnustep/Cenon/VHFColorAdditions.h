/*
 * VHFColorAdditions.h
 *
 * Copyright 1997-2003 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2003-03-28
 * modified: 2003-03-28
 */

#ifndef VHF_H_COLORADDITIONS
#define VHF_H_COLORADDITIONS

#include <AppKit/AppKit.h>

@interface NSColor(VHFColorAdditions)
//- (void) set;
- (NSColor*)colorUsingColorSpaceName:(NSString*)colorSpace;
- (NSColor*)colorUsingColorSpaceName:(NSString*)colorSpace device:(NSDictionary*)deviceDescription;
@end

#endif // VHF_H_COLORADDITIONS
