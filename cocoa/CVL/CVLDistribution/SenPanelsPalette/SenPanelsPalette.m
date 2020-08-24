/* SenPanelsPalette.m created by ja on Tue 24-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenPanelsPalette.h"
#ifndef RHAPSODY
#ifdef PANTHER
#import <SenFormControllerConnector.h>
#import <SenFormPanelController.h>
#import <SenPanelFactory.h>
#import <SenOpenPanelController.h>
#import <SenMultiPageController.h>
#else /* Not PANTHER */
#import <SenPanels.subproj/SenFormControllerConnector.h>
#import <SenPanels.subproj/SenFormPanelController.h>
#import <SenPanels.subproj/SenPanelFactory.h>
#import <SenPanels.subproj/SenOpenPanelController.h>
#import <SenPanels.subproj/SenMultiPageController.h>
#endif /* End PANTHER */
#else /* Not MACOSX */
#import <SenPanels/SenFormControllerConnector.h>
#import <SenPanels/SenFormPanelController.h>
#import <SenPanels/SenPanelFactory.h>
#import <SenPanels/SenOpenPanelController.h>
#import <SenPanels/SenMultiPageController.h>
#endif /* End MACOSX */

@implementation SenPanelsPalette

- (void)finishInstantiate
{
    /* `finishInstantiate' can be used to associate non-view objects with
     * a view in the palette's nib.  For example: */
    [self associateObject:[[SenFormController alloc] init] ofType:IBObjectPboardType
                    withView:formControllerRepresentative];
    [self associateObject:[[SenFormPanelController alloc] init] ofType:IBObjectPboardType
                    withView:formPanelControllerRepresentative];
    [self associateObject:[[SenOpenPanelController alloc] init] ofType:IBObjectPboardType
                    withView:openPanelControllerRepresentative];
    [self associateObject:[[SenMultiPageController alloc] init] ofType:IBObjectPboardType
                    withView:multiPageControllerRepresentative];
}

@end

@implementation SenFormController (SenFormsPaletteInspector)

- (NSString *)connectInspectorClassName
{
    return @"SenFormControllerConnectInspector";
}

- (NSString *)inspectorClassName
{
    return @"IBCustomClassInspector";
}

@end

@implementation SenMultiPageController (SenFormsPaletteInspector)

- (NSString *)inspectorClassName
{
    return @"IBCustomClassInspector";
}

@end

@implementation SenOpenPanelController (SenFormsPaletteInspector)

- (NSString *)inspectorClassName
{
    return @"SenOpenPanelInspector";
}

@end

@implementation SenFormPanelController (SenFormsPaletteInspector)

- (NSString *)inspectorClassName
{
    return @"IBCustomClassInspector";
}

@end

@implementation SenPanelFactory (SenFormsPaletteInspector)

- (NSString *)inspectorClassName
{
    return @"IBCustomClassInspector";
}

@end

