//
//  PXDocument.h
//  Pixen-XCode
//
// Copyright (c) 2003,2004 Open Sword Group

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, 
//copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
// to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  PXDocument.h
//  Pixen
//
//  Author Joe Osborn 
//  Created on Thu Sep 11 2003.


#import <AppKit/NSDocument.h>

@class PXCanvas;
@class PXCanvasController;

@class NSString;
@class NSTimer;

extern NSString * PXDocumentOpened;
extern NSString * PXDocumentClosed;


@interface PXDocument : NSDocument
{
  PXCanvasController * canvasController;
  PXCanvas * canvas;
  NSTimer *autosaveTimer;
  NSString *autosaveFilename;
  id printableView;
  
  BOOL canSave;
}
- (IBAction)cut: (id) sender;
- (IBAction)copy:(id) sender;
- (IBAction)paste: (id) sender;
- (IBAction)delete: (id) sender;
- (IBAction)selectAll: (id)sender;
- (IBAction)selectNone: (id)sender;
- (id)canvas; // -(PXCanvas *) canvas;

- (void)autosave:(NSTimer *)timer;

- (void)setCanSave:(BOOL)canSave;

@end
