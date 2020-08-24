//
//  PXLayerController.m
//  Pixen-XCode
//
//  Created by Joe Osborn on Thu Feb 05 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXLayerController.h"
#import "PXLayerDetailsView.h"
#import "PXCanvas.h"
#import "PXLayer.h"
#import "PXSelectionLayer.h"
#import "SubviewTableViewController.h"

NSString * PXLayerSelectionDidChangeName = @"PXLayerNotificationDidChange";
NSString * PXCanvasLayerSelectionDidChangeName = @"PXCanvasLayerNotificationDidChange";

@implementation PXLayerController

- initWithCanvas:aCanvas
{
  [super init];
  [NSBundle loadNibNamed:@"PXLayerController" owner:self];
  views = [[NSMutableArray alloc] initWithCapacity:8];
  [self selectRow:-1];
  [self setCanvas:aCanvas];
  [tableView registerForDraggedTypes:[NSArray arrayWithObject:@"PXLayerRowPasteType"]];
  return self;
}

- (void)setNextResponder:responder
{
  [super setNextResponder:responder];
  [drawer setNextResponder:self];
  [tableView setNextResponder:self];
}

- (void)mouseMoved:(NSEvent *)event
{
	NSPoint location = [event locationInWindow];
	location.x -= ([drawer contentSize].width + 11);
	location.y += 15;
	id newEvent = [NSEvent mouseEventWithType:[event type] location:location modifierFlags:[event modifierFlags] timestamp:[event timestamp] windowNumber:[event windowNumber] context:[event context] eventNumber:[event eventNumber]+1 clickCount:0 pressure:0];
	[[self nextResponder] mouseMoved:newEvent];
}

- (void)setCanvas:aCanvas
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[aCanvas retain];
	[canvas release];
	canvas = aCanvas;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData:) name:PXCanvasLayersChangedNotificationName object:canvas];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(canvasLayerChanged:) name:PXCanvasLayerSelectionDidChangeName object:canvas];
	[self reloadData:nil];
}

