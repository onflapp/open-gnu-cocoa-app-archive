/* dxfColorTable.h
 * DXF color table
 *
 * Copyright (C) 1996-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1996-05-01
 * modified: 2002-06-29
 *
 * This file is part of the vhf Import and Export Library.
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

#ifndef VHF_H_DXFCOLORTABLE
#define VHF_H_DXFCOLORTABLE

#ifndef DXFColor
typedef struct _DXFColor
{	float	r, g, b;
}DXFColor;
#endif

/* color codes */
static DXFColor colorTable[] = 
{
	{1,     0,    0},	/*   1 red */
	{1,     1,    0},	/*   2 yellow */
	{0,     1,    0},	/*   3 green */
	{0,     1,    1},	/*   4 cyan */
	{0,     0,    1},	/*   5 blue */
	{1,     0,    1},	/*   6 magenta */
	{0,     0,    0},	/*   8 white */
	{1,     1,    1},	/*   7 black */
	{1,     0,    0},	/*   9 red */

	{1,     0,     0},	/*    10 */
	{1,     0.5,   0.5},	/*    11 */
	{0.8,   0,     0},	/*    12 */
	{0.8,   0.4,   0.4},	/*    13 */
	{0.6,   0,     0},	/*    14 */
	{0.6,   0.3,   0.3},	/*    15 */
	{0.4,   0,     0},	/*    16 */
	{0.4,   0.2,   0.2},	/*    17 */
	{0.2,   0,     0},	/*    18 */
	{0.2,   0.1,   0.1},	/*    19 */

	{1,     0.25,  0},	/*    20 */
	{1,     0.625, 0.5},	/*    21 */
	{0.8,   0.2,   0},	/*    22 */
	{0.8,   0.5,   0.4},	/*    23 */
	{0.6,   0.15,  0},	/*    24 */
	{0.6,   0.375, 0.3},	/*    25 */
	{0.4,   0.1,   0},	/*    26 */
	{0.4,   0.25,  0.2},	/*    27 */
	{0.2,   0.05,  0},	/*    28 */
	{0.2,   0.125, 0.1},	/*    29 */

	{1,     0.5,   0},	/*    30 */
	{1,     0.75,  0.5},	/*    31 */
	{0.8,   0.4,   0},	/*    32 */
	{0.8,   0.6,   0.4},	/*    33 */
	{0.6,   0.3,   0},	/*    34 */
	{0.6,   0.45,  0.3},	/*    35 */
	{0.4,   0.2,   0},	/*    36 */
	{0.4,   0.3,   0.2},	/*    37 */
	{0.2,   0.1,   0},	/*    38 */
	{0.2,   0.15,  0.1},	/*    39 */

	{1,     0.75,  0},	/*    40 */
	{1,     0.875, 0.5},	/*    41 */
	{0.8,   0.6,   0},	/*    42 */
	{0.8,   0.7,   0.4},	/*    43 */
	{0.6,   0.45,  0},	/*    44 */
	{0.6,   0.525, 0.3},	/*    45 */
	{0.4,   0.3,   0},	/*    46 */
	{0.4,   0.35,  0.2},	/*    47 */
	{0.2,   0.15,  0},	/*    48 */
	{0.2,   0.175, 0.1},	/*    49 */

	{1,     1,     0},	/*    50 */
	{1,     1,     0.5},	/*    51 */
	{0.8,   0.8,   0},	/*    52 */
	{0.8,   0.8,   0.4},	/*    53 */
	{0.6,   0.6,   0},	/*    54 */
	{0.6,   0.6,   0.3},	/*    55 */
	{0.4,   0.4,   0},	/*    56 */
	{0.4,   0.4,   0.2},	/*    57 */
	{0.2,   0.2,   0},	/*    58 */
	{0.2,   0.2,   0.1},	/*    59 */

	{0.75,  1,     0},	/*    60 */
	{0.875, 1,     0.5},	/*    61 */
	{0.6,   0.8,   0},	/*    62 */
	{0.7,   0.8,   0.4},	/*    63 */
	{0.45,  0.6,   0},	/*    64 */
	{0.525, 0.6,   0.3},	/*    65 */
	{0.3,   0.4,   0},	/*    66 */
	{0.35,  0.4,   0.2},	/*    67 */
	{0.15,  0.2,   0},	/*    68 */
	{0.175, 0.2,   0.1},	/*    69 */

	{0.5,   1,     0},	/*    70 */
	{0.75,  1,     0.5},	/*    71 */
	{0.4,   0.8,   0},	/*    72 */
	{0.6,   0.8,   0.4},	/*    73 */
	{0.3,   0.6,   0},	/*    74 */
	{0.45,  0.6,   0.3},	/*    75 */
	{0.2,   0.4,   0},	/*    76 */
	{0.3,   0.4,   0.2},	/*    77 */
	{0.1,   0.2,   0},	/*    78 */
	{0.15,  0.2,   0.1},	/*    79 */

	{0.25,  1,     0},	/*    80 */
	{0.625, 1,     0.5},	/*    81 */
	{0.2,   0.8,   0},	/*    82 */
	{0.5,   0.8,   0.4},	/*    83 */
	{0.15,  0.6,   0},	/*    84 */
	{0.375, 0.6,   0.3},	/*    85 */
	{0.1,   0.4,   0},	/*    86 */
	{0.25,  0.4,   0.2},	/*    87 */
	{0.05,  0.2,   0},	/*    88 */
	{0.125, 0.2,   0.1},	/*    89 */

	{0,     1,     0},	/*    90 */
	{0.5,   1,     0.5},	/*    91 */
	{0,     0.8,   0},	/*    92 */
	{0.4,   0.8,   0.4},	/*    93 */
	{0,     0.6,   0},	/*    94 */
	{0.3,   0.6,   0.3},	/*    95 */
	{0,     0.4,   0},	/*    96 */
	{0.2,   0.4,   0.2},	/*    97 */
	{0,     0.2,   0},	/*    98 */
	{0.1,   0.2,   0.1},	/*    99 */

	{0,     1,     0.25},	/*   100 */
	{0.5,   1,     0.625},	/*   101 */
	{0,     0.8,   0.2},	/*   102 */
	{0.4,   0.8,   0.5},	/*   103 */
	{0,     0.6,   0.15},	/*   104 */
	{0.3,   0.6,   0.375},	/*   105 */
	{0,     0.4,   0.1},	/*   106 */
	{0.2,   0.4,   0.25},	/*   107 */
	{0,     0.2,   0.05},	/*   108 */
	{0.1,   0.2,   0.125},	/*   109 */

	{0,     1,     0.5},	/*   110 */
	{0.5,   1,     0.75},	/*   111 */
	{0,     0.8,   0.4},	/*   112 */
	{0.4,   0.8,   0.6},	/*   113 */
	{0,     0.6,   0.3},	/*   114 */
	{0.3,   0.6,   0.45},	/*   115 */
	{0,     0.4,   0.2},	/*   116 */
	{0.2,   0.4,   0.3},	/*   117 */
	{0,     0.2,   0.1},	/*   118 */
	{0.1,   0.2,   0.15},	/*   119 */

	{0,     1,     0.75},	/*   120 */
	{0.5,   1,     0.875},	/*   121 */
	{0,     0.8,   0.6},	/*   122 */
	{0.4,   0.8,   0.7},	/*   123 */
	{0,     0.6,   0.45},	/*   124 */
	{0.3,   0.6,   0.525},	/*   125 */
	{0,     0.4,   0.3},	/*   126 */
	{0.2,   0.4,   0.35},	/*   127 */
	{0,     0.2,   0.15},	/*   128 */
	{0.1,   0.2,   0.175},	/*   129 */

	{0,     1,     0.75},	/*   130 */
	{0.5,   1,     1},	/*   131 */
	{0,     0.8,   0.8},	/*   132 */
	{0.4,   0.8,   0.8},	/*   133 */
	{0,     0.6,   0.6},	/*   134 */
	{0.3,   0.6,   0.6},	/*   135 */
	{0,     0.4,   0.4},	/*   136 */
	{0.2,   0.4,   0.4},	/*   137 */
	{0,     0.2,   0.2},	/*   138 */
	{0.1,   0.2,   0.2},	/*   139 */

	{0,     0.75,  1},	/*   140 */
	{0.5,   0.875, 1},	/*   141 */
	{0,     0.6,   0.8},	/*   142 */
	{0.4,   0.7,   0.8},	/*   143 */
	{0,     0.45,  0.6},	/*   144 */
	{0.3,   0.525, 0.6},	/*   145 */
	{0,     0.3,   0.4},	/*   146 */
	{0.2,   0.35,  0.4},	/*   147 */
	{0,     0.15,  0.2},	/*   148 */
	{0.1,   0.175, 0.2},	/*   149 */

	{0,     0.5,   1},	/*   150 */
	{0.5,   0.75,  1},	/*   151 */
	{0,     0.4,   0.8},	/*   152 */
	{0.4,   0.6,   0.8},	/*   153 */
	{0,     0.3,   0.6},	/*   154 */
	{0.3,   0.45,  0.6},	/*   155 */
	{0,     0.2,   0.4},	/*   156 */
	{0.2,   0.3,   0.4},	/*   157 */
	{0,     0.1,   0.2},	/*   158 */
	{0.1,   0.15,  0.2},	/*   159 */

	{0,     0.25,   1},	/*   160 */
	{0.5,   0.625, 1},	/*   161 */
	{0,     0.2,   0.8},	/*   162 */
	{0.4,   0.5,   0.8},	/*   163 */
	{0,     0.15,  0.6},	/*   164 */
	{0.3,   0.375, 0.6},	/*   165 */
	{0,     0.1,   0.4},	/*   166 */
	{0.2,   0.25,  0.4},	/*   167 */
	{0,     0.05,  0.2},	/*   168 */
	{0.1,   0.125, 0.2},	/*   169 */

	{0,     0,     1},	/*   170 */
	{0.5,   0.5,   1},	/*   171 */
	{0,     0,     0.8},	/*   172 */
	{0.4,   0.4,   0.8},	/*   173 */
	{0,     0,     0.6},	/*   174 */
	{0.3,   0.3,   0.6},	/*   175 */
	{0,     0,     0.4},	/*   176 */
	{0.2,   0.2,   0.4},	/*   177 */
	{0,     0,     0.2},	/*   178 */
	{0.1,   0.1,   0.2},	/*   179 */

	{0.25,  0,     1},	/*   180 */
	{0.625, 0.5,   1},	/*   181 */
	{0.2,   0,     0.8},	/*   182 */
	{0.5,   0.4,   0.8},	/*   183 */
	{0.15,  0,     0.6},	/*   184 */
	{0.375, 0.3,   0.6},	/*   185 */
	{0.1,   0,     0.4},	/*   186 */
	{0.25,  0.2,   0.4},	/*   187 */
	{0.05,  0,     0.2},	/*   188 */
	{0.125, 0.1,   0.2},	/*   189 */

	{0.5,   0,     1},	/*   190 */
	{0.75,  0.5,   1},	/*   191 */
	{0.4,   0,     0.8},	/*   192 */
	{0.6,   0.4,   0.8},	/*   193 */
	{0.3,   0,     0.6},	/*   194 */
	{0.45,  0.3,   0.6},	/*   195 */
	{0.2,   0,     0.4},	/*   196 */
	{0.3,   0.2,   0.4},	/*   197 */
	{0.1,   0,     0.2},	/*   198 */
	{0.15,  0.1,   0.2},	/*   199 */

	{0.75,  0,     1},	/*   200 */
	{0.875, 0.5,   1},	/*   201 */
	{0.6,   0,     0.8},	/*   202 */
	{0.7,   0.4,   0.8},	/*   203 */
	{0.45,  0,     0.6},	/*   204 */
	{0.525, 0.3,   0.6},	/*   205 */
	{0.3,   0,     0.4},	/*   206 */
	{0.35,  0.2,   0.4},	/*   207 */
	{0.15,  0,     0.2},	/*   208 */
	{0.175, 0.1,   0.2},	/*   209 */

	{1,     0,     1},	/*   210 */
	{1,     0.5,   1},	/*   211 */
	{0.8,   0,     0.8},	/*   212 */
	{0.8,   0.4,   0.8},	/*   213 */
	{0.6,   0,     0.6},	/*   214 */
	{0.6,   0.3,   0.6},	/*   215 */
	{0.4,   0,     0.4},	/*   216 */
	{0.4,   0.2,   0.4},	/*   217 */
	{0.2,   0,     0.2},	/*   218 */
	{0.2,   0.1,   0.2},	/*   219 */

	{1,     0,     0.75},	/*   220 */
	{1,     0.5,   0.875},	/*   221 */
	{0.8,   0,     0.6},	/*   222 */
	{0.8,   0.4,   0.7},	/*   223 */
	{0.6,   0,     0.45},	/*   224 */
	{0.6,   0.3,   0.525},	/*   225 */
	{0.4,   0,     0.3},	/*   226 */
	{0.4,   0.2,   0.35},	/*   227 */
	{0.2,   0,     0.15},	/*   228 */
	{0.2,   0.1,   0.175},	/*   229 */

	{1,     0,     0.5},	/*   230 */
	{1,     0.5,   0.75},	/*   231 */
	{0.8,   0,     0.4},	/*   232 */
	{0.8,   0.4,   0.6},	/*   233 */
	{0.6,   0,     0.3},	/*   234 */
	{0.6,   0.3,   0.45},	/*   235 */
	{0.4,   0,     0.2},	/*   236 */
	{0.4,   0.2,   0.3},	/*   237 */
	{0.2,   0,     0.1},	/*   238 */
	{0.2,   0.1,   0.15},	/*   239 */

	{1,     0,     0.25},	/*   240 */
	{1,     0.5,   0.625},	/*   241 */
	{0.8,   0,     0.2},	/*   242 */
	{0.8,   0.4,   0.5},	/*   243 */
	{0.6,   0,     0.15},	/*   244 */
	{0.6,   0.3,   0.375},	/*   245 */
	{0.4,   0,     0.1},	/*   246 */
	{0.4,   0.2,   0.25},	/*   247 */
	{0.2,   0,     0.05},	/*   248 */
	{0.2,   0.1,   0.125},	/*   249 */

	{0.857143, 0.857143, 0.857143},	/*   250 */
	{0.714286, 0.714286, 0.714286},	/*   251 */
	{0.571429, 0.571429, 0.571429},	/*   252 */
	{0.428571, 0.428571, 0.428571},	/*   253 */
	{0.285714, 0.285714, 0.285714},	/*   254 */
	{0.142857, 0.142857, 0.142857}	/*   255 */

};

#endif // VHF_H_DXFCOLORTABLE
