//
//  PXToolPropertiesController.h
//  Pixen-XCode
//
// Copyright (c) 2004 Open Sword Group

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, 
//copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
// to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//  Author : Andy Matuschak on Fri Mar 12 2004.

// This class manage the properties tool Panel 
//(TODO : more Comment)
// Fabien

#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class NSPanel;

@interface PXToolPropertiesController : NSObject
{
  IBOutlet NSPanel *panel;
}

//Double-ton
+ (id)leftToolPropertiesController;
+ (id)rightToolPropertiesController;

//Use to change the property view
- (void)setPropertiesView:(id) propertiesView;
//Accessor
-(NSPanel *) propertiesPanel;

@end


