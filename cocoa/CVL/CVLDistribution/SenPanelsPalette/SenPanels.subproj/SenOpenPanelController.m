/* SenOpenPanelController.m created by ja on Mon 02-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenOpenPanelController.h"
#import <SenFoundation/SenFoundation.h>

@interface SenOpenPanelController (private)
- (void)initValues;
- (void)senOpenPanelController:(SenOpenPanelController *)aSenOpenPanelController selectedDirectory:(NSString *)aDirectory selectedFileNames:(NSArray *)someFilenames;
@end

@implementation SenOpenPanelController
+ (void)initialize
{
    if (self == [SenOpenPanelController class]) {
        [self setVersion:1];
    }
}

- (void)setAction:(SEL)aSelector
{
    action=aSelector;
}

- (id)init
{
    if ( (self=[super init]) ) {
        [self initValues];
    }
    return self;
}

- (void)initValues
{
    title=@"";
    prompt=@"";
    requiredFileType=@"";
    treatsFilePackagesAsDirectories=NO;
    canChooseFiles=YES;
    canChooseDirectories=NO;
    allowsMultipleSelection=NO;
}

- (SEL)action
{
    return action;
}

- (void)setTarget:(id)anObject
{
    ASSIGN(target, anObject);
}

- (id)target
{
    return target;
}

- (void)setUseSaveVsOpenPanel:(BOOL)flag
{
    saveVsOpenPanel=flag;
}

- (BOOL)useSaveVsOpenPanel
{
    return saveVsOpenPanel;
}

- (NSOpenPanel *)initializedOpenPanel
{
    NSOpenPanel *panel;

    if (saveVsOpenPanel) {
        panel=(NSOpenPanel *)[NSSavePanel savePanel];
    } else {
        panel=[NSOpenPanel openPanel];
    }

    if (delegate) {
        [panel setDelegate:delegate];
    }
    if (accessoryView) {
        [panel setAccessoryView:accessoryView];
    }
    if (title && ![title isEqual:@""]) {
        [panel setTitle:title];
    }
    if (prompt && ![prompt isEqual:@""]) {
        [panel setPrompt:prompt];
    }
    if (requiredFileType && ![requiredFileType isEqual:@""]) {
        [panel setRequiredFileType:requiredFileType];
    }
    [panel setTreatsFilePackagesAsDirectories:treatsFilePackagesAsDirectories];

    if (!saveVsOpenPanel) {
        [panel setCanChooseFiles:canChooseFiles];
        [panel setCanChooseDirectories:canChooseDirectories];
        [panel setAllowsMultipleSelection:allowsMultipleSelection];
    }
	[panel setCanCreateDirectories:YES];
    return panel;
}

- (IBAction)senOpenPanel:(id)sender
    /*" This is an action method that is a cover for the method -senOpenPanel.
    "*/
{
    (void)[self senOpenPanel];
}

- (BOOL)openPanel:(id)sender
    /*" This is an old misformed action method. It has been deprecated. Use 
        either senOpenPanel: for an action method or senOpenPanel if a boolean
        return value is needed. We are keeping this method since some nibs might
        be using it and they are not easy to find.
    "*/
{
    return [self senOpenPanel];
}

- (BOOL)senOpenPanel
{
    int resultCode;
    NSOpenPanel *panel;
	SEL aSelector = NULL;

    isInUse = YES;
    panel=[self initializedOpenPanel];

    if (valueField) {
        [self takeObjectValueFrom:valueField];
    }
    if (fileNames && [fileNames count]) {
        resultCode=[panel runModalForDirectory:directory file:[[fileNames objectAtIndex:0] lastPathComponent]];
    } else if (directory) {
        resultCode=[panel runModalForDirectory:directory file:@""];
    } else {
        resultCode=[panel runModal];
    }

    if (resultCode==NSOKButton) {
        ASSIGN(directory, [panel directory]);
        ASSIGN(fileNames, [NSArray arrayWithObject:[panel filename]]);
        if (action && target) {
            [target performSelector:action withObject:self];
        }
		if ( delegate != nil ) {
			aSelector = @selector(senOpenPanelController:selectedDirectory:selectedFileNames:);
			if ([delegate respondsToSelector:aSelector] == YES) {
				[delegate senOpenPanelController:self 
									   selectedDirectory:directory 
									   selectedFileNames:fileNames];
			}
		}
        isInUse = NO;
        return YES;
    }
    isInUse = NO;
    return NO;
}

