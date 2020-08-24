/* InspectorPanel.h
 * Cenon Inspector panel
 *
 * Copyright (C) 1996-2010 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1993-10-01
 * modified: 2008-03-17 (Accessory replaces AllText)
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

#ifndef VHF_H_INSPECTORPANEL
#define VHF_H_INSPECTORPANEL

#include <AppKit/AppKit.h>
#include <VHFShared/vhfCommonFunctions.h>
#include "IPBasicLevel.h"
#include "../PreferencesMacros.h"
#include "../Graphics.h"
#include "../functions.h"

#define BUTTONLEFT      0
#define BUTTONRIGHT     1
#define BUTTONUP        2
#define BUTTONDOWN      3

#define IP_OBJECT       0
#define IP_STROKEWIDTH  1
#define IP_FILLING      2
//#define IP_TEXT       3
#define IP_ACC          3
#define IP_LAYERS       4
#define IP_DEFAULT      99

@interface InspectorPanel:IPBasicLevel
{
    NSString            *defaultName;

    VGraphic            *graphic;
    id                  activeWindow;   // FIXME: we should turn that into a view + controller class
    id                  levRadio;
    NSScrollView        *levView;
    id                  objectWindow;
    id                  defaultView;    // empty view (nil contentView doesn't work with GNUstep)
    NSMutableDictionary *viewDict;      // content views for window class names

    id                  allStrokeWindow;
    id                  allFillingWindow;
    id                  allAccWindow;
    id                  allLayersWindow;
    id                  lineWindow;
    id                  line3DWindow;
    id                  curveWindow;
    id                  arcWindow;
    id                  threadWindow;
    id                  pathWindow;
    id                  polyLineWindow;
    id                  textWindow;
    id                  textPathWindow;
    id                  groupWindow;
    id                  rectangleWindow;
    id                  imageWindow;
    id                  markWindow;
    id                  webWindow;
    id                  sinkingWindow;
    id                  crosshairsWindow;

    id                  dataView;
    BOOL                tabEvent;
    id                  docView;        // temporary current document view
}

- init;
- (void)update:sender;

- (void)setLevel:sender;
- (void)setLevelAt:(int)level;

- windowAt:(int)level;

- (void)loadList:(NSArray*)list;
- (void)loadGraphic:(id)g;
- (void)setLevelView:theView;

- (void)updateInspector;

- (void)setDocView:(id)aView;
- (id)docView;

@end

#endif // VHF_H_INSPECTORPANEL
