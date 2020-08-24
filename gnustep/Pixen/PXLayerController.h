//
//  PXLayerController.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Thu Feb 05 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SubviewTableViewController.h"

extern NSString * PXLayerSelectionDidChangeName;
extern NSString * PXCanvasLayerSelectionDidChangeName;

@interface PXLayerController : NSResponder <SubviewTableViewControllerDataSourceProtocol> {
	IBOutlet id tableView;
	id canvas;
	IBOutlet id drawer;
	id views;
	id tableViewController;
	id window;
	IBOutlet id removeButton;
}
- initWithCanvas:aCanvas;
- (void)toggle:sender;
- (void)setWindow:aWindow;
- (void)reloadData:aNotification;
- (void)setCanvas:aCanvas;

- (IBAction)addLayer:sender;
- (IBAction)duplicateLayer:sender;
- (void)duplicateLayerObject:layer;
- (IBAction)removeLayer:sender;
- (void)removeLayerObject:layer;
- (IBAction)selectLayer:sender;
- (void)selectRow:(int)index;

- (IBAction)nextLayer:sender;
- (IBAction)previousLayer:sender;

- (void)mergeDown;

- (void)updateRemoveButtonStatus;
- (int)invertLayerIndex:(int)anIndex;
- (void)setLayers:layers fromLayers:oldLayers resetSelection:(BOOL)resetSelection;

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation;

@end