- (id)objectValue
{
    return fileNames;
}

- (NSString *)stringValue
{
    return [fileNames objectAtIndex:0];
}

- (void)setStringValue:(NSString *)value
{
    ASSIGN(directory, [value stringByDeletingLastPathComponent]);
    ASSIGN(fileNames, [NSArray arrayWithObject:value]);
}

// Actions
- (IBAction)takeStringValueFrom:(id)sender
{
    id anObjectValue = nil;
    
    anObjectValue = [sender objectValue];
    if ( (anObjectValue != nil) && ([anObjectValue isKindOfClass:[NSString class]] == NO) ) {
        [NSException raise:@"SenAssertClassException" format:
    @"\"%@\" should be of class NSString but instead it is of class %@! Occurred in file %s:%d in method [%@ %@].", 
            anObjectValue, NSStringFromClass([NSString class]), 
            __FILE__, __LINE__, NSStringFromClass([self class]), 
            NSStringFromSelector(_cmd)]; 
    } 

    [self setStringValue:(NSString *)anObjectValue];
}

- (IBAction)takeStringArrayValueFrom:(id)sender
{
    id value;

    value=[sender objectValue];

    ASSIGN(directory , [[value objectAtIndex:0] stringByDeletingLastPathComponent]);
    [fileNames release];
    fileNames=[value copy];
}

- (IBAction)takeObjectValueFrom:(id)sender
{
    id value;

    value=[sender objectValue];
    if ([value isKindOfClass:[NSString class]]) {
        [self takeStringValueFrom:sender];
    } else if ([value isKindOfClass:[NSArray class]]) {
        [self takeStringArrayValueFrom:sender];
    }
}


// NSSavePanel options
- (void)setPrompt:(NSString *)value
{
    ASSIGN(prompt, value);
}

- (NSString *)prompt
{
    return prompt;
}

- (void)setTitle:(NSString *)value
{
    ASSIGN(title, value);
}

- (NSString *)title
{
    return title;
}

- (void)setRequiredFileType:(NSString *)value
{
    ASSIGN(requiredFileType, value);
}

- (NSString *)requiredFileType
{
    return requiredFileType;
}

- (void)setTreatsFilePackagesAsDirectories:(BOOL)flag
{
    treatsFilePackagesAsDirectories=flag;
}

- (BOOL)treatsFilePackagesAsDirectories
{
    return treatsFilePackagesAsDirectories;
}

// NSOpenPanel options
- (void)setAllowsMultipleSelection:(BOOL)flag
{
    allowsMultipleSelection=flag;
}

- (BOOL)allowsMultipleSelection
{
    return allowsMultipleSelection;
}

- (void)setCanChooseDirectories:(BOOL)flag
{
    canChooseDirectories=flag;
}

- (BOOL)canChooseDirectories
{
    return canChooseDirectories;
}

- (void)setCanChooseFiles:(BOOL)flag
{
    canChooseFiles=flag;
}

- (BOOL)canChooseFiles
{
    return canChooseFiles;
}

// NSCoding
- (id)initWithCoder:(NSCoder *)decoder
{
    int		version;

    self = [self init];

    version = [decoder versionForClassName:@"SenOpenPanelController"];

    switch (version) {
    case 1:
        ASSIGN(title, [decoder decodeObject]);
        ASSIGN(prompt, [decoder decodeObject]);
        ASSIGN(requiredFileType, [decoder decodeObject]);
        [decoder decodeValueOfObjCType:@encode(BOOL) at:&treatsFilePackagesAsDirectories];
        [decoder decodeValueOfObjCType:@encode(BOOL) at:&canChooseFiles];
        [decoder decodeValueOfObjCType:@encode(BOOL) at:&canChooseDirectories];
        [decoder decodeValueOfObjCType:@encode(BOOL) at:&allowsMultipleSelection];
    case 0:
        [decoder decodeValueOfObjCType:@encode(BOOL) at:&saveVsOpenPanel];
    default:
        break;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];
    // Version == 1
    [coder encodeObject:title];
    [coder encodeObject:prompt];
    [coder encodeObject:requiredFileType];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&treatsFilePackagesAsDirectories];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&canChooseFiles];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&canChooseDirectories];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&allowsMultipleSelection];

    // Version == 0
    [coder encodeValueOfObjCType:@encode(BOOL) at:&saveVsOpenPanel];

}

- (BOOL) isInUse
{
    return isInUse;
}

@end
