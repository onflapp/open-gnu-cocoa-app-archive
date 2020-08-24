%
% psi.prolog
%
% Copyright (C) 1996-2012 by vhf interservice GmbH
% Author:   Georg Fleischmann
%
% created:  2000-09-09
% modified: 2012-05-16 (xshow, yshow, xyshow added, show with flatten extended to handle displacement)
%
% this PostScript code writes a file with the structure below.
% # # # # l             (x0 y0 x1 y1) line
% # # # # # # # # c     (x0 y0 x1 y1 x2 y2 x3 y3) curve
% # w                   (width) width
% # # # # # co          (c m y k a) color
% n                     new list
% f                     list is a filled polygon
% s                     list is a group
% cl                    list is a clip list (clip with old clip list and use it)
% gs                    save current clip list and width to top of stack
% gr                    use last clip list (on top of stack) and width
% # # # # # # # # # #   (x y a b c d e f text font) text
%

/cfile (/tmp/psImport.out) (w) file def
/print { cfile exch writestring } bind def

% whether we have to flatten the text
/flattenText 0  def

/vhf_xarray  [] def     % used for xshow
/vhf_yarray  [] def     % used for yshow
/vhf_xyarray [] def     % used for xyshow

% remember the current point
/currentX 0 def
/currentY 0 def

% 1 = newpath
%/startPath 1 def

% 1st point of path to close the path
/beginX 0 def
/beginY 0 def

% dummy for converting strings
/str 50 string def

% 0 = mirror at
/mirror 0 def

% mirror a at 0
/mir
{
	mirror 0 ne
	{	0 exch sub
	}if
} bind def

% scale
/m_a 1 def
/m_b 0 def
/m_c 0 def
/m_d 1 def
/m_x 0 def
/m_y 0 def
/matrix_x	% x y
{
	% ax + cy + tx
	m_c mul exch m_a mul add m_x add
} bind def
/matrix_y	% x y
{
	% bx + dy + ty
	m_d mul exch m_b mul add m_y add
} bind def

/writecurrentcolor
{
	currentcolorspace 0 get /CIEBasedABC eq
	{	currentcolor setrgbcolor
	} if

	currentcmykcolor	% -> c m y k
	3 index str cvs print
	( ) print
	2 index str cvs print
	( ) print
	1 index str cvs print
	( ) print
	str cvs print
	( ) print
	pop pop pop
	currentalpha	% a
	str cvs print
	( co
)print
} bind def

/vhfCurrentLineWidth 1 def
/writecurrentlinewidth
{
	currentlinewidth	% w
	storeMatrix

	% (wb + wd + wa + wc) / 2
	dup dup dup m_b abs mul exch m_d abs mul add  exch m_a abs mul add  exch m_c abs mul add  2 div  abs
	dup vhfCurrentLineWidth ne
	{
		dup str cvs print
		( w
) print
		/vhfCurrentLineWidth exch def
	}
	{
		pop
	}ifelse
} bind def

/_move	% x y
{
	/currentY exch def
	/currentX exch def

%	startPath 1 eq
%	{
		/beginX currentX def
		/beginY currentY def
%		/startPath 0 def
%	}if

}bind def

/_line
{
	/y1 exch def
	/x1 exch def

	% x x1 ne y y1 ne or
	currentX x1 sub abs 0.001 gt  currentY y1 sub abs 0.001 gt or
	{
		currentX currentY matrix_x str cvs print
		( ) print
		currentX currentY matrix_y str cvs print
		( ) print

		x1 y1 matrix_x str cvs print
		( ) print
		x1 y1 matrix_y str cvs print
		( l
) print
		/currentX x1 def
		/currentY y1 def
	}if
}bind def

/_curve
{
	% x1 y1 x2 y2 x3 y3

	currentX currentY matrix_x str cvs print
	( ) print
	currentX currentY matrix_y str cvs print
	( ) print
	5 index 5 index matrix_x str cvs print
	( ) print
	5 index 5 index matrix_y str cvs print
	( ) print
	3 index 3 index matrix_x str cvs print
	( ) print
	3 index 3 index matrix_y str cvs print
	( ) print

	/currentY exch def
	/currentX exch def

	currentX currentY matrix_x str cvs print
	( ) print
	currentX currentY matrix_y str cvs print
	( c
)print
	pop pop pop pop
}bind def

% modified: 18.10.96
/_close
{
%	/startPath 1 def
	beginX beginY _line
} bind def

