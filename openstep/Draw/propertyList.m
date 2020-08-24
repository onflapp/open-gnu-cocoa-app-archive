#import "draw.h"

id propertyListFromArray(NSArray *array)
{
    id realObject;
    NSMutableArray *plistArray;
    NSEnumerator *enumerator;

    plistArray = [NSMutableArray arrayWithCapacity:[array count]];
    enumerator = [array objectEnumerator];
    while ((realObject = [enumerator nextObject])) {
        if ([realObject respondsToSelector:@selector(propertyList)]) {
            [plistArray addObject:[realObject propertyList]];
	} else {
	    /* Should probably raise here. */
	}
    }

    return plistArray;
}

id propertyListFromFloat(float f)
{
    return [NSString stringWithFormat:@"%g", f];
}

id propertyListFromInt(int i)
{
    return [NSString stringWithFormat:@"%d", i];
}

id propertyListFromNSColor(NSColor *color)
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:5];
    if ([[color colorSpaceName] isEqualToString:NSCalibratedWhiteColorSpace]) {
        [dictionary setObject:@"NSCalibratedWhiteColorSpace" forKey:@"ColorSpace"];
        [dictionary setObject:[NSNumber numberWithFloat:[color alphaComponent]] forKey:@"Alpha"];
        [dictionary setObject:[NSNumber numberWithFloat:[color whiteComponent]] forKey:@"White"];
    } else if ([[color colorSpaceName] isEqualToString:NSCalibratedRGBColorSpace]) {
        [dictionary setObject:@"NSCalibratedRGBColorSpace" forKey:@"ColorSpace"];
        [dictionary setObject:[NSNumber numberWithFloat:[color alphaComponent]] forKey:@"Alpha"];
        [dictionary setObject:[NSNumber numberWithFloat:[color blueComponent]] forKey:@"Blue"];
        [dictionary setObject:[NSNumber numberWithFloat:[color greenComponent]] forKey:@"Green"];
        [dictionary setObject:[NSNumber numberWithFloat:[color redComponent]] forKey:@"Red"];
    } else if ([[color colorSpaceName] isEqualToString:NSDeviceWhiteColorSpace]) {
        [dictionary setObject:@"NSDeviceWhiteColorSpace" forKey:@"ColorSpace"];
        [dictionary setObject:[NSNumber numberWithFloat:[color alphaComponent]] forKey:@"Alpha"];
        [dictionary setObject:[NSNumber numberWithFloat:[color whiteComponent]] forKey:@"White"];
    } else if ([[color colorSpaceName] isEqualToString:NSDeviceRGBColorSpace]) {
        [dictionary setObject:@"NSDeviceRGBColorSpace" forKey:@"ColorSpace"];
        [dictionary setObject:[NSNumber numberWithFloat:[color alphaComponent]] forKey:@"Alpha"];
        [dictionary setObject:[NSNumber numberWithFloat:[color blueComponent]] forKey:@"Blue"];
        [dictionary setObject:[NSNumber numberWithFloat:[color greenComponent]] forKey:@"Green"];
        [dictionary setObject:[NSNumber numberWithFloat:[color redComponent]] forKey:@"Red"];
    } else if ([[color colorSpaceName] isEqualToString:NSDeviceCMYKColorSpace]) {
        [dictionary setObject:@"NSDeviceCMYKColorSpace" forKey:@"ColorSpace"];
        [dictionary setObject:[NSNumber numberWithFloat:[color alphaComponent]] forKey:@"Alpha"];
        [dictionary setObject:[NSNumber numberWithFloat:[color cyanComponent]] forKey:@"Cyan"];
        [dictionary setObject:[NSNumber numberWithFloat:[color magentaComponent]] forKey:@"Magenta"];
        [dictionary setObject:[NSNumber numberWithFloat:[color yellowComponent]] forKey:@"Yellow"];
        [dictionary setObject:[NSNumber numberWithFloat:[color blackComponent]] forKey:@"Black"];
    } else if ([[color colorSpaceName] isEqualToString:NSNamedColorSpace]) {
        [dictionary setObject:@"NSNamedColorSpace" forKey:@"ColorSpace"];
        [dictionary setObject:[color catalogNameComponent] forKey:@"CId"];
        [dictionary setObject:[color colorNameComponent] forKey:@"NId"];
        [dictionary setObject:[color localizedCatalogNameComponent] forKey:@"Catalog"];
        [dictionary setObject:[color localizedColorNameComponent] forKey:@"Name"];
    } else {
        [dictionary setObject:@"Unknown" forKey:@"ColorSpace"];
        [dictionary setObject:[NSArchiver archivedDataWithRootObject:color] forKey:@"Data"];
    }
    return dictionary;
}

