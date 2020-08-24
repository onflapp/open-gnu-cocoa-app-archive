/*
 * psi.prolog
 *
 * Copyright (C) 1996-2000 by vhf computer GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-09-09
 * modified: 
 *
 * this code writes a file with the structure below.
 * # # # # l		(x0 y0 x1 y1) line
 * # # # # # # # #c	(x0 y0 x1 y1 x2 y2 x3 y3) curve
 * # w			(width) width
 * # # # # # co		(c m y k a) color
 * n			new list
 * f			list is a filled polygon
 * s			list is a group
 * cl			list is a clip list (clip with old clip list and use it)
 * gs			save current clip list and width to top of stack
 * gr			use last clip list (on top of stack) and width
 * # # # # # # # # # #	(x y a b c d e f text font) text
 */

#define PROLOG_STRING @" \n\
/cfile (/tmp/Cenon_psImport.out) (w) file def \n\
/print { cfile exch writestring } bind def \n\
 \n\
% whether we have to flatten the text\n\n \n\
/flattenText 0 def \n\
 \n\
% remember the current point \n\
/currentX 0 def \n\
/currentY 0 def \n\
 \n\
% 1 = newpath \n\
%/startPath 1 def \n\
 \n\
% 1st point of path to close the path \n\
/beginX 0 def \n\
/beginY 0 def \n\
 \n\
% dummy for converting strings \n\
/str 50 string def \n\
 \n\
% 0 = mirror at \n\
/mirror 0 def \n\
 \n\
% mirror a at 0 \n\
/mir \n\
{ \n\
    mirror 0 ne \n\
    {   0 exch sub \n\
    }if \n\
} bind def \n\
 \n\
% scale \n\
/m_a 1 def \n\
/m_b 0 def \n\
/m_c 0 def \n\
/m_d 1 def \n\
/m_x 0 def \n\
/m_y 0 def \n\
/matrix_x	% x y \n\
{ \n\
    % ax + cy + tx \n\
    m_c mul exch m_a mul add m_x add \n\
} bind def \n\
/matrix_y	% x y \n\
{ \n\
    % bx + dy + ty \n\
    m_d mul exch m_b mul add m_y add \n\
} bind def \n\
 \n\
/writecurrentcolor \n\
{ \n\
    currentcolorspace 0 get /CIEBasedABC eq \n\
    {   currentcolor setrgbcolor \n\
    } if \n\
 \n\
    currentcmykcolor	% -> c m y k \n\
    3 index str cvs print \n\
    ( ) print \n\
    2 index str cvs print \n\
    ( ) print \n\
    1 index str cvs print \n\
    ( ) print \n\
    str cvs print \n\
    ( ) print \n\
    pop pop pop \n\
    currentalpha	% a \n\
    str cvs print \n\
    ( co )print \n\
} bind def \n\
 \n\
/vhfCurrentLineWidth 1 def \n\
/writecurrentlinewidth \n\
{ \n\
    currentlinewidth	% w \n\
    storeMatrix \n\
 \n\
    % (wb + wd + wa + wc) / 2 \n\
    dup dup dup m_b abs mul exch m_d abs mul add  exch m_a abs mul add  exch m_c abs mul add  2 div  abs \n\
    dup vhfCurrentLineWidth ne \n\
    { \n\
        dup str cvs print \n\
        ( w ) print \n\
        /vhfCurrentLineWidth exch def \n\
    } \n\
    { \n\
        pop \n\
    }ifelse \n\
} bind def \n\
 \n\
/_move	% x y \n\
{ \n\
    /currentY exch def \n\
    /currentX exch def \n\
    /beginX currentX def \n\
    /beginY currentY def \n\
}bind def \n\
 \n\
/_line \n\
{ \n\
    /y1 exch def \n\
    /x1 exch def \n\
 \n\
    % x x1 ne y y1 ne or \n\
    currentX x1 sub abs 0.001 gt  currentY y1 sub abs 0.001 gt or \n\
    { \n\
        currentX currentY matrix_x str cvs print \n\
        ( ) print \n\
        currentX currentY matrix_y str cvs print \n\
        ( ) print \n\
 \n\
        x1 y1 matrix_x str cvs print \n\
        ( ) print \n\
        x1 y1 matrix_y str cvs print \n\
        ( l ) print \n\
        /currentX x1 def \n\
        /currentY y1 def \n\
    }if \n\
}bind def \n\
 \n\
/_curve \n\
{ \n\
    % x1 y1 x2 y2 x3 y3 \n\
 \n\
    currentX currentY matrix_x str cvs print \n\
    ( ) print \n\
    currentX currentY matrix_y str cvs print \n\
    ( ) print \n\
    5 index 5 index matrix_x str cvs print \n\
    ( ) print \n\
    5 index 5 index matrix_y str cvs print \n\
    ( ) print \n\
    3 index 3 index matrix_x str cvs print \n\
    ( ) print \n\
    3 index 3 index matrix_y str cvs print \n\
    ( ) print \n\
 \n\
    /currentY exch def \n\
    /currentX exch def \n\
 \n\
    currentX currentY matrix_x str cvs print \n\
    ( ) print \n\
    currentX currentY matrix_y str cvs print \n\
    ( c )print \n\
    pop pop pop pop \n\
}bind def \n\
 \n\