/storeMatrix
{
	matrix currentmatrix
	0 get /m_a exch def
%/m_a m_a 0.5 mul def	% workaround to avoid uncertaincies in small ps files
	matrix currentmatrix
	1 get /m_b exch def
	matrix currentmatrix
	2 get /m_c exch def
	matrix currentmatrix
	3 get /m_d exch def
%/m_d m_d 0.5 mul def	% workaround to avoid uncertaincies in small ps files

	matrix currentmatrix
	4 get /m_x exch def
	matrix currentmatrix
	5 get /m_y exch def
} bind def

/rectfill
{
	(n )print			% start polygon
	writecurrentcolor
	writecurrentlinewidth
	storeMatrix

	% x y width height
	dup type /arraytype ne
	{
		/hr exch def
		/wr exch def
		/yr exch def
		/xr exch def
		xr yr _move
		xr wr add yr _line
		xr wr add yr hr add _line
		xr yr hr add _line
		xr yr _line
	}
	% numarray
	% numstring
	{
		/ar exch def
		0 4 ar length 1 sub
		{
			/n exch def
			ar n get /xr exch def
			ar n 1 add get /yr exch def
			ar n 2 add get /wr exch def
			ar n 3 add get /hr exch def
			xr yr _move
			xr wr add yr _line
			xr wr add yr hr add _line
			xr yr hr add _line
			xr yr _line
		} for
	}ifelse

	(f
)print			% close polygon
} bind def

/rectstroke
{
	(n )print			% start rect
	writecurrentcolor
	writecurrentlinewidth
	storeMatrix

	% x y width height
	dup type /arraytype ne
	{
		/hr exch def
		/wr exch def
		/yr exch def
		/xr exch def
		xr yr _move
		xr wr add yr _line
		xr wr add yr hr add _line
		xr yr hr add _line
		xr yr _line
	}
	% numarray
	% numstring
	{
		/ar exch def
		0 4 ar length 1 sub
		{
			/n exch def
			ar n get /xr exch def
			ar n 1 add get /yr exch def
			ar n 2 add get /wr exch def
			ar n 3 add get /hr exch def
			xr yr _move
			xr wr add yr _line
			xr wr add yr hr add _line
			xr yr hr add _line
			xr yr _line
		} for
	}ifelse
	(n )print			% stroke rect
} bind def

/stroke
{
	writecurrentcolor
	writecurrentlinewidth
%	/startPath 1 def
	storeMatrix
	{_move} {_line} {_curve} {_close} pathforall
	(n )print			% stroke path

	newpath
} bind def

/eofill
{
	(n )print			% start polygon
	writecurrentcolor	% write color
	writecurrentlinewidth

%	/startPath 1 def	% flag -> position of next move will be used from closepath
	storeMatrix			% take transformation, scaling, rotation from PostScript
	{_move} {_line} {_curve} {_close} pathforall

	(f
)print			% close polygon

	newpath				% clear stack
} bind def

/fill
{
	eofill
} bind def

/clip
{
	(n 
)print			% start clip polygon

%	/startPath 1 def	% flag -> position of next move will be used from closepath
	storeMatrix			% take transformation, scaling, rotation from PostScript
	{_move} {_line} {_curve} {_close} pathforall

	(cl 
)print			% close clip polygon begin path
						% we have to close the path!!

	/clipCnt 1 def
	newpath				% clear stack
} bind def

% we don't clip
% because this doesn't work for flattening text (show, charpath) with NeXT PostScript Code
/rectclip
{
	pop pop pop pop
} bind def

/stateArray 500 array def
/stateTop 0 def
/gsave
{
	(gs 
) print
	stateArray stateTop gstate currentgstate put
	/stateTop stateTop 1 add def
} bind def

/grestore
{
	stateTop 1 lt
	{
	}
	{
		(gr 
) print
		stateArray stateTop 1 sub get setgstate
		/stateTop stateTop 1 sub def
		stateArray stateTop 0 put
		/vhfCurrentLineWidth -1 def
	}ifelse
} bind def

% a bind def of the show operator doesn't work,
% so this is our way to get a charpath entry for flattening text
/root_charpath
{
	charpath
} bind def

