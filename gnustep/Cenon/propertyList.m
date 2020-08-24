/* propertyList.m
 * Functions helping to read and write property lists
 *
 * Copyright (C) 2002-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  ?
 * modified: 2009-12-12 (save coordinated with 9 digits precision instead of 6 before)
 *           2008-01-12 (propertyListFromNSColor() Apple >= 10.4 workaround)
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

#include <AppKit/AppKit.h>
#include <VHFShared/VHFDictionaryAdditions.h>
#include <VHFShared/vhfCommonFunctions.h>	// vhfStringWithFloat()
#include <VHFShared/vhfCompatibility.h>     // CGFloat for OS X 10.4
#include "propertyList.h"

#ifndef NSAppKitVersionNumber10_4
#  define NSAppKitVersionNumber10_4 824
#endif

/* we don't always have VGraphic objects, so we declare the used method here */
@interface PropertyList
- (id)initFromPropertyList:(id)plist inDirectory:(NSString*)directory;
@end
@implementation PropertyList
- (id)initFromPropertyList:(id)plist inDirectory:(NSString*)directory	{ return nil; }
@end

/* backward compatibility before moving to new classnames
 */
NSString *newClassName(NSString *className)
{
    if ([className isEqual:@"TextGraphic"])
        return @"VText";
    return [@"V" stringByAppendingString:className];
}

id propertyListFromArray(NSArray *array)
{   id              realObject;
    NSMutableArray  *plistArray;
    NSEnumerator    *enumerator;

    plistArray = [NSMutableArray arrayWithCapacity:[array count]];
    enumerator = [array objectEnumerator];
    while ((realObject = [enumerator nextObject]))
    {
        if ([realObject respondsToSelector:@selector(propertyList)])
            [plistArray addObject:[realObject propertyList]];
        else
        {
            /* Should probably raise here. */
        }
    }
    return plistArray;
}

id propertyListFromFloat(float f)
{
    return [NSString stringWithFormat:@"%.12g", f];
}

id propertyListFromInt(int i)
{
    return [NSString stringWithFormat:@"%d", i];
}

/* modified: 2008-01-11 (Apple workaround)
 */
id propertyListFromNSColor(NSColor *color)
{   NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:5];

    if ([[color colorSpaceName] isEqualToString:NSCalibratedWhiteColorSpace])
    {
        [dictionary setObject:@"CalWhite" forKey:@"s"];
        [dictionary setObject:vhfStringWithFloat([color alphaComponent]) forKey:@"A"];
        [dictionary setObject:vhfStringWithFloat([color whiteComponent]) forKey:@"W"];
    }
    else if ( [[color colorSpaceName] isEqualToString:NSCalibratedRGBColorSpace] )
    {
        [dictionary setObject:@"CalRGB" forKey:@"s"];
        [dictionary setObject:vhfStringWithFloat([color alphaComponent]) forKey:@"A"];
        [dictionary setObject:vhfStringWithFloat([color blueComponent])  forKey:@"B"];
        [dictionary setObject:vhfStringWithFloat([color greenComponent]) forKey:@"G"];
        [dictionary setObject:vhfStringWithFloat([color redComponent])   forKey:@"R"];
    }
    else if ([[color colorSpaceName] isEqualToString:NSDeviceWhiteColorSpace])
    {
        [dictionary setObject:@"DevWhite" forKey:@"s"];
        [dictionary setObject:vhfStringWithFloat([color alphaComponent]) forKey:@"A"];
        [dictionary setObject:vhfStringWithFloat([color whiteComponent]) forKey:@"W"];
    }
    else if ([[color colorSpaceName] isEqualToString:NSDeviceRGBColorSpace])
    {
        [dictionary setObject:@"DevRGB" forKey:@"s"];
        [dictionary setObject:vhfStringWithFloat([color alphaComponent]) forKey:@"A"];
        [dictionary setObject:vhfStringWithFloat([color blueComponent])  forKey:@"B"];
        [dictionary setObject:vhfStringWithFloat([color greenComponent]) forKey:@"G"];
        [dictionary setObject:vhfStringWithFloat([color redComponent])   forKey:@"R"];
    }
    else if ([[color colorSpaceName] isEqualToString:NSDeviceCMYKColorSpace])
    {
        [dictionary setObject:@"DevCMYK" forKey:@"s"];
        [dictionary setObject:vhfStringWithFloat([color alphaComponent])   forKey:@"A"];
        [dictionary setObject:vhfStringWithFloat([color cyanComponent])    forKey:@"C"];
        [dictionary setObject:vhfStringWithFloat([color magentaComponent]) forKey:@"M"];
        [dictionary setObject:vhfStringWithFloat([color yellowComponent])  forKey:@"Y"];
        [dictionary setObject:vhfStringWithFloat([color blackComponent])   forKey:@"B"];
    }
    else if ([[color colorSpaceName] isEqualToString:NSNamedColorSpace])
    {
        [dictionary setObject:@"Named" forKey:@"s"];
        [dictionary setObject:[color catalogNameComponent]          forKey:@"CId"];
        [dictionary setObject:[color colorNameComponent]            forKey:@"NId"];
        [dictionary setObject:[color localizedCatalogNameComponent] forKey:@"Catalog"];
        [dictionary setObject:[color localizedColorNameComponent]   forKey:@"Name"];
    }
