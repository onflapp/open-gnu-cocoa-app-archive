/* messages.h
 * common project messages
 *
 * Copyright (C) 1993-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1993-08-19
 * modified: 2011-07-05 (PSIMPORT_INSTALLGS_STRING added)
 *           2011-03-30
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

#ifndef VHF_H_MESSAGES
#define VHF_H_MESSAGES

#define HIDE_GRID NSLocalizedString(@"Turn Grid Off", NULL)
#define SHOW_GRID NSLocalizedString(@"Turn Grid On", NULL)
#define HIDE_DIRECTION NSLocalizedString(@"Hide Directions", NULL)
#define SHOW_DIRECTION NSLocalizedString(@"Show Directions", NULL)
#define HIDE_COORDS NSLocalizedString(@"Hide Coordinates", NULL)
#define SHOW_COORDS NSLocalizedString(@"Show Coordinates", NULL)
#define HIDE_MOVES NSLocalizedString(@"Hide Moves", NULL)			// -> CAM
#define SHOW_MOVES NSLocalizedString(@"Show Moves", NULL)			// -> CAM
#define HIDE_TOOLDIAMETER NSLocalizedString(@"Hide Tool Diameter", NULL)	// -> CAM
#define SHOW_TOOLDIAMETER NSLocalizedString(@"Show Tool Diameter", NULL)	// -> CAM

#define OPEN_ERROR NSLocalizedString(@"I/O error.  Can't open file '%@'.", "Message in alert given to user when he tries to open a draw document and there is an I/O error.  This usually happens when the document being opened is not really a draw document but somehow got renamed to have the .draw extension.")
#define CANT_CREATE_BACKUP NSLocalizedString(@"Can't create backup file. File not saved!", "Message indicating that a backup file could not be created during save.")
#define DIR_NOT_WRITABLE NSLocalizedString(@"Directory is not writeable.", "Message indicating that the directory the user is trying to save to is not writable.")
#define CANT_SAVE NSLocalizedString(@"Can't save file.", "This alert appears when the user has asked to save his file somewhere, but Cenon was unable to create that file.  This can occur for many reasons, the most common of which is that the file or directory is not writable.")
#define EXPORTLOCK_STRING NSLocalizedString(@"This document is not supposed to be exported\nPlease respect the efforts of the author.", "This alert appears when the user has asked to save his file, but it is protected.")

/* In these next few items the space in the name is intentional, to distinguish them from the same strings which occur on buttons */
#define SAVE_TITLE NSLocalizedString(@"Save ", "Title of alerts which come up during save.")
#define OPEN_TITLE NSLocalizedString(@"Open ", "Title of alerts which come up during open.")
#define REVERT_TITLE NSLocalizedString(@"Revert ", "This is the title of the alert which asks the user if he is sure he wants to revert a document he has edited back to its last-saved state.")
#define QUIT_TITLE NSLocalizedString(@"Quit ", "Title of alert which comes up when exiting the application.")


#define OK_STRING NSLocalizedString(@"OK", "Default response in alert panel")
#define CANCEL_STRING NSLocalizedString(@"Cancel", "Button choice allowing user to cancel")
#define DELETE_STRING NSLocalizedString(@"Delete", "Button choice allowing user to remove something")
#define MODIFY_STRING NSLocalizedString(@"Modify", "Button choice allowing user to modify something")
#define KEEP_STRING NSLocalizedString(@"Keep", "Button choice allowing user to keep something")
#define SKIP_STRING NSLocalizedString(@"Skip", NULL)


#define SELECT2FORJOIN_STRING NSLocalizedString(@"Select two objects for joining!", NULL)

#define UNTITLED_STRING NSLocalizedString(@"UNTITLED", "The name of a document which the user has not yet given a name to.")

