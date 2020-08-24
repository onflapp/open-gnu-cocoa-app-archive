/* PreferencesMacros.h
 * Macros for easier access of basic preferences from default database
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-15
 * Modified: 2011-03-30 (Prefs_DisableAutoUpdate added, clean-up)
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

#ifndef VHF_H_PREFERENCEMACROS
#define VHF_H_PREFERENCEMACROS

/* General */
#define Prefs_Caching           ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"doCaching"]           isEqual:@"YES"]) ? YES : NO )
#define Prefs_ExpertMode        ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"expertMode"]          isEqual:@"YES"]) ? YES : NO )
#define Prefs_RemoveBackups     ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"removeBackups"]       isEqual:@"YES"]) ? YES : NO )
#define Prefs_SelectNonEditable ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"selectNonEditable"]   isEqual:@"YES"]) ? YES : NO )
#define Prefs_DisableAntiAlias  ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"disbaleAntiAliasing"] isEqual:@"YES"]) ? YES : NO )
#define Prefs_OSPropertyList    ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"writeOSPropertyList"] isEqual:@"YES"]) ? YES : NO )
#define Prefs_SelectByBorder    ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"selectByBorder"]      isEqual:@"YES"]) ? YES : NO )
#define Prefs_Antialias         ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"disableAntiAliasing"] isEqual:@"YES"]) ? NO : YES )
#define Prefs_OSPropertyList    ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"writeOSPropertyList"] isEqual:@"YES"]) ? YES : NO )
#define Prefs_DisableAutoUpdate ( ([[[NSUserDefaults standardUserDefaults] \
                                    objectForKey:@"disableAutoUpdate"]   isEqual:@"YES"]) ? YES : NO )

#define Prefs_Snap              [[NSUserDefaults standardUserDefaults] integerForKey:@"snap"]
#define Prefs_Unit              [[NSUserDefaults standardUserDefaults] integerForKey:@"unit"]
#define Prefs_LineWidth         [[NSUserDefaults standardUserDefaults] floatForKey:@"lineWidth"]
#define Prefs_CacheLimit        [[NSUserDefaults standardUserDefaults] integerForKey:@"cacheLimit"]*1000000

#define Prefs_WindowGrid        [[NSUserDefaults standardUserDefaults] integerForKey:@"windowGrid"]

/* Import */
#define Prefs_ColorToLayer      ( ([[[NSUserDefaults standardUserDefaults] \
                                     objectForKey:@"colorToLayer"] isEqual:@"YES"]) ? YES : NO )
#define Prefs_FillObjects       ( ([[[NSUserDefaults standardUserDefaults] \
                                     objectForKey:@"fillObjects"] isEqual:@"YES"]) ? YES : NO )
#define Prefs_DXFRes            [[[NSUserDefaults standardUserDefaults] objectForKey:@"dxfRes"] floatValue]
#define Prefs_PSPreferArcs      ( ([[[NSUserDefaults standardUserDefaults] \
                                     objectForKey:@"psPreferArcs"] isEqual:@"YES"]) ? YES : NO )
#define Prefs_PSFlattenText     ( ([[[NSUserDefaults standardUserDefaults] \
                                     objectForKey:@"psFlattenText"] isEqual:@"YES"]) ? YES : NO )
#define Prefs_GerberParmsFileName   [[NSUserDefaults standardUserDefaults] objectForKey:@"gerberParmsFileName"]
#define Prefs_HPGLParmsFileName [[NSUserDefaults standardUserDefaults] objectForKey:@"hpglParmsFileName"]
#define Prefs_DINParmsFileName  [[NSUserDefaults standardUserDefaults] objectForKey:@"dinParmsFileName"]

/* Export */
#define Prefs_ExportFlattenText ( ([[[NSUserDefaults standardUserDefaults] \
                                     objectForKey:@"exportFlattenText"] isEqual:@"YES"]) ? YES : NO )

#endif // VHF_H_PREFERENCEMACROS
