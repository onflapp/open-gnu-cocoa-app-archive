/* propertyList.h
 * Functions helping to read and write property lists
 *
 * Copyright 2002 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  ?
 * modified: 2003-08-10
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_PROPERTYLIST
#define VHF_H_PROPERTYLIST

#include <AppKit/AppKit.h>      // NSColor, NSPrintInfo
#include <VHFShared/types.h>	// V3Point

/* Convenience methods for Property List-izing */

typedef enum { FromPropertyList = 0, ToPropertyList = 1 } ConversionDirection;

/* return new class name, if name has changed from one version to another */
extern NSString *newClassName(NSString *className);

/* The following functions return autoreleased objects. */

extern id propertyListFromArray(NSArray *array);
extern id propertyListFromFloat(float f);
extern id propertyListFromInt(int i);
extern id propertyListFromNSPrintInfo(NSPrintInfo *printInfo);
extern id propertyListFromNSColor(NSColor *color);
extern id propertyListFromNSRect(NSRect rect);
extern id propertyListFromNSSize(NSSize size);
extern id propertyListFromNSPoint(NSPoint point);
extern id propertyListFromV3Point(V3Point point);

/* The following functions return retained objects. */

extern NSMutableArray   *arrayFromPropertyList(id plist, NSString *directory, NSZone *zone);
extern NSColor          *colorFromPropertyList(id plist, NSZone *zone);
extern NSPrintInfo      *printInfoFromPropertyList(id plist, NSZone *zone);
extern NSRect           rectFromPropertyList(NSString *plist);
extern NSSize           sizeFromPropertyList(id plist);
extern NSPoint          pointFromPropertyList(id plist);
extern V3Point          v3pointFromPropertyList(id plist);

#define PL_FLAG(plist, flag, key, direction) \
    if (direction == ToPropertyList) { \
        if (flag) [plist setObject:@"YES" forKey:key]; \
    } else { \
        flag = ([plist objectForKey:key] ? YES : NO); \
    }

#define PL_INT(plist, value, key, direction) \
   if (direction == ToPropertyList) { \
       if (value) [plist setObject:propertyListFromInt(value) forKey:key]; \
   } else { \
       value = [[plist objectForKey:key] intValue]; \
       if (![plist objectForKey:key]) value = 0; \
   }

#define PL_FLOAT(plist, value, key, direction) \
   if (direction == ToPropertyList) { \
       if (value) [plist setObject:propertyListFromFloat(value) forKey:key]; \
   } else { \
       value = [[plist objectForKey:key] floatValue]; \
       if (![plist objectForKey:key]) value = 0.0; \
   }

#define PL_COLOR(plist, value, key, direction, zone) \
   if (direction == ToPropertyList) { \
       if (value) [plist setObject:propertyListFromNSColor(value) forKey:key]; \
   } else { \
       value = colorFromPropertyList([plist objectForKey:key], zone); \
   }

#define PL_RECT(plist, value, key, direction) \
   if (direction == ToPropertyList) { \
       [plist setObject:propertyListFromNSRect(value) forKey:key]; \
   } else { \
       value = rectFromPropertyList([plist objectForKey:key]); \
   }

#endif // VHF_H_PROPERTYLIST