#ifdef __APPLE__   // Fat: a 2nd layer of same functionality added in Mac OS 10.4
    else if ( NSAppKitVersionNumber >= NSAppKitVersionNumber10_4 &&   // >= 10.4
              [[color colorSpaceName] isEqualToString:NSCustomColorSpace] )
    {   int     cnt = [color numberOfComponents];
        CGFloat compo[cnt];

        [color getComponents:compo];
        switch ([[color colorSpace] colorSpaceModel])
        {
            case NSGrayColorSpaceModel: // NSCustomColorSpace Generic Gray colorspace 0.5 1
                [dictionary setObject:@"CalWhite" forKey:@"s"];
                [dictionary setObject:vhfStringWithFloat(compo[0]) forKey:@"W"];
                [dictionary setObject:vhfStringWithFloat(compo[1]) forKey:@"A"];
                break;
                //return propertyListFromNSColor([color colorUsingColorSpace:[NSColorSpace deviceGrayColorSpace]]);
            case NSRGBColorSpaceModel:
                [dictionary setObject:@"DevRGB" forKey:@"s"];
                [dictionary setObject:vhfStringWithFloat(compo[0]) forKey:@"R"];
                [dictionary setObject:vhfStringWithFloat(compo[1]) forKey:@"G"];
                [dictionary setObject:vhfStringWithFloat(compo[2]) forKey:@"B"];
                [dictionary setObject:vhfStringWithFloat(compo[3]) forKey:@"A"];
                break;
            case NSCMYKColorSpaceModel:
                [dictionary setObject:@"DevCMYK" forKey:@"s"];
                [dictionary setObject:vhfStringWithFloat(compo[0]) forKey:@"C"];
                [dictionary setObject:vhfStringWithFloat(compo[1]) forKey:@"M"];
                [dictionary setObject:vhfStringWithFloat(compo[2]) forKey:@"Y"];
                [dictionary setObject:vhfStringWithFloat(compo[3]) forKey:@"B"];
                [dictionary setObject:vhfStringWithFloat(compo[4]) forKey:@"A"];
                break;
            //case NSLABColorSpaceModel:
            //case NSDeviceNColorSpaceModel:
            default:
                break;
        }
    }
#endif
    /*else
    {
        [dictionary setObject:@"Unknown" forKey:@"s"];
        [dictionary setObject:[NSArchiver archivedDataWithRootObject:color] forKey:@"Data"];
    }*/
    return dictionary;
}

id propertyListFromNSPrintInfo(NSPrintInfo *printInfo)
{   NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:5];

    if (!printInfo)
        return dictionary;
    [dictionary setFloat:[printInfo leftMargin] forKey:@"leftMargin"];
    [dictionary setFloat:[printInfo rightMargin] forKey:@"rightMargin"];
    [dictionary setFloat:[printInfo topMargin] forKey:@"topMargin"];
    [dictionary setFloat:[printInfo bottomMargin] forKey:@"bottomMargin"];
    [dictionary setObject:propertyListFromNSSize([printInfo paperSize]) forKey:@"paperSize"];
    [dictionary setObject:[printInfo paperName] forKey:@"paperName"];
    [dictionary setInt:[printInfo orientation] forKey:@"orientation"];

    return dictionary;
}

