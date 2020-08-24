#import <Foundation/Foundation.h>

/* Localization strings for the undo subproject */

#define UNDO_OPERATION  NSLocalizedStringFromTable(@"&Undo", @"Operations", "The operation of undoing the last thing the user did.")
#define UNDO_SOMETHING_OPERATION  NSLocalizedStringFromTable(@"&Undo %@", @"Operations", "The operation of undoing the last %@ operation the user did--all the entries in the Operations and TextOperations .strings files are the %@ of this or Redo.")
#define REDO_OPERATION  NSLocalizedStringFromTable(@"&Redo", @"Operations", "The operation of redoing the last thing the user undid.")
#define REDO_SOMETHING_OPERATION  NSLocalizedStringFromTable(@"&Redo %@", @"Operations", "The operation of redoing the last %@ operation the user undid--all the entries in the Operations and TextOperations .strings files are the %@ of either this or Undo.")


