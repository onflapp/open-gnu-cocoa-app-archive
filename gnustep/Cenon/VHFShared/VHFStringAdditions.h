/* VHFStringAdditions.h
 * vhf NSString additions
 *
 * Copyright (C) 1997-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1997-07-08
 * modified: 2012-02-07 (-writeToFile:... added)
 *           2011-09-01 (-stringWithContentsOfFile: loads flexible on Apple)
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

#ifndef VHF_H_STRINGADDITIONS
#define VHF_H_STRINGADDITIONS

#include <Foundation/Foundation.h>

@interface NSString(VHFStringAdditions)

#ifdef __APPLE__
+ (id)stringWithContentsOfFile:(NSString*)path;   // Apple only, for it's deprecated since 10.5 and makes no sense
#   if MAC_OS_X_VERSION_MAX_ALLOWED < 1050 /*MAC_OS_X_VERSION_10_5*/
    - (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile  // added in 10.5
               encoding:(NSStringEncoding)enc error:(NSError **)error;
#   endif
#endif

+ (NSString*)stringWithFloat:(float)value decimals:(int)decimals;
+ (NSString*)stringWithFloat:(float)value;

- (NSString*)stringByRemovingTrailingCharacters:(NSString*)chars;
- (NSString*)stringByReplacing:(NSString*)from by:(NSString*)to;
- (NSString*)stringByReplacing:(NSString*)from by:(NSString*)to all:(BOOL)replaceAll;
- (NSString*)stringByReplacingSequence:(NSString*)sequence by:(NSString*)to;
- (NSString*)stringByReplacingSequence:(NSString*)sequence by:(NSString*)to wildcards:(NSDictionary*)wildcards;
- (NSString*)stringByAdjustingDecimal;
- (NSString*)stringWithLength:(int)length;
- (NSString*)stringWithLength:(int)length fillCharacter:(NSString*)fillChar;

- (int)appearanceCountOfCharacter:(unsigned char)c;
- (int)countOfCharacter:(unsigned char)c inRange:(NSRange)range;

- (NSRange)rangeOfSequence:(NSString*)sequence options:(int)options;
- (NSRange)rangeOfSequence:(NSString*)sequence options:(int)options range:(NSRange)sRange;
- (NSRange)rangeOfSequence:(NSString*)sequence options:(int)options range:(NSRange)sRange wildcards:(NSDictionary*)wildcards;
@end

#endif // VHF_H_STRINGADDITIONS