id propertyListFromNSRect(NSRect rect)
{
    return [NSString stringWithFormat:@"%.12g %.12g %.12g %.12g", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

id propertyListFromNSSize(NSSize size)
{
    return [NSString stringWithFormat:@"%.12g %.12g", size.width, size.height];
}

id propertyListFromNSPoint(NSPoint point)
{   //int digX = 9;

    //if ( floor(point.x*1000.0)/1000.0 == point.x )
    //    digX = 6;
    return [NSString stringWithFormat:@"%.12g %.12g", point.x, point.y];
}

id propertyListFromV3Point(V3Point point)
{
    return [NSString stringWithFormat:@"%.12g %.12g %.12g", point.x, point.y, point.z];
}

NSMutableArray *arrayFromPropertyList(id plist, NSString *directory, NSZone *zone)
{   id              realObject;
    NSMutableArray  *realArray;
    NSDictionary    *plistObject;
    NSEnumerator    *enumerator;
    NSString        *className;

    realArray = [[NSMutableArray allocWithZone:zone] initWithCapacity:[plist count]];
    enumerator = [plist objectEnumerator];
    while ((plistObject = [enumerator nextObject]))
    {
        className = [plistObject objectForKey:@"Class"];
        if (className)
        {   id	obj = [NSClassFromString(className) allocWithZone:zone];

            if (!obj)	// load old projects
                obj = [NSClassFromString(newClassName(className)) allocWithZone:zone];
            realObject = [obj initFromPropertyList:plistObject inDirectory:directory];
            [realArray addObject:realObject];
            [realObject release];
        }
        else
            NSLog(@"arrayFromPropertyList(): Class expected !");
    }

    return realArray;
}

NSColor *colorFromPropertyList(id plist, NSZone *zone)
{
    if ([plist isKindOfClass:[NSDictionary class]])
    {   NSString *colorSpaceName = [plist objectForKey:@"s"];

        if (!colorSpaceName)
            colorSpaceName = [plist objectForKey:@"ColorSpace"];

        if ([colorSpaceName isEqualToString:@"CalWhite"] || [colorSpaceName isEqualToString:@"NSCalibratedWhiteColorSpace"])
        {
            if ([plist objectForKey:@"W"])
                return [[NSColor colorWithCalibratedWhite:[[plist objectForKey:@"W"] floatValue] alpha:[[plist objectForKey:@"A"] floatValue]] retain];
            else
                return [[NSColor colorWithCalibratedWhite:[[plist objectForKey:@"White"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        }
        else if ([colorSpaceName isEqualToString:@"CalRGB"] || [colorSpaceName isEqualToString:@"NSCalibratedRGBColorSpace"])
        {
            if ([plist objectForKey:@"R"])
            return [[NSColor colorWithCalibratedRed:[[plist objectForKey:@"R"] floatValue] green:[[plist objectForKey:@"G"] floatValue] blue:[[plist objectForKey:@"B"] floatValue] alpha:[[plist objectForKey:@"A"] floatValue]] retain];
            else
                return [[NSColor colorWithCalibratedRed:[[plist objectForKey:@"Red"] floatValue] green:[[plist objectForKey:@"Green"] floatValue] blue:[[plist objectForKey:@"Blue"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        }
        else if ([colorSpaceName isEqualToString:@"DevWhite"] || [colorSpaceName isEqualToString:@"NSDeviceWhiteColorSpace"])
        {
            if ([plist objectForKey:@"W"])
                return [[NSColor colorWithDeviceWhite:[[plist objectForKey:@"W"] floatValue] alpha:[[plist objectForKey:@"A"] floatValue]] retain];
            else
                return [[NSColor colorWithDeviceWhite:[[plist objectForKey:@"White"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        }
        else if ([colorSpaceName isEqualToString:@"DevRGB"] || [colorSpaceName isEqualToString:@"NSDeviceRGBColorSpace"])
        {
            if ([plist objectForKey:@"R"])
                return [[NSColor colorWithDeviceRed:[[plist objectForKey:@"R"] floatValue] green:[[plist objectForKey:@"G"] floatValue] blue:[[plist objectForKey:@"B"] floatValue] alpha:[[plist objectForKey:@"A"] floatValue]] retain];
            else
                return [[NSColor colorWithDeviceRed:[[plist objectForKey:@"Red"] floatValue] green:[[plist objectForKey:@"Green"] floatValue] blue:[[plist objectForKey:@"Blue"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        }
        else if ([colorSpaceName isEqualToString:@"DevCMYK"] || [colorSpaceName isEqualToString:@"NSDeviceCMYKColorSpace"])
        {
            if ([plist objectForKey:@"C"])
                return [[NSColor colorWithDeviceCyan:[[plist objectForKey:@"C"] floatValue] magenta:[[plist objectForKey:@"M"] floatValue] yellow:[[plist objectForKey:@"Y"] floatValue] black:[[plist objectForKey:@"B"] floatValue] alpha:[[plist objectForKey:@"A"] floatValue]] retain];
            else
                return [[NSColor colorWithDeviceCyan:[[plist objectForKey:@"Cyan"] floatValue] magenta:[[plist objectForKey:@"Magenta"] floatValue] yellow:[[plist objectForKey:@"Yellow"] floatValue] black:[[plist objectForKey:@"Black"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        }
        else if ([colorSpaceName isEqualToString:@"Named"] || [colorSpaceName isEqualToString:@"NSNamedColorSpace"])
        {
            return [[NSColor colorWithCatalogName:[plist objectForKey:@"CId"] colorName:[plist objectForKey:@"NId"]] retain];
        }
        else if ([colorSpaceName isEqualToString:@"Unknown"])
            return [[NSUnarchiver unarchiveObjectWithData:[plist objectForKey:@"Data"]] retain];
        else
            return nil;
    }
    else if ([plist isKindOfClass:[NSData class]])
        return plist ? [[NSUnarchiver unarchiveObjectWithData:plist] retain] : nil;
    else	// should never happen
        return nil;
}

NSPrintInfo *printInfoFromPropertyList(id plist, NSZone *zone)
{   NSPrintInfo	*printInfo = [[NSPrintInfo sharedPrintInfo] copy];

    //[printInfo setVerticallyCentered:NO];
    //[printInfo setHorizontallyCentered:NO];
    //[printInfo setHorizontalPagination:NSFitPagination];

    [printInfo setLeftMargin:[plist floatForKey:@"leftMargin"]];
    [printInfo setRightMargin:[plist floatForKey:@"rightMargin"]];
    [printInfo setTopMargin:[plist floatForKey:@"topMargin"]];
    [printInfo setBottomMargin:[plist floatForKey:@"bottomMargin"]];

    [printInfo setPaperSize:sizeFromPropertyList([plist objectForKey:@"paperSize"])];
    [printInfo setPaperName:[plist objectForKey:@"paperName"]];
    [printInfo setOrientation:[plist intForKey:@"orientation"]];
    return printInfo;
}

NSRect rectFromPropertyList(NSString *plist)
{   NSRect	retval;
    NSArray	*components = [plist componentsSeparatedByString:@" "];

    retval.origin.x = [[components objectAtIndex:0] floatValue];
    retval.origin.y = [[components objectAtIndex:1] floatValue];
    retval.size.width  = [[components objectAtIndex:2] floatValue];
    retval.size.height = [[components objectAtIndex:3] floatValue];
    return retval;
}

NSSize sizeFromPropertyList(id plist)
{   NSSize	retval;
    NSArray	*components = [plist componentsSeparatedByString:@" "];

    retval.width = [[components objectAtIndex:0] floatValue];
    retval.height = [[components objectAtIndex:1] floatValue];
    return retval;
}

NSPoint pointFromPropertyList(id plist)
{   NSPoint	retval;
    NSArray	*components = [plist componentsSeparatedByString:@" "];

    if ([components count] < 2)
        return NSMakePoint(0.0, 0.0);
    retval.x = [[components objectAtIndex:0] floatValue];
    retval.y = [[components objectAtIndex:1] floatValue];
    return retval;
}

V3Point v3pointFromPropertyList(id plist)
{   V3Point retval;
    NSArray *components = [plist componentsSeparatedByString:@" "];

    if ([components count] < 3)
        return V3MakePoint(0.0, 0.0, 0.0);
    retval.x = [[components objectAtIndex:0] floatValue];
    retval.y = [[components objectAtIndex:1] floatValue];
    retval.z = [[components objectAtIndex:2] floatValue];
    return retval;
}
