/* PreferencesPanel.h
 * Control class of preferences panel
 *
 * Copyright (C) 1995-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1999-03-15
 * Modified: 2011-09-13 (-update: new)
 *           2003-07-22
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

#include <AppKit/AppKit.h>

#define PP_IMPORT	0
#define PP_CONTROL	1
#define PP_MISC		3
#define PP_DEFAULT	99

#define BUTTONLEFT	0
#define BUTTONRIGHT	1
#define BUTTONUP	2
#define BUTTONDOWN	3

@interface PreferencesPanel:NSPanel
{
    id	iconMatrix;			// the matrix of icons at the top of the panel
    id	moduleView;			// the view where the modules are placed

    NSMutableArray	*modules;	// the loaded modules
}

- init;
- (void)loadModules;
- (void)addBundleWithPath:(NSString*)path;

- (void)setModule:sender;
- (void)setModuleAt:(int)level orderFront:(BOOL)orderFront;
- (void)update:sender;

@end
