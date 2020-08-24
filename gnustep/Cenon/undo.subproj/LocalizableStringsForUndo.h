/* LocalizedStringsForUndo.h
 *
 * Copyright (C) 1993-2002 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2002-07-15
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

#ifndef VHF_H_LOCALIZABLESTRINGSFORUNDO
#define VHF_H_LOCALIZABLESTRINGSFORUNDO

#include <Foundation/Foundation.h>

/* Localization strings for the undo subproject */

#define UNDO_OPERATION  NSLocalizedStringFromTable(@"Undo", @"Operations", "The operation of undoing the last thing the user did.")
#define UNDO_SOMETHING_OPERATION  NSLocalizedStringFromTable(@"Undo %@", @"Operations", "The operation of undoing the last %@ operation the user did--all the entries in the Operations and TextOperations .strings files are the %@ of this or Redo.")
#define REDO_OPERATION  NSLocalizedStringFromTable(@"Redo", @"Operations", "The operation of redoing the last thing the user undid.")
#define REDO_SOMETHING_OPERATION  NSLocalizedStringFromTable(@"Redo %@", @"Operations", "The operation of redoing the last %@ operation the user undid--all the entries in the Operations and TextOperations .strings files are the %@ of either this or Undo.")

#endif // VHF_H_LOCALIZABLESTRINGSFORUNDO
