/* PSInfo.m
 * Info panel for project settings
 *
 * Copyright (C) 2002-2005 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  2002-11-23
 * Modified: 2003-06-26
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

#include "ProjectSettings.h"
#include "PSInfo.h"
#include "../App.h"
#include "../Document.h"
//#include "../locations.h"
//#include "../messages.h"


@interface PSInfo(PrivateMethods)
@end

@implementation PSInfo

- (id)init
{
    [super init];

    if ( ![NSBundle loadNibNamed:@"PSInfo" owner:self] )
    {   NSLog(@"Cannot load 'PSInfo' interface file");
        return nil;
    }

    [self update:self];

    return self;
}

- (void)update:sender
{   id          doc = ([sender isKindOfClass:[Document class]]) ? sender : [(App*)NSApp currentDocument];
    NSString    *string;

    string = ([doc docVersion])   ? [doc docVersion]   : @"";
    [versionForm setStringValue:string];
    string = ([doc docAuthor])    ? [doc docAuthor]    : @"";
    [authorForm setStringValue:string];
    string = ([doc docCopyright]) ? [doc docCopyright] : @"";
    [copyrightForm setStringValue:string];
    string = ([doc docComment])   ? [doc docComment]   : @"";
    [commentText setString:string];
}

- (NSString*)name
{
    return [[view window] title];
}

- (NSView*)view
{
    return view;
}

- (void)set:sender
{   id		doc = ([sender isKindOfClass:[Document class]]) ? sender : [(App*)NSApp currentDocument];

    if (!doc)
        return;

    [doc setDocVersion:[versionForm stringValue]];
    [doc setDocAuthor:[authorForm stringValue]];
    [doc setDocCopyright:[copyrightForm stringValue]];
    [doc setDocComment:[commentText string]];
}


@end
