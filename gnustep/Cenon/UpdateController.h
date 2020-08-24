/* UpdateController.m
 * Checking for Updates...
 *
 * Copyright 2010-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2010-05-27
 * modified: 2011-02-14
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
 * eMail: service@vhf.de
 * http://www.vhf-interservice.com
 */

#ifndef VHF_H_UPDATECONTROLLER
#define VHF_H_UPDATECONTROLLER

#include <AppKit/AppKit.h>

@interface UpdateController: NSObject
{
    id  panel;
    id  titleLabel;     // title
    id  infoLabel;      // info text
    id  tableView;      // list of updates
    id  textView;       // news
    id  installButton;
    id  skipButton;

    id  progressPanel;
    id  progressTitleText;
    id  progressIndicator;
    id  progressNameText;
    id  progressSizeText;

    BOOL            isAutoCheck;            // whether check is started automatically
    BOOL            checking;
    NSURLConnection *urlConnection;         // used to be able to cancel a connection
    NSMutableData   *connectionData;        // data from cgi-script
    NSDictionary    *updateDict;            // update dict
    id              tableData;              // data source for table view
    NSMutableArray  *downloadFiles;         // files to download
    NSURLDownload   *pkgDownload;
    NSString        *pkgPath;
    int             fileCnt;                // number of files to download
    long long       sizeTotal, sizeDownl;   // expected and downloaded size
}

+ (UpdateController*)sharedInstance;
- (void)checkForUpdates:sender;

- (void)install:sender;
- (void)skip:sender;
- (void)cancel:sender;

- (void)cancelDownload:sender;

@end

#endif // VHF_H_UPDATECONTROLLER
