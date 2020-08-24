/*
 * GSPropertyListSerialization.m
 *
 * Copyright (C) 2003,2004 Free Software Foundation, Inc.
 * Written by:       Richard Frith-Macdonald <rfm@gnu.org>
 *                   Fred Kiefer <FredKiefer@gmx.de>
 * Modifications by: Georg Fleischmann
 *
 * This class has been extracted from the GNUstep implementation of
 * NSPropertyList to achieve best compatibility of the Property List
 * formats between Mac OS X, GNUstep, OpenStep...
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * created:  2008-03-06 (extracted from NSPropertyList.m)
 * modified: 2008-03-08
 */

#ifndef GS_H_PLSERIALIZATION
#define GS_H_PLSERIALIZATION

#include <Foundation/Foundation.h>

#define NSPropertyListGNUstepFormat 1000

@interface GSPropertyListSerialization:NSObject
{
}

+ (NSData*)dataFromPropertyList:(id)plist
                         format:(NSPropertyListFormat)format
               errorDescription:(NSString**)errorString;

+ (NSString*)stringFromPropertyList:(id)plist;

@end

#endif // GS_H_PLSERIALIZATION
