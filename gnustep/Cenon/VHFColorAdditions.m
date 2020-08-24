/* VHFColorAdditions.m
 * some workarounds for OpenStep CMYK-bug
 *
 * Copyright (C) 2003 by vhf interservice GmbH
 * Author:   Ilonka Fleischmann
 *
 * created:  2003-03-28
 * modified: 2003-03-28
 *
 * This file is part of the vhf Export Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include "VHFColorAdditions.h"

@implementation NSColor(VHFColorAdditions)

/*- (void) set
{   NSString	*selfColorSpace = [self colorSpaceName];

    if ([selfColorSpace isEqualToString:NSNamedColorSpace])
    {   PSsetgray(0.0);
        return;
    }
    else if ([selfColorSpace isEqualToString:NSDeviceWhiteColorSpace] ||
             [selfColorSpace isEqualToString:NSCalibratedWhiteColorSpace])
        PSsetgray([self whiteComponent]);
    else if ([selfColorSpace isEqualToString:NSDeviceRGBColorSpace] ||
             [selfColorSpace isEqualToString:NSCalibratedRGBColorSpace])
        PSsetrgbcolor([self redComponent], [self greenComponent], [self blueComponent]);
    else if ([selfColorSpace isEqualToString:NSDeviceCMYKColorSpace])
    {   NSColor	*col = [self colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

        PSsetrgbcolor([col redComponent], [col greenComponent], [col blueComponent]);

        //PSsetcmykcolor([self cyanComponent], [self magentaComponent],
        //               [self yellowComponent], [self blackComponent]);
    }
    // Should we check the ignore flag here?
    PSsetalpha([self alphaComponent]);
}*/

