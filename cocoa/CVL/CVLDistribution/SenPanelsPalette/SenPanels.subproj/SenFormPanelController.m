/* SenFormPanelController.m created by ja on Wed 25-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.


#import "SenFormPanelController.h"
#import <SenFoundation/SenFoundation.h>


@implementation SenFormPanelController

- (void) dealloc
{
    RELEASE(panel);
    RELEASE(formController);
    
    [super dealloc];
}

- (int)showAndRunModal
{
    return [self showAndRunModal:YES];
}

- (int)showAndRunModal:(BOOL)modalFlag
{
    modalResult = -1;
    isInUse = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:@"PanelWillRun" object:self];
    [panel makeKeyAndOrderFront:self];
    if([panel initialFirstResponder])
        [panel makeFirstResponder:[panel initialFirstResponder]];
    modal = modalFlag;
    if(modal){
        modalResult= [NSApp runModalForWindow: panel];
        [panel orderOut: self];
        isInUse = NO;
    }

    return modalResult;
}

- (void) endNonModal
{
    [panel orderOut: self];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PanelDidRun" object:self];
    isInUse = NO;
}

- (int) modalResult
{
    return modalResult;
}

- (void)cancel:sender
{
    modalResult = NSCancelButton;
    if(modal)
        [NSApp stopModalWithCode:modalResult];
    else
        [self endNonModal];
} // cancel:


- (void)ok:sender
{
    [formController takeObjectValuesFromAllControls];
    modalResult = NSOKButton;
    if(modal)
        [NSApp stopModalWithCode:modalResult];
    else
        [self endNonModal];
} // ok:

- (void) windowWillClose:(NSNotification *)notification
{
    if(modalResult == -1)
        [self cancel:nil];
}

- (void)awakeWithProperties:(NSDictionary *)someProperties
{
    NSDictionary *defaultValues;
    if ( (defaultValues=[someProperties objectForKey:@"defaultValues"]) ) {
        [self setDictionaryValue:defaultValues];
    }
     if ([[someProperties objectForKey:@"autosaveFrame"] isEqual:@"YES"]) {
         // Thank you to Tom Hageman <trh@xs4all.nl> for this feature
         [panel setFrameAutosaveName:[someProperties objectForKey:@"nib"]];
     }
}

- (NSWindow *)panel
{
    return panel;
}

- (SenFormController *)formController
{
    return formController;
}

- (NSDictionary *)dictionaryValue
{
    return [formController dictionaryValue];
}

- (id)objectValueForKey:(NSString *)aKey
{
    return [formController objectValueForKey:aKey];
}

- (void)setDictionaryValue:(NSDictionary *)newValues
{
    NSString *panelTitle;
    [formController setDictionaryValue:newValues];
    if ( (panelTitle=[newValues objectForKey:@"PanelTitle"]) ) {
        [panel setTitle:panelTitle];
    }
}

- (void)setObjectValue:(id)newValue forKey:(NSString *)aKey
{
    if ([aKey isEqual:@"PanelTitle"]) {
        [panel setTitle:newValue];
    }
    [formController setObjectValue:newValue forKey:aKey];
}

- (void)addValuesFromDictionary:(NSDictionary *)newValues
{
    NSString *panelTitle;
    [formController addValuesFromDictionary:newValues];
    if ( (panelTitle=[newValues objectForKey:@"PanelTitle"]) ) {
        [panel setTitle:panelTitle];
    }
}

- (id)initWithCoder:(NSCoder *)decoder
{
    int		version;

    self = [self init];

    version = [decoder versionForClassName:@"SenFormController"];
    /*
    switch (version) {
    case 0:
        break;
    default:
        break;
    } */
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];

    // Version == 1
}

- (BOOL) isInUse
{
    return isInUse;
}

- (void)setupAuxiliaryController
    /*" This method will send the message -performSetup to the auxiliary
        controller if one exsits. This allows the auxiliary controller a chance
        to set itself up before processing begins.
    "*/
{
    if ( auxiliaryController != nil ) {
        [auxiliaryController performSetup];
    }    
}


@end