- (void)dealloc
{
	[views release];
	[canvas release];
	[tableViewController release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[tableView setIntercellSpacing:NSMakeSize(0,1)];
	tableViewController = [[SubviewTableViewController controllerWithViewColumn:[tableView tableColumnWithIdentifier:@"details"]] retain];
    [tableViewController setDelegate:self];
}

- undoManager
{
    return [[[NSDocumentController sharedDocumentController] currentDocument] undoManager]; // NOTE: this may not work in all cases
}

- (void)resetViewHiddenStatus
{
	BOOL shouldBeHidden = (([drawer state] == NSDrawerClosedState) || ([drawer state] == NSDrawerClosingState));
	id enumerator = [views objectEnumerator];
	id current;
	while ( (current = [enumerator nextObject] ) )
	{
		[current setHidden:shouldBeHidden];
	}
}

- (NSView *) tableView:(NSTableView *)tableView viewForRow:(int)row
{
	return [views objectAtIndex:[self invertLayerIndex:row]];	
}

- (int)numberOfRowsInTableView:view
{
	return [[canvas layers] count];
}

- (void)reloadData:aNotification
{
  int i, selectedRow;
  [views makeObjectsPerformSelector:@selector(invalidateTimer)];
  if ([tableView selectedRow] == -1) { [self selectRow:0]; }
  selectedRow = [self invertLayerIndex:[tableView selectedRow]];
  for(i = 0; i < [[canvas layers] count]; i++)
    {
      id layer = [[canvas layers] objectAtIndex:i];
      NSLog(@"ploplppoplpop ");
      if([views count] > i)
	{
	  [[views objectAtIndex:i] setLayer:layer];
	}
      else
	{
	  NSLog(@"before NewView");
	  id newView = [[[PXLayerDetailsView alloc] initWithLayer:layer] autorelease];
	  NSLog(@"newView %@",newView);
	  [views addObject:newView];
	}
    }
  [views removeObjectsInRange:NSMakeRange(i, [views count] - i)];
  [tableViewController reloadTableView];
  [self selectRow:[self invertLayerIndex:selectedRow]];
  [self resetViewHiddenStatus];
  [[canvas layers] makeObjectsPerformSelector:@selector(setLayerController:) withObject:self];
}

- (IBAction)nextLayer:sender
{
	[self selectRow:[tableView selectedRow]+1];
	[self selectLayer:[[canvas layers] objectAtIndex:[self invertLayerIndex:[tableView selectedRow]]]];
}

- (IBAction)previousLayer:sender
{
	[self selectRow:[tableView selectedRow]-1];
	[self selectLayer:[[canvas layers] objectAtIndex:[self invertLayerIndex:[tableView selectedRow]]]];
}

- (void)selectRow:(int)index
{
	if ([tableView respondsToSelector:@selector(selectRowIndexes:byExtendingSelection:)])
	{
#ifdef __COCOA__
		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
#else
		if ( index > 0 )
		  {
		    //	  NSLog(@"respondsToSelector selectRowIndexes:  byExtendingSelection");
		    [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		  }
#endif
	}
	else
	{
		[tableView selectRow:index byExtendingSelection:NO];
	}
	[self updateRemoveButtonStatus];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
       NSLog(@" NUMBEROFROWSINTABLEVIEW %@",[NSNumber numberWithBool:[[[canvas layers] objectAtIndex:[self invertLayerIndex:rowIndex]] visible]]);
   if([[aTableColumn identifier] isEqualToString:@"visible"])
     {
       NSLog(@" NUMBEROFROWSINTABLEVIEW %@",[NSNumber numberWithBool:[[[canvas layers] objectAtIndex:[self invertLayerIndex:rowIndex]] visible]]);
       return [NSNumber numberWithBool:[[[canvas layers] objectAtIndex:[self invertLayerIndex:rowIndex]] visible]];
     }
  return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if([[aTableColumn identifier] isEqualToString:@"visible"])
	{
		[[[canvas layers] objectAtIndex:[self invertLayerIndex:rowIndex]] setVisible:[anObject boolValue]];
		[canvas changedInRect:NSMakeRect(0,0,[canvas size].width, [canvas size].height)];
	}
}

- (void)toggle:sender
{
	[drawer toggle:sender];
	[drawer setContentSize:NSMakeSize(233, [drawer contentSize].height)];
	[self resetViewHiddenStatus];
}

- (void)setWindow:aWindow
{
	window = aWindow;
	[drawer setParentWindow:window];
}

- (void)setLayers:layers fromLayers:oldLayers resetSelection:(BOOL)resetSelection
{
	[[[self undoManager] prepareWithInvocationTarget:self] setLayers:oldLayers fromLayers:layers resetSelection:YES];
	[canvas setLayers:layers];
	if (resetSelection)
	{
	 	[self selectRow:0];
	 	[self selectLayer:nil];
	}
}

- (IBAction)addLayer:sender
{
  [[self undoManager] beginUndoGrouping];
  [[self undoManager] setActionName:@"Add Layer"];
  [self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers] resetSelection:YES];		
  [canvas deselect];

  PXLayer *layer = [[PXLayer alloc] initWithName:@"New Layer" size:[canvas size]];
  [layer setLayerController:self];
  [canvas addLayer:layer];
  [self selectRow:0];
  [self selectLayer:nil];
  [[self undoManager] endUndoGrouping];
}

- (void)removeLayerAtCanvasLayersIndex:(unsigned)index
{
  [[self undoManager] beginUndoGrouping];
  [[self undoManager] setActionName:@"Remove Layer"];
  [self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers] resetSelection:NO];
  [canvas deselect];
  [canvas removeLayerAtIndex:index];
  [self selectRow:[self invertLayerIndex:0]];
  [self selectLayer:nil];
  [[self undoManager] endUndoGrouping];
}

- (IBAction)duplicateLayerAtCanvasLayersIndex:(unsigned)index
{
    [[self undoManager] beginUndoGrouping];
    [[self undoManager] setActionName:@"Duplicate Layer"];
    [self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers] resetSelection:NO];
	[canvas insertLayer:[[[[canvas layers] objectAtIndex:index] copy] autorelease] atIndex:index];
    [canvas changedInRect:NSMakeRect(0, 0, [canvas size].width, [canvas size].height)];
    [[self undoManager] endUndoGrouping];
}


- (void)duplicateLayerObject:layer
{
	[self duplicateLayerAtCanvasLayersIndex:[[canvas layers] indexOfObject:layer]];
}

- (IBAction)duplicateLayer:sender
{
	if ([tableView selectedRow] == -1) { return; }
	[self duplicateLayerAtCanvasLayersIndex:[self invertLayerIndex:[tableView selectedRow]]];
}

- (void)removeLayerObject:layer
{
	[self removeLayerAtCanvasLayersIndex:[[canvas layers] indexOfObject:layer]];
}