- (NSColor*)colorUsingColorSpaceName:(NSString *)colorSpace
/*{
  return [self colorUsingColorSpaceName:colorSpace device:nil];
}*/
{   NSString		*selfColorSpace = [self colorSpaceName];
    NSDictionary	* deviceDescription = nil;

    if (colorSpace == nil)
    {
        if (deviceDescription != nil)
            colorSpace = [deviceDescription objectForKey: NSDeviceColorSpaceName];
        if (colorSpace == nil)
            colorSpace = NSDeviceRGBColorSpace;
    }
    if ([colorSpace isEqualToString: [self colorSpaceName]])
    {
        return self;
    }

    if ([colorSpace isEqualToString: NSNamedColorSpace] ||
        [selfColorSpace isEqualToString:NSNamedColorSpace])
        /*[colorSpace isEqualToString: NSDynamicSystemColorSpace] ||
        [selfColorSpace isEqualToString: NSDynamicSystemColorSpace]*/
    {
      // FIXME: We cannot convert to named color space.
        return nil;
    }
    /* wanted is calibrated||device rgb color */
    if ([colorSpace isEqualToString:NSCalibratedRGBColorSpace] ||
        [colorSpace isEqualToString:NSDeviceRGBColorSpace])
    {   double	r = 0.0, g = 0.0, b = 0.0;

        /* we are cmyk color */
        if ([selfColorSpace isEqualToString:NSDeviceCMYKColorSpace]) // bw rgb cmy hsb
        {   double c = [self cyanComponent];
            double m = [self magentaComponent];
            double y = [self yellowComponent];
            double white = 1.0 - [self blackComponent];

            r = (c > white) ? 0 : (white - c);
            g = (m > white) ? 0 : (white - m);
            b = (y > white) ? 0 : (white - y);
        }
        /* we are white color */
        else if ([selfColorSpace isEqualToString:NSDeviceWhiteColorSpace] ||
                 [selfColorSpace isEqualToString:NSCalibratedWhiteColorSpace])
        {
            r = g = b = [self whiteComponent];
        }
        /* we are device rgb color */
        else if ([selfColorSpace isEqualToString:NSDeviceRGBColorSpace])
        {
            r = [self redComponent];
            g = [self greenComponent];
            b = [self blueComponent];
        }
        else if ([selfColorSpace isEqualToString:NSCalibratedRGBColorSpace])
            return self;
        else
            NSLog(@"VHFColorAdditions undefinded colorSpace to rgb colorSpace");

        if ([colorSpace isEqualToString:NSCalibratedRGBColorSpace])
            return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:[self alphaComponent]];
        if ([colorSpace isEqualToString:NSDeviceRGBColorSpace])
            return [NSColor colorWithDeviceRed:r green:g blue:b alpha:[self alphaComponent]];
    }
    /* wanted is device cmyk color */
    if ([colorSpace isEqualToString: NSDeviceCMYKColorSpace])
    {   double	c = 0.0, m = 0.0, y = 0.0, k = 0.0;

        /* we are rgb color */
        if ([selfColorSpace isEqualToString:NSDeviceRGBColorSpace] ||
            [selfColorSpace isEqualToString:NSCalibratedRGBColorSpace])
        {
            c = 1.0 - [self redComponent];
            m = 1.0 - [self greenComponent];
            y = 1.0 - [self blueComponent];
        }
        /* we are white color */
        else if ([selfColorSpace isEqualToString:NSDeviceWhiteColorSpace] ||
                 [selfColorSpace isEqualToString:NSCalibratedWhiteColorSpace])
        {
            c = m = y = 0.0;
            k = 1.0 - [self whiteComponent];
        }
        else if ([selfColorSpace isEqualToString:NSDeviceCMYKColorSpace])
            return self;
        else
            NSLog(@"VHFColorAdditions undefinded colorSpace to cmyk device colorSpace");

      return [NSColor colorWithDeviceCyan:c magenta:m yellow:y black:k alpha:[self alphaComponent]];
    }
    /* wanted is device white color */
    if ([colorSpace isEqualToString: NSDeviceWhiteColorSpace] ||
        [colorSpace isEqualToString: NSCalibratedWhiteColorSpace])
    {   double	w = 0.0;

        /* we are cmyk color */
        if ([selfColorSpace isEqualToString:NSDeviceCMYKColorSpace]) // bw rgb cmy hsb
        {
            w =  1.0 - [self blackComponent] -
            ([self cyanComponent] + [self magentaComponent] + [self yellowComponent]) / 3.0;
        }
        /* we are white color */
        else if ([selfColorSpace isEqualToString:NSCalibratedWhiteColorSpace])
        {
            w = [self whiteComponent];
        }
        /* we are device rgb color */
        else if ([selfColorSpace isEqualToString:NSCalibratedRGBColorSpace] ||
                 [selfColorSpace isEqualToString:NSDeviceRGBColorSpace])
        {
            w = ([self redComponent] + [self greenComponent] + [self blueComponent]) / 3.0;
        }
        else if ([selfColorSpace isEqualToString:NSDeviceWhiteColorSpace])
            return self;
        else
            NSLog(@"VHFColorAdditions undefinded colorSpace to white device colorSpace");

        if ([colorSpace isEqualToString: NSDeviceWhiteColorSpace])
            return [NSColor colorWithDeviceWhite:w alpha:[self alphaComponent]];
        if ([colorSpace isEqualToString: NSCalibratedWhiteColorSpace])
            return [NSColor colorWithCalibratedWhite:w alpha:[self alphaComponent]];
    }
    return nil;
}