/_close \n\
{ \n\
    beginX beginY _line \n\
} bind def \n\
 \n\
/storeMatrix \n\
{ \n\
    matrix currentmatrix \n\
    0 get /m_a exch def \n\
    matrix currentmatrix \n\
    1 get /m_b exch def \n\
    matrix currentmatrix \n\
    2 get /m_c exch def \n\
    matrix currentmatrix \n\
    3 get /m_d exch def \n\
    matrix currentmatrix \n\
    4 get /m_x exch def \n\
    matrix currentmatrix \n\
    5 get /m_y exch def \n\
} bind def \n\
 \n\
/rectfill \n\
{ \n\
    (n )print		% start polygon \n\
    writecurrentcolor \n\
    writecurrentlinewidth \n\
    storeMatrix \n\
 \n\
    % x y width height \n\
    dup type /arraytype ne \n\
    { \n\
        /hr exch def \n\
        /wr exch def \n\
        /yr exch def \n\
        /xr exch def \n\
        xr yr _move \n\
        xr wr add yr _line \n\
        xr wr add yr hr add _line \n\
        xr yr hr add _line \n\
        xr yr _line \n\
    } \n\
    % numarray \n\
    % numstring \n\
    { \n\
        /ar exch def \n\
        0 4 ar length 1 sub \n\
        { \n\
            /n exch def \n\
            ar n get /xr exch def \n\
            ar n 1 add get /yr exch def \n\
            ar n 2 add get /wr exch def \n\
            ar n 3 add get /hr exch def \n\
            xr yr _move \n\
            xr wr add yr _line \n\
            xr wr add yr hr add _line \n\
            xr yr hr add _line \n\
            xr yr _line \n\
        } for \n\
    }ifelse \n\
 \n\
    (f )print			% close polygon \n\
} bind def \n\
 \n\
/rectstroke \n\
{ \n\
    (n )print			% start rect \n\
    writecurrentcolor \n\
    writecurrentlinewidth \n\
    storeMatrix \n\
 \n\
    % x y width height \n\
    dup type /arraytype ne \n\
    { \n\
        /hr exch def \n\
        /wr exch def \n\
        /yr exch def \n\
        /xr exch def \n\
        xr yr _move \n\
        xr wr add yr _line \n\
        xr wr add yr hr add _line \n\
        xr yr hr add _line \n\
        xr yr _line \n\
        } \n\
    % numarray \n\
    % numstring \n\
    { \n\
        /ar exch def \n\
        0 4 ar length 1 sub \n\
        { \n\
            /n exch def \n\
            ar n get /xr exch def \n\
            ar n 1 add get /yr exch def \n\
            ar n 2 add get /wr exch def \n\
            ar n 3 add get /hr exch def \n\
            xr yr _move \n\
            xr wr add yr _line \n\
            xr wr add yr hr add _line \n\
            xr yr hr add _line \n\
            xr yr _line \n\
        } for \n\
    }ifelse \n\
        (n )print	% stroke rect \n\
} bind def \n\
 \n\
/stroke \n\
{ \n\
    writecurrentcolor \n\
    writecurrentlinewidth \n\
    storeMatrix \n\
    {_move} {_line} {_curve} {_close} pathforall \n\
    (n )print		% stroke path \n\
    newpath \n\
} bind def \n\
 \n\
/eofill \n\
{ \n\
    (n )print		% start polygon \n\
    writecurrentcolor	% write color \n\
    writecurrentlinewidth \n\
 \n\
    storeMatrix		% take transformation, scaling, rotation from PostScript \n\
    {_move} {_line} {_curve} {_close} pathforall \n\
 \n\
    (f )print		% close polygon \n\
    newpath		% clear stack \n\
} bind def \n\
 \n\
/fill \n\
{ \n\
    eofill \n\
} bind def \n\
 \n\
/clip \n\
{ \n\
    (n )print			% start clip polygon \n\
 \n\
    storeMatrix			% take transformation, scaling, rotation from PostScript \n\
    {_move} {_line} {_curve} {_close} pathforall \n\
 \n\
    (cl )print			% close clip polygon begin path \n\
    % we have to close the path!! \n\
 \n\
    /clipCnt 1 def \n\
    newpath			% clear stack \n\
} bind def \n\
 \n\