id propertyListFromNSRect(NSRect rect)
{
    return [NSString stringWithFormat:@"%g %g %g %g", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

id propertyListFromNSSize(NSSize size)
{
    return [NSString stringWithFormat:@"%g %g", size.width, size.height];
}

id propertyListFromNSPoint(NSPoint point)
{
    return [NSString stringWithFormat:@"%g %g", point.x, point.y];
}

NSMutableArray *arrayFromPropertyList(id plist, NSString *directory, NSZone *zone)
{
    id realObject;
    NSMutableArray *realArray;
    NSDictionary *plistObject;
    NSEnumerator *enumerator;
    NSString *className;

    realArray = [[NSMutableArray allocWithZone:zone] initWithCapacity:[plist count]];
    enumerator = [plist objectEnumerator];
    while ((plistObject = [enumerator nextObject])) {
        className = [plistObject objectForKey:@"Class"];
        if (className) {
            realObject = [[NSClassFromString(className) allocWithZone:zone] initFromPropertyList:plistObject inDirectory:directory];
            [realArray addObject:realObject];
        } else {
            /* Should probably raise in this case. */
        }
    }

    return realArray;
}

NSColor *colorFromPropertyList(id plist, NSZone *zone)
{
    if ([plist isKindOfClass:[NSDictionary class]]) {
        NSString *colorSpaceName = [plist objectForKey:@"ColorSpace"];
        if ([colorSpaceName isEqualToString:@"NSCalibratedWhiteColorSpace"]) {
            return [[NSColor colorWithCalibratedWhite:[[plist objectForKey:@"White"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        } else if ([colorSpaceName isEqualToString:@"NSCalibratedRGBColorSpace"]) {
            return [[NSColor colorWithCalibratedRed:[[plist objectForKey:@"Red"] floatValue] green:[[plist objectForKey:@"Green"] floatValue] blue:[[plist objectForKey:@"Blue"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        } else if ([colorSpaceName isEqualToString:@"NSDeviceWhiteColorSpace"]) {
            return [[NSColor colorWithDeviceWhite:[[plist objectForKey:@"White"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        } else if ([colorSpaceName isEqualToString:@"NSDeviceRGBColorSpace"]) {
            return [[NSColor colorWithDeviceRed:[[plist objectForKey:@"Red"] floatValue] green:[[plist objectForKey:@"Green"] floatValue] blue:[[plist objectForKey:@"Blue"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        } else if ([colorSpaceName isEqualToString:@"NSDeviceCMYKColorSpace"]) {
            return [[NSColor colorWithDeviceCyan:[[plist objectForKey:@"Cyan"] floatValue] magenta:[[plist objectForKey:@"Magenta"] floatValue] yellow:[[plist objectForKey:@"Yellow"] floatValue] black:[[plist objectForKey:@"Black"] floatValue] alpha:[[plist objectForKey:@"Alpha"] floatValue]] retain];
        } else if ([colorSpaceName isEqualToString:@"NSNamedColorSpace"]) {
            return [[NSColor colorWithCatalogName:[plist objectForKey:@"CId"] colorName:[plist objectForKey:@"NId"]] retain];
        } else if ([colorSpaceName isEqualToString:@"Unknown"]) {
            return [[NSUnarchiver unarchiveObjectWithData:[plist objectForKey:@"Data"]] retain];
        } else { // should never happen, maybe raise?
            return nil;
        }
    } else if ([plist isKindOfClass:[NSData class]]) {
        return plist ? [[NSUnarchiver unarchiveObjectWithData:plist] retain] : nil;
    } else { // should never happen, maybe raise?
        return nil;
    }
}

NSRect rectFromPropertyList(id plist)
{
    NSRect retval;
    NSArray *components = [plist componentsSeparatedByString:@" "];
    retval.origin.x = [[components objectAtIndex:0] floatValue];
    retval.origin.y = [[components objectAtIndex:1] floatValue];
    retval.size.width = [[components objectAtIndex:2] floatValue];
    retval.size.height = [[components objectAtIndex:3] floatValue];
    return retval;
}

NSSize sizeFromPropertyList(id plist)
{
    NSSize retval;
    NSArray *components = [plist componentsSeparatedByString:@" "];
    retval.width = [[components objectAtIndex:0] floatValue];
    retval.height = [[components objectAtIndex:1] floatValue];
    return retval;
}

NSPoint pointFromPropertyList(id plist)
{
    NSPoint retval;
    NSArray *components = [plist componentsSeparatedByString:@" "];
    retval.x = [[components objectAtIndex:0] floatValue];
    retval.y = [[components objectAtIndex:1] floatValue];
    return retval;
}

