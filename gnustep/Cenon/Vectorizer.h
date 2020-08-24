/*
 * Vectorizer.h
 *
 * Copyright (C) 2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2011-04-05
 * modified: 2011-04-05
 */

#include <AppKit/AppKit.h>

@interface Vectorizer:NSObject
{
    id panel;
    id switchMatrix;
    id typPopup;        // lines or curves ?
    id tolSlider;
    id tolField;
}

+ (Vectorizer*)sharedInstance;
- (void)showPanel:(id)sender;

/* action methods */
- (void)set:(id)sender;
- (void)setTypePopup:(id)sender;
- (void)setTolerance:(id)sender;    // updates tolerance

@end