% we don't clip \n\
/rectclip \n\
{ \n\
    pop pop pop pop \n\
} bind def \n\
 \n\
/stateArray 500 array def \n\
/stateTop 0 def \n\
/gsave \n\
{ \n\
    (gs ) print \n\
    stateArray stateTop gstate currentgstate put \n\
    /stateTop stateTop 1 add def \n\
} bind def \n\
 \n\
/grestore \n\
{ \n\
    stateTop 1 lt \n\
    { \n\
    } \n\
    { \n\
        (gr ) print \n\
        stateArray stateTop 1 sub get setgstate \n\
        /stateTop stateTop 1 sub def \n\
        stateArray stateTop 0 put \n\
        /vhfCurrentLineWidth -1 def \n\
    }ifelse \n\
} bind def \n\
 \n\
% a bind def of the show operator doesn't work, \n\
% so this is our way to get a charpath entry for flattening text \n\
/root_charpath \n\
{ \n\
    charpath \n\
} bind def \n\
 \n\
/show \n\
{ \n\
    storeMatrix \n\
    currentfont /FontName known flattenText 0 eq and \n\
    { \n\
        writecurrentcolor	% write color \n\
        writecurrentlinewidth \n\
 \n\
        currentpoint /currentY exch def /currentX exch def \n\
        currentX currentY matrix_x str cvs print	% position \n\
        ( ) print \n\
        currentX currentY matrix_y str cvs print \n\
        ( ) print \n\
 \n\
        [1.0 0.0 0.0 1.0 0.0 0.0] currentmatrix currentfont (FontMatrix) get [1.0 0.0 0.0 1.0 0.0 0.0] concatmatrix \n\
        /matrix exch def \n\
 \n\
        matrix 0 get str cvs print \n\
        ( ) print \n\
        matrix 1 get str cvs print \n\
        ( ) print \n\
        matrix 2 get str cvs print \n\
        ( ) print \n\
        matrix 3 get str cvs print \n\
        ( ) print \n\
        matrix 4 get str cvs print \n\
        ( ) print \n\
        matrix 5 get str cvs print \n\
        ( ) print \n\
 \n\
        ( \\() print \n\
        print		% the string itself \n\
        (\\) ) print \n\
 \n\
        (\\() print \n\
        currentfont		% -> font dict \n\
        /FontName get str cvs print \n\
        (\\)) print \n\
 \n\
        ( t )print \n\
    } \n\
    % stack: string \n\
    { \n\
        % we scale to factor 10 to minimize rounding problems in charpath (distance between chars varies) \n\
        currentpoint	% x y \n\
        10 10 scale \n\
        moveto \n\
        0.1 0.1 scale \n\
 \n\
        % we process each char separately to get smaller paths \n\
        0 1 2 index length 1 sub \n\
        { \n\
            (n )print		% start polygon \n\
            writecurrentcolor	% write color \n\
            writecurrentlinewidth \n\
            %	/startPath 1 def \n\
 \n\
            currentpoint	% x y	(this is scaled to 10) \n\
            newpath			% clear graphic stack \n\
            moveto \n\
            10 10 scale \n\
            1 index exch 1 getinterval false root_charpath \n\
            0.1 0.1 scale \n\
 \n\
            /m_a m_a 0.1 mul def \n\
            /m_b m_b 0.1 mul def \n\
            /m_c m_c 0.1 mul def \n\
            /m_d m_d 0.1 mul def \n\
            {_move} {_line} {_curve} {_close} pathforall \n\
            /m_a m_a 10.0 mul def \n\
            /m_b m_b 10.0 mul def \n\
            /m_c m_c 10.0 mul def \n\
            /m_d m_d 10.0 mul def \n\
 \n\
            % fill or stroke charpath \n\
            currentfont (PaintType) get 0 eq { (f )print } { (n )print } ifelse \n\
        } for \n\
        currentpoint	% x y	(this is scaled to 10) \n\
        0.1 0.1 scale \n\
        newpath				% clear graphic stack (and current point) \n\
        moveto \n\
        10.0 10.0 scale \n\
    } \n\
    ifelse \n\
} def \n\
 \n\
/ashow \n\
{ \n\
    % ax ay string \n\
    exch pop \n\
    exch pop \n\
    show \n\
} bind def \n\
 \n\
/widthshow	% cx cy char string \n\
{ \n\
    exch pop \n\
    exch pop \n\
    exch pop \n\
    show \n\
} bind def \n\
 \n\
/awidthshow		% cx cy char ax ay string \n\
{ \n\
    exch pop \n\
    exch pop \n\
    exch pop \n\
    exch pop \n\
    exch pop \n\
    show \n\
} bind def \n\
 \n\
/cshow	% proc string \n\
{ \n\
    exch pop \n\
    show \n\
} bind def \n\
 \n\
/kshow	% proc string \n\
{ \n\
    exch pop \n\
    show \n\
} bind def \n\
 \n\
/charpath \n\
{ \n\
    % string bool \n\
    pop \n\
    show \n\
} bind def \n\
"
