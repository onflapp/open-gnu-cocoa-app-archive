/* dxfOperators.h
 * common defines for dxf import
 *
 * Copyright (C) 1993-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1993-06-08
 * modified: 2011-04-04 (3DLINE, 3DFACE added, IDZ0-IDZ3 addded)
 *           2009-02-06 (Extrusion Direction ID_EXT_X,Y,Z added)
 *
 * This file is part of the vhf Import Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_DXFOPERATORS
#define VHF_H_DXFOPERATORS

/* resolution in pixel per inch */
#define	RES		25.4

/* the following characters may apear as digits in a coordinate */
#define DIGITS		@".+-0123456789"

#define NOP		@" \t\r\n"

/* names of groupes */
#define NAMHEADER       @"HEADER"
#define NAMLTYPE        @"LTYPE"
#define NAMLAYER        @"LAYER"
#define NAMTABLES       @"TABLES"
#define NAMBLOCKS       @"BLOCKS"
#define NAMENTITIES     @"ENTITIES"
#define NAMOBJECTS      @"OBJECTS"

/* names for groups */
#define GRPEXTMIN       @"$EXTMIN"
#define GRPEXTMAX       @"$EXTMAX"
#define GRPBLOCK        @"BLOCK"
#define GRPENDBLOCK     @"ENDBLK"
#define GRPSECTION      @"SECTION"
#define GRPENDSEC       @"ENDSEC"
#define GRPTABLE        @"TABLE"
#define GRPENDTAB       @"ENDTAB"
#define GRPLTYPE        @"LTYPE"
#define GRPLAYER        @"LAYER"
#define GRPLINE         @"LINE"
#define GRPLWPOLYLINE   @"LWPOLYLINE"
#define GRPPOLYLINE     @"POLYLINE"
#define GRPVERTEX       @"VERTEX"
#define GRPSEQEND       @"SEQEND"
#define GRPSOLID        @"SOLID"
#define GRPSPLINE       @"SPLINE"       // TODO
#define GRPCIRCLE       @"CIRCLE"
#define GRPARC          @"ARC"
#define GRPTEXT         @"TEXT"
#define GRPMTEXT        @"MTEXT"
#define GRPINSERT       @"INSERT"
#define GRP3DLINE       @"3DLINE"
#define GRP3DFACE       @"3DFACE"
#define GRPIDBUFFER     @"IDBUFFER"
#define GRPEOF          @"EOF"

/* codes for groups */
#define IDGROUP         @"0"
#define IDTEXT          @"1"
#define IDNAME          @"2"
#define IDDESCRIPT      @"3"
#define IDLTYPE         @"6"
#define IDLAYER         @"8"
//#define IDX0            @"10"
//#define IDY0            @"20"
//#define IDZ0            @"30"
//#define IDX1            @"11"
//#define IDY1            @"21"
//#define IDZ1            @"31"
//#define IDX2            @"12"
//#define IDY2            @"22"
//#define IDZ2            @"32"
//#define IDX3            @"13"
//#define IDY3            @"23"
//#define IDZ3            @"33"
#define IDRADIUS        @"40"
#define IDBEGWIDTH      @"40"
#define IDSUMLEN        @"40"
#define IDHEIGHT        @"40"
#define IDENDWIDTH      @"41"
#define IDA             @"42"
#define IDBEGANGLE      @"50"
#define IDENDANGLE      @"51"
#define IDCOLOR         @"62"
#define IDMORE          @"66"
#define IDFLAGS         @"70"
#define IDGENFLAGS      @"71"
#define IDADJUST        @"72"
#define IDNUMGRP        @"73"

/* codes for groups */
#define ID_GROUP        0
#define ID_TEXT         1
#define ID_NAME         2
#define ID_DESCRIPT     3
#define ID_HANDLE       5
#define ID_LTYPE        6
#define ID_STYLE        7
#define ID_LAYER        8
#define ID_VARNAME      9
#define ID_X0           10
#define ID_Y0           20
#define ID_Z0           30
#define ID_X1           11
#define ID_Y1           21
#define ID_Z1           31
#define ID_X2           12
#define ID_Y2           22
#define ID_Z2           32
#define ID_X3           13
#define ID_Y3           23
#define ID_Z3           33
#define ID_WIDTH        40
#define ID_ENDWIDTH     41
#define ID_A            42
#define ID_CONSTWIDTH   43
#define ID_BEGANGLE     50
#define ID_ENDANGLE     51
#define ID_COLOR        62
#define ID_MORE         66
#define ID_FLAGS        70
#define ID_GENFLAGS     71
#define ID_ADJUST       72
#define ID_NUMGRP       73
#define ID_EXT_X        210
#define ID_EXT_Y        220
#define ID_EXT_Z        230
#define ID_REFENTITY    330

#endif // VHF_H_DXFOPERATORS
