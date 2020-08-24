/* SenOpenPanelController.h created by ja on Mon 02-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <AppKit/AppKit.h>

@interface SenOpenPanelController : NSObject <NSCoding>
{
    SEL action;
    id target;
    NSString *directory;
    NSArray *fileNames;
    BOOL saveVsOpenPanel;
    id valueField;
    
    NSView *accessoryView;
    NSString *title;
    NSString *prompt;
    NSString *requiredFileType;
    BOOL treatsFilePackagesAsDirectories;
    id delegate;
    // NSOpenPanel only
    BOOL canChooseFiles;
    BOOL canChooseDirectories;
    BOOL allowsMultipleSelection;
    BOOL isInUse;
}
- (BOOL) isInUse;

- (void)setAction:(SEL)aSelector;
- (SEL)action;
- (void)setTarget:(id)anObject;
- (id)target;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)value;

- (BOOL)useSaveVsOpenPanel;
- (void)setUseSaveVsOpenPanel:(BOOL)flag;

- (BOOL)senOpenPanel;
- (BOOL)openPanel:(id)sender;

// NSSavePanel options
- (void)setPrompt:(NSString *)prompt;
- (NSString *)prompt;
- (void)setTitle:(NSString *)title;
- (NSString *)title;
- (void)setRequiredFileType:(NSString *)type;
- (NSString *)requiredFileType;
- (void)setTreatsFilePackagesAsDirectories:(BOOL)flag;
- (BOOL)treatsFilePackagesAsDirectories;

// NSOpenPanel options
- (void)setAllowsMultipleSelection:(BOOL)flag;
- (BOOL)allowsMultipleSelection;
- (void)setCanChooseDirectories:(BOOL)flag;
- (BOOL)canChooseDirectories;
- (void)setCanChooseFiles:(BOOL)flag;
- (BOOL)canChooseFiles;

// Actions
- (IBAction)senOpenPanel:(id)sender;
- (IBAction)takeStringValueFrom:(id)sender;
- (IBAction)takeStringArrayValueFrom:(id)sender;
- (IBAction)takeObjectValueFrom:(id)sender;
@end

@interface SenOpenPanelController (NSCoding) <NSCoding>
@end
