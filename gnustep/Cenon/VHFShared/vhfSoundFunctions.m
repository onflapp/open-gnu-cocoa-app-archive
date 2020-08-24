/*
 * vhfSoundFunctions.m
 *
 * Copyright (C) 2000-2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-04-04
 * modified: 2010-08-18 (Apple added)
 *
 * This file is part of the vhf Shared Library.
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

#ifdef __APPLE__
#   include <AppKit/NSSound.h>
#   include "vhfCommonFunctions.h"
#endif
#ifdef __NeXT__
    #include <SoundKit/Sound.h>
#endif

#include "vhfSoundFunctions.h"

void vhfPlaySound(NSString *soundName)
{
#   ifdef __APPLE__
    NSString    *path;  //= [bundle pathForResource:soundName ofType:@"aif"];
    NSString    *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) objectAtIndex:0];
    NSSound     *sound;

    path = vhfPathWithPathComponents(libraryPath, @"Sounds", soundName, nil);
    path = [path stringByAppendingPathExtension:@"aiff"];
    sound = [[NSSound alloc] initWithContentsOfFile:path byReference:NO];
    [sound play];
    [sound release];
#   endif
#   ifdef __NeXT__
        [[Sound findSoundFor:soundName] play];
#   endif
}