- (IBAction)removeLayer:sender
{
	if ([tableView selectedRow] == -1) { return; }
	[self removeLayerAtCanvasLayersIndex:[self invertLayerIndex:[tableView selectedRow]]];
}

- (IBAction)selectLayer:sender
{
	if ([tableView selectedRow] == -1) { [self selectRow:0]; }
	int row = [self invertLayerIndex:[tableView selectedRow]];
	if (![[[canvas layers] lastObject] isKindOfClass:[PXSelectionLayer class]])
	{	
	 	[canvas deselect];
	}
	[self selectRow:[self invertLayerIndex:row]];
	[[NSNotificationCenter defaultCenter] postNotificationName:PXLayerSelectionDidChangeName object:self userInfo:[[canvas layers] objectAtIndex:row]];
}

- (void)updateRemoveButtonStatus
{
	if ([self invertLayerIndex:[tableView selectedRow]] == 0) { [removeButton setEnabled:NO]; }
	else { [removeButton setEnabled:YES]; }
}

- (int)invertLayerIndex:(int)anIndex
{
	return [[canvas layers] count] - anIndex - 1;
}

- (void)canvasLayerChanged:notification
{
	[self selectRow:[self invertLayerIndex:[[canvas layers] indexOfObject:[canvas activeLayer]]]];
}

- (void)mergeDownLayerAtCanvasLayersIndex:(unsigned)index
{
	if ([[[canvas layers] objectAtIndex:index] isKindOfClass:[PXSelectionLayer class]]) { [canvas deselect]; return; }
	[[self undoManager] beginUndoGrouping];
	[[self undoManager] setActionName:@"Merge Down"];
	[self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers] resetSelection:YES];
	if (index == 0) { return; }
	[[[canvas layers] objectAtIndex:index-1] compositeUnder:[[canvas layers] objectAtIndex:index] flattenOpacity:YES];
	[canvas removeLayerAtIndex:index];
	if (index >= [[canvas layers] count]) {
		index = 0;
	}
	[self selectRow:[self invertLayerIndex:index]];
	[self selectLayer:[[canvas layers] objectAtIndex:index]];
	[[self undoManager] endUndoGrouping];
}

- (void)mergeDownLayerObject:layer
{
	[self mergeDownLayerAtCanvasLayersIndex:[[canvas layers] indexOfObject:layer]];
}

- (void)mergeDown
{
	[self mergeDownLayerAtCanvasLayersIndex:[self invertLayerIndex:[tableView selectedRow]]];
}

- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	if ([[[canvas layers] objectAtIndex:[self invertLayerIndex:[tableView selectedRow]]] isKindOfClass:[PXSelectionLayer class]]) { return NO; }
	[pboard declareTypes:[NSArray arrayWithObject:@"PXLayerRowPasteType"] owner:self];
	[pboard setString:[NSString stringWithFormat:@"%d", [self invertLayerIndex:[[rows objectAtIndex:0] intValue]]] forType:@"PXLayerRowPasteType"];
	//[pboard setData:[NSKeyedArchiver archivedDataWithRootObject:[[canvas layers] objectAtIndex:[self invertLayerIndex:[tableView selectedRow]]]] forType:@"PXLayerRowPasteType"];
	return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	if (![[[info draggingPasteboard] types] containsObject:@"PXLayerRowPasteType"]) { return NSDragOperationNone; }
	if (operation == NSTableViewDropOn) { [aTableView setDropRow:row dropOperation:NSTableViewDropAbove]; }
	return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	[[self undoManager] beginUndoGrouping];
	[[self undoManager] setActionName:@"Reorder Layer"];
	[self setLayers:[[canvas layers] deepMutableCopy] fromLayers:[canvas layers] resetSelection:YES];
	if (row == [[canvas layers] count]) { row--; }
	[canvas moveLayer:[[canvas layers] objectAtIndex:[[[info draggingPasteboard] stringForType:@"PXLayerRowPasteType"] intValue]] toIndex:[self invertLayerIndex:row]];
	//[canvas moveLayer:[[info draggingPasteboard] dataForType:@"PXLayerRowPasteType"] toIndex:[self invertLayerIndex:row]];
	[self selectRow:[self invertLayerIndex:[[canvas layers] indexOfObject:[canvas activeLayer]]]];
	[[self undoManager] endUndoGrouping];
	return YES;
}

@end
