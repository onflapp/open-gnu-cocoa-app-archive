/* PXPaletteSwitcher */

#import <AppKit/AppKit.h>

@interface PXPaletteSwitcher : NSObject
{
  IBOutlet id delegate;
  IBOutlet id paletteChooser;
  id userPalettes, defaultPalettes;
  id palette;
  id namePrompter;
  id canvas;
	
  id gradientBuilder;
@private
  id _delegate;

}

+ defaultPalettes;

-(id) init;

- (void) populateMenuForCanvas:(id)aCanvas;
- (unsigned)indexOfPalette:(id) aPalette;
- (void)addNewPalette:(id) newPalette withName:(NSString *)name replacingPaletteAtIndex:(unsigned)index;


- (void)dealloc;


- (void)setDelegate:(id) aDelegate;

- (void)selectPaletteNamed:aName;
- (void)selectDefaultPalette;

- (IBAction)deleteCurrentPalette: (id) sender;
- (IBAction)makeGradient:(id)sender;
- (IBAction)selectPalette: (id) sender;
- (IBAction)saveCurrentPalette:(id) sender;
- (IBAction)setCurrentPaletteAsDefault:(id) sender;




@end


@interface PXPaletteSwitcher ( NamePrompterDelegate )
- (void)prompter:aPrompter didFinishWithName:name context:contextObject;
- (void)prompter:aPrompter didCancelWithContext:contextObject;
@end