/show   % string
{
	storeMatrix
	currentfont /FontName known flattenText 0 eq and
	{
		writecurrentcolor	% write color
		writecurrentlinewidth

		currentpoint /currentY exch def /currentX exch def
		currentX currentY matrix_x str cvs print	% position
		( ) print
		currentX currentY matrix_y str cvs print
		( ) print

		[1.0 0.0 0.0 1.0 0.0 0.0] currentmatrix currentfont (FontMatrix) get [1.0 0.0 0.0 1.0 0.0 0.0] concatmatrix
		/matrix exch def

		matrix 0 get str cvs print
		( ) print
		matrix 1 get str cvs print
		( ) print
		matrix 2 get str cvs print
		( ) print
		matrix 3 get str cvs print
		( ) print
		matrix 4 get str cvs print
		( ) print
		matrix 5 get str cvs print
		( ) print

		( \() print
		print		% the string itself
		(\) ) print

		(\() print
		currentfont		% -> font dict
		/FontName get str cvs print
		(\)) print

		( t
)print
	}
	% stack: string
	{
		%/m_a m_a 0.5 mul def	% hide our 2:1 scale */
		%/m_d m_d 0.5 mul def

		% we scale to factor 10 to minimize rounding problems in charpath (distance between chars varies)

		currentpoint	% x y
		%0 0 moveto
		10 10 scale
		moveto
		0.1 0.1 scale

		currentpoint	% x y
        /vhf_y exch def
        /vhf_x exch def

		% we process each char separately to get smaller paths
		0 1 2 index length 1 sub
		{
            dup /vhf_index exch def     % current index

			(n )print			% start polygon
			writecurrentcolor	% write color
			writecurrentlinewidth
		%	/startPath 1 def

			currentpoint	% x y	(this is scaled to 10)
			newpath			% clear graphic stack
			moveto
			10 10 scale
			1 index exch 1 getinterval false root_charpath
			0.1 0.1 scale

			/m_a m_a 0.1 mul def
			/m_b m_b 0.1 mul def
			/m_c m_c 0.1 mul def
			/m_d m_d 0.1 mul def
			{_move} {_line} {_curve} {_close} pathforall
			/m_a m_a 10.0 mul def
			/m_b m_b 10.0 mul def
			/m_c m_c 10.0 mul def
			/m_d m_d 10.0 mul def

			(f
)print                  % close polygon

            % position for next char
            vhf_xarray  length 0 ne     % x displacement
            {   vhf_x  vhf_xarray vhf_index get 10 mul  add /vhf_x exch def
                vhf_x vhf_y moveto
            } if
            vhf_yarray  length 0 ne     % y displacement
            {   vhf_y  vhf_yarray vhf_index get 10 mul  add /vhf_y exch def
                vhf_x vhf_y moveto
            } if
            vhf_xyarray length 0 ne     % xy displacement
            {   vhf_x  vhf_xyarray vhf_index 2 mul get 10 mul        add /vhf_x exch def    % 0, 2, 4, ...
                vhf_y  vhf_xyarray vhf_index 2 mul 1 add get 10 mul  add /vhf_y exch def    % 1, 3, 5, ...
                vhf_x vhf_y moveto
            } if
		} for
		currentpoint    % x y	(this is scaled to 10)
		0.1 0.1 scale
		newpath         % clear graphic stack (and current point)
		moveto
		10.0 10.0 scale

		%/m_a m_a 2.0 mul def
		%/m_d m_d 2.0 mul def
	}
	ifelse
} def

/ashow          % ax ay string (FIXME: add kerning)
{
	exch pop
	exch pop
	show
} bind def

/widthshow      % cx cy char string
{
	exch pop
	exch pop
	exch pop
	show
} bind def

/awidthshow		% cx cy char ax ay string
{
	exch pop
	exch pop
	exch pop
	exch pop
	exch pop
	show
} bind def

/cshow          % proc string
{
	exch pop
	show
} bind def

/kshow          % proc string
{
	exch pop
	show
} bind def

/xyshow         % string numarray/numstring [Lev 2] - (Text) [10 50  10 50  10 50  0 0] xyshow
{
    /vhf_xyarray exch def
	show
} bind def
/xshow          % string numarray/numstring [Lev 2] - (Text) [10 10 10 0] xshow
{
    /vhf_xarray exch def
    show
} bind def
/yshow          % string numarray/numstring [Lev 2] - (Text) [50 50 50 0] yshow
{
    /vhf_yarray exch def
	show
} bind def

% FIXME: we could also write the charname to our file and later read the name
% FIXME: For flatten text we should directly exec the character procedure from /CharProcs
/glyphshow		% name [Lev 2]
{
    /vhf_charname exch def

    % We get the char code from the /Encoding array, then we call show
    0 1 255
    {
        dup currentfont /Encoding get exch get	% get charname at index in Encoding
        vhf_charname eq				% compare charname with charname
        {
            % (\[) print  dup 40 string cvs print  (\]) print	% print index (char code)
            1 string dup 0 3 index put show		% put index into string at position 0
            pop		% remove index from stack
            exit
        } if
    } for
} bind def

/charpath
{
	% string bool
	pop
	show
} bind def
