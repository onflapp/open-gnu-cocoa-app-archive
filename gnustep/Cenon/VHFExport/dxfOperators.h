/*
 * sv_dxf_a.h
 *
 * Copyright 1993-2002 by vhf computer GmbH + vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1993-06-08
 * modified: 2002-06-29
 *
 * common defines for dxf import and export
 */

#ifndef VHF_H_DXFOPERATORS
#define VHF_H_DXFOPERATORS

/* resolution in pixel per inch */
#define	RES		25.4

/* the following characters may apear as digits in a coordinate */
#define DIGITS		@".+-0123456789"

#define NOP		@" \t\r\n"

/* names of groupes */
#define NAMHEADER	@"HEADER"
#define NAMLTYPE	@"LTYPE"
#define NAMLAYER	@"LAYER"
#define NAMTABLES	@"TABLES"
#define NAMBLOCKS	@"BLOCKS"
#define NAMENTITIES	@"ENTITIES"
#define NAMOBJECTS	@"OBJECTS"

/* names for groups */
#define GRPEXTMIN	@"$EXTMIN"
#define GRPEXTMAX	@"$EXTMAX"
#define GRPBLOCK	@"BLOCK"
#define GRPENDBLOCK	@"ENDBLK"
#define GRPSECTION	@"SECTION"
#define GRPENDSEC	@"ENDSEC"
#define GRPTABLE	@"TABLE"
#define GRPENDTAB	@"ENDTAB"
#define GRPLTYPE	@"LTYPE"
#define GRPLAYER	@"LAYER"
#define GRPLINE		@"LINE"
#define GRPLWPOLYLINE	@"LWPOLYLINE"
#define GRPPOLYLINE	@"POLYLINE"
#define GRPVERTEX	@"VERTEX"
#define GRPSEQEND	@"SEQEND"
#define GRPSOLID	@"SOLID"
#define GRPCIRCLE	@"CIRCLE"
#define GRPARC		@"ARC"
#define GRPTEXT		@"TEXT"
#define GRPMTEXT	@"MTEXT"
#define GRPINSERT	@"INSERT"
#define GRPIDBUFFER	@"IDBUFFER"
#define GRPEOF		@"EOF"

/* codes for groups */
#define IDGROUP		@"0"
#define IDTEXT		@"1"
#define IDNAME		@"2"
#define IDDESCRIPT	@"3"
#define IDLTYPE		@"6"
#define IDLAYER		@"8"
#define IDX0		@"10"
#define IDY0		@"20"
#define IDX1		@"11"
#define IDY1		@"21"
#define IDX2		@"12"
#define IDY2		@"22"
#define IDX3		@"13"
#define IDY3		@"23"
#define IDRADIUS	@"40"
#define IDBEGWIDTH	@"40"
#define IDSUMLEN	@"40"
#define IDHEIGHT	@"40"
#define IDENDWIDTH	@"41"
#define IDA		@"42"
#define IDBEGANGLE	@"50"
#define IDENDANGLE	@"51"
#define IDCOLOR		@"62"
#define IDMORE		@"66"
#define IDFLAGS		@"70"
#define IDGENFLAGS	@"71"
#define IDADJUST	@"72"
#define IDNUMGRP	@"73"

/* codes for groups */
#define ID_GROUP	0
#define ID_TEXT		1
#define ID_NAME		2
#define ID_DESCRIPT	3
#define ID_HANDLE	5
#define ID_LTYPE	6
#define ID_STYLE	7
#define ID_LAYER	8
#define ID_VARNAME	9
#define ID_X0		10
#define ID_Y0		20
#define ID_X1		11
#define ID_Y1		21
#define ID_X2		12
#define ID_Y2		22
#define ID_X3		13
#define ID_Y3		23
#define ID_WIDTH	40
#define ID_ENDWIDTH	41
#define ID_A		42
#define ID_CONSTWIDTH	43
#define ID_BEGANGLE	50
#define ID_ENDANGLE	51
#define ID_COLOR	62
#define ID_MORE		66
#define ID_FLAGS	70
#define ID_GENFLAGS	71
#define ID_ADJUST	72
#define ID_NUMGRP	73
#define ID_REFENTITY	330

#endif // VHF_H_DXFOPERATORS
