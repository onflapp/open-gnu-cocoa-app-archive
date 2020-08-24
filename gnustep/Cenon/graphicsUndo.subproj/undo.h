/* undo.h
 *
 * Copyright (C) 1993-2011 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993
 * modified: 2011-05-28 (ExcludeGraphicsChange added)
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

#ifndef VHF_H_UNDO
#define VHF_H_UNDO

#include <string.h>
#include <AppKit/AppKit.h>

#include "../undo.subproj/Change.h"
#include "../undo.subproj/ChangeManager.h"

#include "../propertyList.h"
#include "../Graphics.h"
#include "../DocView.h"
#include "../Inspectors.h"
#include "../Document.h"
#include "../App.h"

#include "ChangeDetail.h"

#include "CreateGraphicsChange.h"
#include "SplitGraphicsChange.h"
//#include "StartEditingGraphicsChange.h"
#include "EndEditingGraphicsChange.h"
#include "UngroupGraphicsChange.h"

#include "GraphicsChange.h"
#include "ContourGraphicsChange.h"
# include "JoinGraphicsChange.h"
# include "PunchGraphicsChange.h"
#include "ReorderGraphicsChange.h"
# include "BringToFrontGraphicsChange.h"
# include "SendToBackGraphicsChange.h"
#include "DeleteGraphicsChange.h"
# include "CutGraphicsChange.h"
#include "DragPointGraphicsChange.h"
#include "GroupGraphicsChange.h"
#include "PasteGraphicsChange.h"

#include "SimpleGraphicsChange.h"
#include "AlignGraphicsChange.h"
#include "MoveLayerGraphicsChange.h"
#include "LabelGraphicsChange.h"
//#include "NameGraphicsChange.h" // DEPRECATED
#include "AngleGraphicsChange.h"
#include "ColorGraphicsChange.h"
#include "DimensionsGraphicsChange.h"
#include "FillGraphicsChange.h"
#include "ExcludeGraphicsChange.h"
#include "LockGraphicsChange.h"
#include "MirrorGraphicsChange.h"
#include "MixGraphicsChange.h"
#include "MoveGraphicsChange.h"
#include "MovePointGraphicsChange.h"
#include "RadiusGraphicsChange.h"
#include "RotateGraphicsChange.h"
#include "ScaleGraphicsChange.h"
#include "WidthGraphicsChange.h"
#include "LengthGraphicsChange.h"
#include "StepWidthGraphicsChange.h"
#include "RadialCenterGraphicsChange.h"
#include "AddPointGraphicsChange.h"
#include "RemovePointGraphicsChange.h"

//#include "PerformVTextsChange.h"
#include "LocalizableStringsForGraphicsUndo.h"

#endif // VHF_H_UNDO
