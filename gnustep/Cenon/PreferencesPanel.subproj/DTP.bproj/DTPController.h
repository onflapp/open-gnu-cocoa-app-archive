/*
 * ExportController.h
 *
 * Copyright (C) 2002 by vhf computer GmbH + vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  2002-07-01
 * Modified: 2002-07-01
 */

#ifndef VHF_H_PREFEXPORTCONTROLLER
#define VHF_H_PREFEXPORTCONTROLLER

#include <AppKit/AppKit.h>
#include "../PreferencesMethods.h"

#define SWITCH_COLORTOLAYER	0
#define SWITCH_FILLOBJECTS	1

@interface ExportController:NSObject <PreferencesMethods>
{
    id box;

    id switchMatrix;
}

- (void)set:sender;

@end

#endif // VHF_H_PREFEXPORTCONTROLLER