#define CANTSTARTMODUL NSLocalizedString(@"Could not start module.", "The specified program could not be started")
#define CANTOPENFILE_STRING NSLocalizedString(@"Could not open file.", "The user-specified file could not be opened")
#define CANTLOADFILE_STRING NSLocalizedString(@"Could not open file\n%@.", "The user-specified file could not be opened")
#define CANTLOADFILEDEFAULT_STRING NSLocalizedString(@"Could not open file\n%@. \nUsing Default.", NULL)
#define UNSAVEDDOCS_STRING NSLocalizedString(@"You have unsaved documents.", "Message given to user when he tries to quit the application without saving all of his documents.")
#define REVIEW_STRING NSLocalizedString(@"Review Unsaved", "Choice (on a button) given to user which allows him/her to review all unsaved documents if he/she quits the application without saving them all first.")
#define QUITANYWAY_STRING NSLocalizedString(@"Quit Anyway", "Choice (on a button) given to user which allows him/her to quit the application even though there are unsaved documents.")
#define QUIT_STRING NSLocalizedString(@"Quit", "The operation of exiting the application.")
#define	DEFAULTSTRING	"Default"
#define CANTSAVEFILE_STRING  NSLocalizedString(@"Can't save file.", NULL)   // CANT_SAVE is used
#define CANTWRITEFILE_STRING NSLocalizedString(@"Can't write file.", "Document could not be saved")   // CANT_SAVE is used
#define NULLGRAPHIC_STRING NSLocalizedString(@"Graphic has zero size.", "")
#define BAD_IMAGE @"Unable to import that image into Cenon."
#define SAVECHANGES_STRING NSLocalizedString(@"%@ has changes. Save them?", "Question asked of user when he/she tries to close a window containing an unsaved document.  The %@ is the name of the document.")
#define CLOSEWINDOW_STRING NSLocalizedString(@"Close", "Request to close window containing unsaved document from menu or close button.")
#define SAVE_STRING NSLocalizedString(@"Save", "Button choice which allows the user to save the document.")
#define REVERT_STRING NSLocalizedString(@"Do you want to revert to: %@ ?", NULL)
#define DONTSAVE_STRING NSLocalizedString(@"Don't Save", "Button choice which allows the user to abort the save of a document which is being closed.")
#define BAD_MARGINS NSLocalizedString(@"The margins or paper size specified are invalid.", NULL)
#define CALCULATE_STRING NSLocalizedString(@"The contour will be calculated know! You may want to stop this operation to calculate on a later time.", NULL)
#define CALC_STRING NSLocalizedString(@"Calculate", NULL)

#define ABORT_STRING NSLocalizedString(@"Abort", "Button choice allowing user to abort")

#define MM_STRING NSLocalizedString(@"mm", NULL)
#define INCH_STRING NSLocalizedString(@"inch", NULL)
#define POINT_STRING NSLocalizedString(@"pt", NULL)

#define NAMEINUSE_STRING NSLocalizedString(@"Name '%@' allready in use!", NULL)
#define CANTFINDLIB_STRING NSLocalizedString(@"You need to install the Cenon Library!", NULL)

/* layer messages */
#define REALLYDELETELAYER_STRING  NSLocalizedString(@"Do you really want to remove layer '%@' ?", NULL)
#define LAYERTYPEINUSE_STRING NSLocalizedString(@"Only one layer of this kind allowed!", NULL)
#define LAYERONLYFORRECTANGLE_STRING NSLocalizedString(@"Only a single rectangle allowed on leveling layer!", "appears, if too much elements are on leveling layer")
#define LAYERCLIPPING_STRING NSLocalizedString(@"Clipping", "The name of the clipping layer")
#define LAYERNOTEDITABLE_STRING NSLocalizedString(@"Layer is not editable!", "User tried import on selected layer")

/* Preferences Panel
 */

/* import messages */
#define DXFSIZE_STRING NSLocalizedString(@"DXF File exceeds maximum size!\nPlease increase the DXF resolution in the Preferences.", NULL)
#define DINLAYERNAME_STRING NSLocalizedString(@"Bore %.1f mm", NULL)
#define DXFIMPORTOUTOFBOUNDS_STRING NSLocalizedString(@"Some Objects are exceeding drawing bounds!", NULL)
#define IMPORTTONOTEXISTINGLAYER_STRING NSLocalizedString(@"No layer available with name/color '%@'!", NULL)
#define CREATELAYER_STRING NSLocalizedString(@"Create Layer", NULL)
#define PSIMPORT_INSTALLGS_STRING NSLocalizedString(@"You need to install GhostScript (gs) to import PDF or PostScript!", NULL)

#endif // VHF_H_MESSAGES