- (NSColor*)colorUsingColorSpaceName:(NSString *)colorSpace device:(NSDictionary *)deviceDescription
{   NSString	*selfColorSpace = [self colorSpaceName];

    if (colorSpace == nil)
    {
        if (deviceDescription != nil)
            colorSpace = [deviceDescription objectForKey: NSDeviceColorSpaceName];
        if (colorSpace == nil)
            colorSpace = NSDeviceRGBColorSpace;
    }
    if ([colorSpace isEqualToString: [self colorSpaceName]])
    {
        return self;
    }

    if ([colorSpace isEqualToString: NSNamedColorSpace] ||
        [selfColorSpace isEqualToString:NSNamedColorSpace])
        /*[colorSpace isEqualToString: NSDynamicSystemColorSpace] ||
        [selfColorSpace isEqualToString: NSDynamicSystemColorSpace]*/
    {
      // FIXME: We cannot convert to named color space.
        return nil;
    }
    /* wanted is calibrated||device rgb color */
    if ([colorSpace isEqualToString:NSCalibratedRGBColorSpace] ||
        [colorSpace isEqualToString:NSDeviceRGBColorSpace])
    {   double	r = 0.0, g = 0.0, b = 0.0;

        /* we are cmyk color */
        if ([selfColorSpace isEqualToString:NSDeviceCMYKColorSpace]) // bw rgb cmy hsb
        {   double c = [self cyanComponent];
            double m = [self magentaComponent];
            double y = [self yellowComponent];
            double white = 1.0 - [self blackComponent];

            r = (c > white) ? 0 : (white - c);
            g = (m > white) ? 0 : (white - m);
            b = (y > white) ? 0 : (white - y);
        }
        /* we are white color */
        else if ([selfColorSpace isEqualToString:NSDeviceWhiteColorSpace] ||
                 [selfColorSpace isEqualToString:NSCalibratedWhiteColorSpace])
        {
            r = g = b = [self whiteComponent];
        }
        /* we are device rgb color */
        else if ([selfColorSpace isEqualToString:NSDeviceRGBColorSpace])
        {
            r = [self redComponent];
            g = [self greenComponent];
            b = [self blueComponent];
        }
        else
            NSLog(@"VHFColorAdditions undefinded colorSpace to rgb colorSpace");

        if ([colorSpace isEqualToString:NSCalibratedRGBColorSpace])
            return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:[self alphaComponent]];
        if ([colorSpace isEqualToString:NSDeviceRGBColorSpace])
            return [NSColor colorWithDeviceRed:r green:g blue:b alpha:[self alphaComponent]];
    }
    /* wanted is device cmyk color */
    if ([colorSpace isEqualToString: NSDeviceCMYKColorSpace])
    {   double	c = 0.0, m = 0.0, y = 0.0, k = 0.0;

        /* we are rgb color */
        if ([selfColorSpace isEqualToString:NSDeviceRGBColorSpace] ||
            [selfColorSpace isEqualToString:NSCalibratedRGBColorSpace])
        {
            c = 1.0 - [self redComponent];
            m = 1.0 - [self greenComponent];
            y = 1.0 - [self blueComponent];
        }
        /* we are white color */
        else if ([selfColorSpace isEqualToString:NSDeviceWhiteColorSpace] ||
                 [selfColorSpace isEqualToString:NSCalibratedWhiteColorSpace])
        {
            c = m = y = 0.0;
            k = 1.0 - [self whiteComponent];
        }
        else
            NSLog(@"VHFColorAdditions undefinded colorSpace to cmyk device colorSpace");

      return [NSColor colorWithDeviceCyan:c magenta:m yellow:y black:k alpha:[self alphaComponent]];
    }
    /* wanted is device white color */
    if ([colorSpace isEqualToString: NSDeviceWhiteColorSpace] ||
        [colorSpace isEqualToString: NSCalibratedWhiteColorSpace])
    {   double	w = 0.0;

        /* we are cmyk color */
        if ([selfColorSpace isEqualToString:NSDeviceCMYKColorSpace]) // bw rgb cmy hsb
        {
            w =  1.0 - [self blackComponent] -
            ([self cyanComponent] + [self magentaComponent] + [self yellowComponent]) / 3.0;
        }
        /* we are white color */
        else if ([selfColorSpace isEqualToString:NSCalibratedWhiteColorSpace])
        {
            w = [self whiteComponent];
        }
        /* we are device rgb color */
        else if ([selfColorSpace isEqualToString:NSCalibratedRGBColorSpace] ||
                 [selfColorSpace isEqualToString:NSDeviceRGBColorSpace])
        {
            w = ([self redComponent] + [self greenComponent] + [self blueComponent]) / 3.0;
        }
        else
            NSLog(@"VHFColorAdditions undefinded colorSpace to white device colorSpace");

        if ([colorSpace isEqualToString: NSDeviceWhiteColorSpace])
            return [NSColor colorWithDeviceWhite:w alpha:[self alphaComponent]];
        if ([colorSpace isEqualToString: NSCalibratedWhiteColorSpace])
            return [NSColor colorWithCalibratedWhite:w alpha:[self alphaComponent]];
    }
    return nil;
}

@end
