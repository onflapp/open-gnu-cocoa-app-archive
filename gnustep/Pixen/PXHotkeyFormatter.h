//
//  PXHotkeyFormatter.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sun Apr 04 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PXHotkeyFormatter : NSFormatter
{

}

- stringForObjectValue:anObject;
- (BOOL)getObjectValue:(id *)anObject forString:string errorDescription:(NSString **)error;
- attributedStringForObjectValue:anObject defaultAttributes:attributes;

@end
