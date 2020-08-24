/* ModuleChoiceController.m created by ja on Tue 10-Mar-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "ModuleChoiceController.h"
#import <SenFormController.h>
#import <SenStringArrayBrowserController.h>
#import <SenOpenPanelController.h>
#import <CvsRepository.h>


//-------------------------------------------------------------------------------------

@interface ModuleChoiceController (Private)
- (void)reloadContent;
- (void)repositoryChanged:(NSNotification *)notification;
- (void)panelWillRun:(NSNotification *)notification;
@end

//-------------------------------------------------------------------------------------

@implementation ModuleChoiceController
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [moduleDict release];
    [repository release];
    [super dealloc];
}


- (void) awakeFromNib
{
    [[NSNotificationCenter defaultCenter]
                  addObserver:self
                     selector:@selector(repositoryChanged:)
                         name:@"RepositoryChanged"
                       object:nil];
    [[NSNotificationCenter defaultCenter]
                  addObserver:self
                     selector:@selector(panelWillRun:)
                         name:@"PanelWillRun"
                       object:panel];
    [moduleNameBrowser setDoubleAction:@selector(doubleClickedModuleName:)];
}

- (void)panelWillRun:(NSNotification *)notification
{
    CvsRepository *repositoryToUse;
    [repository release];

    repositoryToUse=[formController objectValueForKey:@"repository"];
    if (!repositoryToUse) {
        repositoryToUse=[CvsRepository defaultRepository];
    }
    repository=[repositoryToUse retain];
    [[modulePathButton menu] setAutoenablesItems:NO];
    [modulePathButton setEnabled:[repository isLocal]];
    [self reloadContent];
}

- (void)openModuleNamesPanel:sender
{
    BOOL isValid= NO;
    int res= -1;

    [moduleNamesPanel orderFront: self];
    res= [NSApp runModalForWindow: moduleNamesPanel];
    isValid= (res == NSOKButton);
    [moduleNamesPanel orderOut: self];

    if (isValid) {
        NSString *choosen;
        choosen=[moduleNamesListControler selectedEntry];
        if (choosen) {
            [[formController controlForKey:@"module"] setStringValue:choosen];
        }
    }
}

- (void)cancelModuleNames:sender
{
    [NSApp stopModalWithCode:NSCancelButton];
}

- (void)okModuleNames:sender
{
    [NSApp stopModalWithCode:NSOKButton];
}

- (void)selectModulePath:sender
{
    NSString *cvsRoot;
    NSString *defaultOpenPanelPath;
    NSString *moduleName;
    id moduleControl;

    moduleControl=[formController controlForKey:@"module"];
    cvsRoot=[repository path];
    moduleName=[moduleControl stringValue];
    if (moduleName && ![moduleName isEqual:@""]) {
        defaultOpenPanelPath=[cvsRoot stringByAppendingPathComponent:moduleName];
    } else {
        defaultOpenPanelPath=cvsRoot;
    }
    [moduleOpenPanelController setStringValue:defaultOpenPanelPath];

    if ([moduleOpenPanelController senOpenPanel]) {
        NSString* tempPath=[moduleOpenPanelController stringValue];

#if 0
        while ([tempPath length]>=[cvsRoot length]) {
            if ([tempPath isEqual:cvsRoot]) {
                tempPath=[[moduleOpenPanelController stringValue] substringFromIndex:[cvsRoot length]];
                if ([tempPath length]>=1) {
                    tempPath=[tempPath substringFromIndex:1];
                }
                [moduleControl setStringValue:tempPath];
              //  [pathField setStringValue: [[[pathField stringValue] stringByDeletingLastPathComponent] stringByAppendingPathComponent: tempPath]];
                break;
            }
            tempPath=[tempPath stringByDeletingLastPathComponent];
        }
#else
        // We can not compare filenames, because on MacOSX,
        // /Network is replaced by /automount/Network. Let's compare file IDs.
        NSFileManager	*fileManager = [NSFileManager defaultManager];
        NSDictionary	*aDict = [fileManager fileAttributesAtPath:cvsRoot traverseLink:YES];
        NSNumber		*cvsRootSystemNumber = [aDict objectForKey:NSFileSystemNumber];
        NSNumber		*cvsRootSystemFileNumber = [aDict objectForKey:NSFileSystemFileNumber];
        
        moduleName = @"";
        while ([tempPath length]>=[cvsRoot length]) {
            aDict = [fileManager fileAttributesAtPath:tempPath traverseLink:YES];
            if ([[aDict objectForKey:NSFileSystemFileNumber] isEqual:cvsRootSystemFileNumber] && [[aDict objectForKey:NSFileSystemNumber] isEqual:cvsRootSystemNumber]) {
                [moduleControl setStringValue:moduleName];
                //  [pathField setStringValue: [[[pathField stringValue] stringByDeletingLastPathComponent] stringByAppendingPathComponent: tempPath]];
                break;
            }
            moduleName = [[tempPath lastPathComponent] stringByAppendingPathComponent:moduleName];
            tempPath=[tempPath stringByDeletingLastPathComponent];
        }
#endif
    }
} // selectPath:

- (void) reloadContent
{
    [moduleNamesListControler setStringArrayValue:[[CvsRepository defaultRepository] modulesSymbolicNames]];
} // reloadContent

- (void)repositoryChanged:(NSNotification *)notification
{
    [self reloadContent];
}


@end

@implementation SenStringArrayBrowserController(ModuleChoiceController)

// WARNING: this is a quick hack to allow double-click on module name => click on OK button (tagged 627)
// SenStringArrayBrowserController provides no easy way to do it cleanly, if we don't subclass it (Stephane)
// Known bug: a NSBeep() is performed after double-click!
- (void) doubleClickedModuleName:(id)sender
{
    [[[browser superview] viewWithTag:627] performClick:sender];
}

@end
