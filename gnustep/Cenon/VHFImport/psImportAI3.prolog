%!PS-Adobe-3.0 EPSF-3.0
%%Creator: OpenEnd
%%For: () ()
%%BoundingBox: -139 297 841 562
%%DocumentProcessColors: Cyan Magenta Yellow
%%DocumentFonts: Reporter-Two
%%DocumentSuppliedResources: procset Adobe_packedarray 2.0 0
%%+ procset Adobe_cmykcolor 1.1 0
%%+ procset Adobe_cshow 1.1 0
%%+ procset Adobe_customcolor 1.0 0
%%+ procset Adobe_pattern_AI3 1.0 0
%%+ procset Adobe_typography_AI3 1.0 1
%%+ procset Adobe_IllustratorA_AI3 1.0 1
%AI3_ColorUsage: Color
%AI3_TemplateBox: 306 396 306 396
%AI3_TileBox: 0 0 842 595
%AI3_DocumentPreview: Header
%%Template:
%%PageOrigin:0 0
%%AI3_PaperRect:0 595 842 0
%%AI3_Margin:0 0 0 0
%%EndComments
%%BeginProlog
%%BeginResource: procset Adobe_packedarray 2.0 0
%%Title: (Packed Array Operators)
%%Version: 2.0 
%%CreationDate: (8/2/90) ()
%%Copyright: ((C) 1987-1990 Adobe Systems Incorporated All Rights Reserved)

userdict /Adobe_packedarray 5 dict dup begin put
/initialize			% - initialize -
{
/packedarray where
	{
	pop
	}
	{
	Adobe_packedarray begin
	Adobe_packedarray
		{
		dup xcheck
			{
			bind
			} if
		userdict 3 1 roll put
		} forall
	end
	} ifelse
} def
/terminate			% - terminate -
{
} def
/packedarray		% arguments count packedarray array
{
array astore readonly
} def
/setpacking			% boolean setpacking -
{
pop
} def
/currentpacking		% - setpacking boolean
{
false
} def
currentdict readonly pop end
%%EndResource
Adobe_packedarray /initialize get exec

%%BeginResource: procset Adobe_cmykcolor 1.1 0
%%Title: (CMYK Color Operators)
%%Version: 1.1 
%%CreationDate: (1/23/89) ()
%%Copyright: ((C) 1987-1990 Adobe Systems Incorporated All Rights Reserved)

currentpacking true setpacking
userdict /Adobe_cmykcolor 4 dict dup begin put
/initialize			% - initialize -
{
/setcmykcolor where
	{
	pop
	}
	{
	userdict /Adobe_cmykcolor_vars 2 dict dup begin put
	/_setrgbcolor
		/setrgbcolor load def
	/_currentrgbcolor
		/currentrgbcolor load def
	Adobe_cmykcolor begin
	Adobe_cmykcolor
		{
		dup xcheck
			{
			bind
			} if
		pop pop
		} forall
	end
	end
	Adobe_cmykcolor begin
	} ifelse
} def
/terminate			% - terminate -
{
currentdict Adobe_cmykcolor eq
	{
	end
	} if
} def
/setcmykcolor		% cyan magenta yellow black setcmykcolor -
{
1 sub 4 1 roll
3
	{
	3 index add neg dup 0 lt
		{
		pop 0
		} if
	3 1 roll
	} repeat
Adobe_cmykcolor_vars /_setrgbcolor get exec
pop
} def 
/currentcmykcolor	% - currentcmykcolor cyan magenta yellow black
{
Adobe_cmykcolor_vars /_currentrgbcolor get exec
3
	{
	1 sub neg 3 1 roll
	} repeat
0
} def
currentdict readonly pop end
setpacking

%%EndResource
%%BeginResource: procset Adobe_cshow 1.1 0
%%Title: (cshow Operator)
%%Version: 1.1 
%%CreationDate: (1/23/89) ()
%%Copyright: ((C) 1987-1990 Adobe Systems Incorporated All Rights Reserved)

currentpacking true setpacking
userdict /Adobe_cshow 3 dict dup begin put
/initialize			% - initialize -
{
/cshow where
	{
	pop
	}
	{
	userdict /Adobe_cshow_vars 1 dict dup begin put
	/_cshow		% - _cshow proc
		{} def
	Adobe_cshow begin
	Adobe_cshow
		{
		dup xcheck
			{
			bind
			} if
		userdict 3 1 roll put
		} forall
	end
	end
	} ifelse
} def
/terminate			% - terminate -
{
} def
/cshow				% proc string cshow -
{
exch
Adobe_cshow_vars
	exch /_cshow
	exch put
	{
	0 0 Adobe_cshow_vars /_cshow get exec
	} forall
} def
currentdict readonly pop end
setpacking

%%EndResource
%%BeginResource: procset Adobe_customcolor 1.0 0
%%Title: (Custom Color Operators)
%%Version: 1.0 
%%CreationDate: (5/9/88) ()
%%Copyright: ((C) 1987-1990 Adobe Systems Incorporated All Rights Reserved)

currentpacking true setpacking
userdict /Adobe_customcolor 5 dict dup begin put
/initialize			% - initialize -
{
/setcustomcolor where
	{
	pop
	}
	{
	Adobe_customcolor begin
	Adobe_customcolor
		{
		dup xcheck
			{
			bind
			} if
		pop pop
		} forall
	end
	Adobe_customcolor begin
	} ifelse
} def
/terminate			% - terminate -
{
currentdict Adobe_customcolor eq
	{
	end
	} if
} def
/findcmykcustomcolor	% cyan magenta yellow black name findcmykcustomcolor object
{
5 packedarray
}  def
/setcustomcolor		% object tint setcustomcolor -
{
exch
aload pop pop
4
	{
	4 index mul 4 1 roll
	} repeat
5 -1 roll pop
setcmykcolor
} def
/setoverprint		% boolean setoverprint -
{
pop
} def
currentdict readonly pop end
setpacking

%%EndResource
%%BeginResource: procset Adobe_typography_AI3 1.0 1
%%Title: (Typography Operators)
%%Version: 1.0 
%%CreationDate:(5/31/90) ()
%%Copyright: ((C) 1987-1990 Adobe Systems Incorporated All Rights Reserved)

currentpacking true setpacking
userdict /Adobe_typography_AI3 47 dict dup begin put
/initialize			% - initialize -
{
/TZ
 where
	{
	pop
	}
	{
	Adobe_typography_AI3 begin
	Adobe_typography_AI3
		{
		dup xcheck
			{
			bind
			} if
		pop pop
		} forall
	end
	Adobe_typography_AI3 begin
	} ifelse
} def
/terminate			% - terminate -
{
currentdict Adobe_typography_AI3 eq
	{
	end
	} if
} def

% [ number value stream [ array for encoding modification ] modifyEncoding ==> [ modified array ]
/modifyEncoding
{
	/_tempEncode exch ddef
	
	% pointer for sequential encodings
	/_pntr 0 ddef
	
	{
		% get bottom object
		counttomark -1 roll

		% is it a mark ?
		dup type dup /marktype eq 		
		{
			% exit
			pop pop exit
		}
		{
			% ... object ... type ....

			% insert if a nametype
			/nametype eq
			{
				% insert the name at _pntr and increment pointer
				_tempEncode /_pntr dup load dup 3 1 roll 1 add ddef 3 -1 roll
				put
			}
			{
				% reset _pntr if it's a number
				/_pntr exch ddef					
			}
			ifelse
		}
		ifelse
	}
	loop	
	
	% return the modified encoding
	_tempEncode
}
def

/TE	% Set std platform encoding 	% (encoding pairs) TE -
{
	StandardEncoding 256 array copy modifyEncoding 
	/_nativeEncoding exch def
} def

% re-define font
% expected arguments
% for 'normal fonts : 
%	[ /_Helvetica-Bold/Helvetica-Bold direction fontScript defaultEncoding TZ
%
% for cartographic, pictographic, and expert fonts :
% 	[ ... number value stream ... /_Helvetica-Bold/Helvetica-Bold 
%	direction fontScript defaultEncoding TZ
/TZ		
{
	% platform dependent coding flag
	/_useNativeEncoding exch def

	% pop fontScript & direction
	pop pop
	
	% create a new dictionary with length
	% equal to original dictionary length + 2
	% copy all the key/value pairs except FID
	findfont dup length 2 add dict
	
	begin
	
		% copy all the values but the FID
		% into the new dictionary
		mark exch
		{
			1 index /FID ne { def } if cleartomark mark
		}
		forall
		% discard last mark
		pop
		
		% define FontName
		/FontName exch def
		
		% if no re-encoding stream is present
		% then if the use platform encoding flag is true
		% install AI platform encoding
		% else leave the base encoding in effect

		counttomark 0 eq
		{
			1 _useNativeEncoding eq
			{
				/Encoding _nativeEncoding def
			}
			if
			% clean up
			cleartomark
		}
		{	
			% custom encoding to be done
			% start off with a copy of the font's standard encoding
			/Encoding load 256 array copy 
			modifyEncoding /Encoding exch def
		}
		ifelse		
		FontName currentdict
	end
	
	% register the new font
	definefont pop
}
def

% text painting operators
/tr					% string tr ax ay string 
{
_ax _ay 3 2 roll
} def
/trj				% string trj cx cy fillchar ax ay string 
{
_cx _cy _sp _ax _ay 6 5 roll
} def

/a0
{
/Tx	% text							% textString Tx -
	{
	dup 
	currentpoint 3 2 roll
	tr _psf
	newpath moveto
	tr _ctm _pss
	} ddef
/Tj	% justified text				% textString Tj -
	{
	dup
	currentpoint 3 2 roll
	trj _pjsf
	newpath moveto
	trj _ctm _pjss
	} ddef
	
} def
/a1
{
/Tx	% text							% textString Tx -
	{
	dup currentpoint 4 2 roll gsave
	dup currentpoint 3 2 roll
	tr _psf
	newpath moveto
	tr _ctm _pss
	grestore 3 1 roll moveto tr sp
	} ddef
/Tj	% justified text				% textString Tj -
	{
	dup currentpoint 4 2 roll gsave
	dup currentpoint 3 2 roll
	trj _pjsf
	newpath moveto
	trj _ctm _pjss
	grestore 3 1 roll moveto tr sp
	} ddef
	
} def

/e0
{
/Tx	% text							% textString Tx -
	{
	tr _psf
	} ddef
/Tj	% justified text				% textString Tj -
	{
	trj _pjsf
	} ddef
} def

/e1
{
/Tx	% text							% textString Tx -
	{
	dup currentpoint 4 2 roll gsave 
	tr _psf  
	grestore 3 1 roll moveto tr sp 
	} ddef
/Tj	% justified text				% textString Tj -
	{
	dup currentpoint 4 2 roll gsave 
	trj _pjsf
	grestore 3 1 roll moveto tr sp 
	} ddef
} def

/i0
{
/Tx	% text							% textString Tx -
	{
	tr sp
	} ddef
/Tj	% justified text				% textString Tj -
	{
	trj jsp
	} ddef
} def

/i1
{
W N
} def

/o0
{
/Tx	% text							% textString Tx -
	{
	tr sw rmoveto
	} ddef
/Tj	% justified text				% textString Tj -
	{
	trj swj rmoveto
	} ddef
} def

/r0
{
/Tx	% text							% textString Tx -
	{
	tr _ctm _pss
	} ddef
/Tj	% justified text				% textString Tj -
	{
	trj _ctm _pjss
	} ddef
} def

/r1
{
/Tx	% text							% textString Tx -
	{
	dup currentpoint 4 2 roll currentpoint gsave newpath moveto
	tr _ctm _pss 
	grestore 3 1 roll moveto tr sp 
	} ddef
/Tj	% justified text				% textString Tj -
	{
	dup currentpoint 4 2 roll currentpoint gsave newpath moveto
	trj _ctm _pjss
	grestore 3 1 roll moveto tr sp 
	} ddef
} def

% font operators

% Binding
/To	% begin text 					% bindType To -
{
	pop _ctm currentmatrix pop
} def

/TO	% end text					% TO -
{
	Te _ctm setmatrix newpath
} def

% Text paths
/Tp	% begin text path				% a b c d tx ty startPt Tp -
{
	pop _tm astore pop _ctm setmatrix 
	_tDict begin /W {} def /h {} def
} def

/TP	% end text path					% TP -
{
	end
	iTm 0 0 moveto
} def

% Render mode & matrix operators
/Tr	% begin render					% render Tr - 
{
	_render 3 le {currentpoint newpath moveto} if
	dup 8 eq {pop 0} {dup 9 eq {pop 1} if} ifelse
	dup /_render exch ddef
	_renderStart exch get load exec
} def

/iTm % internal set text matrix		% - iTm -	(uses _tm as implicit argument)
{
_ctm setmatrix _tm concat 0 _rise translate _hs 1 scale
} def

/Tm % set text matrix				% a b c d tx ty Tm -
{
_tm astore pop iTm 0 0 moveto
} def

/Td % translate text matrix 		% tx ty Td -
{
_mtx translate _tm _tm concatmatrix pop iTm 0 0 moveto
} def

/Te	% end render					% - Te -
{
	_render -1 eq {} {_renderEnd _render get dup null ne {load exec} {pop} ifelse} ifelse
	/_render -1 ddef
} def


% Attributes
/Ta	% set alignment					% alignment Ta -
{
pop
} def

/Tf	% set font name and size		% fontname size Tf -
{
dup 1000 div /_fScl exch ddef
exch findfont exch scalefont setfont
} def

/Tl	% set leading					% leading paragraphLeading Tl -
{
pop
0 exch _leading astore pop
} def

/Tt	% set user tracking				% userTracking Tt -
{
pop
} def

/TW % set word spacing				% minSpace optSpace maxSpace TW -
{
3 npop
} def

/Tw	% set computed word spacing		% wordSpace Tw
{
/_cx exch ddef
} def

/TC % set character spacing			% minSpace optSpace maxSpace TC -
{
3 npop
} def

/Tc	% set computed char spacing 	% charSpace Tc -
{
/_ax exch ddef
} def

/Ts % set super/subscripting (rise)	% rise Ts -
{
/_rise exch ddef
currentpoint
iTm
moveto
} def

/Ti	% set indentation				% firstStartIndent otherStartIndent stopIndent Ti -
{
3 npop
} def

/Tz % set horizontal scaling		% scalePercent Tz -
{
100 div /_hs exch ddef
iTm
} def

/TA % set pairwise kerning			% autoKern TA -
									%	autoKern = 0 -> no pair kerning
									%			 = 1 -> automatic pair kerning
{
pop
} def

/Tq % set hanging quotes			% hangingQuotes Tq -
									%	hangingQuotes 	= 0 -> no hanging quotes
									%			 		= 1 -> hanging quotes
{
pop
} def


% Text Bodies
/TX {pop} def

%/Tx	% non-justified text			% textString Tx -
%/Tj	% justified text				% textString Tj -

/Tk	% kern							% autoKern kernValue Tk -
									%  	autoKern = 0 -> manual kern, = 1 -> auto kern
									%	kernValue = kern value in em/1000 space
{
exch pop _fScl mul neg 0 rmoveto
} def
/TK	% non-printing kern				% autoKern kernValue TK -
{
2 npop
} def

/T* % carriage return & line feed	% - T* -
{
_leading aload pop neg Td
} def

/T*- % carriage return & negative line feed	% - T*- -
{
_leading aload pop Td
} def

/T-	% print a discretionary hyphen	% - T- -
{
_hyphen Tx
} def

/T+	% discretionary hyphen hyphen	% - T+ -
{} def

/TR	% reset pattern matrix 			% a b c d tx ty TR -
{
_ctm currentmatrix pop 	
_tm astore pop 
iTm 0 0 moveto 
} def

/TS	% special chars					% textString justified TS -
{
0 eq {Tx} {Tj} ifelse
} def

currentdict readonly pop end
setpacking

%%EndResource

%%BeginResource: procset Adobe_pattern_AI3 1.1 0
%%Title: (Adobe Illustrator (R) Version 3.0 Pattern Operators)
%%Version: 1.1 0
%%CreationDate: (7/21/89) ()
%%Copyright: ((C) 1987-1996 Adobe Systems Incorporated All Rights Reserved)
currentpacking true setpacking
userdict /Adobe_pattern_AI3 16 dict dup begin put
/initialize
{
/definepattern where
        {
        pop
        }
        {
        Adobe_pattern_AI3 begin
        Adobe_pattern_AI3
                {
                dup xcheck
                        {
                        bind
                        } if
                pop pop
                } forall
        mark
        cachestatus 7 1 roll pop pop pop pop exch pop exch
                {
                {
                10000 add
                dup 2 index gt
                        {
                        exit
                        } if
                dup setcachelimit
                } loop
                } stopped
        cleartomark
        } ifelse
} def
/terminate
{
currentdict Adobe_pattern_AI3 eq
        {
 end
        } if
} def
errordict
/nocurrentpoint
{
pop
stop
} put
errordict
/invalidaccess
{
pop
stop
} put
/patternencoding
256 array def
0 1 255
{
patternencoding exch ( ) 2 copy exch 0 exch put cvn put
} for
/definepattern
{
17 dict begin
/uniform exch def
/cache exch def
/key exch def
/procarray exch def
/mtx exch matrix invertmatrix def
/height exch def
/width exch def
/ctm matrix currentmatrix def
/ptm matrix def
/str 32 string def
/slice 9 dict def
slice /s 1 put
slice /q 256 procarray length div sqrt floor cvi put
slice /b 0 put
/FontBBox [0 0 0 0] def
/FontMatrix mtx matrix copy def
/Encoding patternencoding def
/FontType 3 def
/BuildChar
        {
        exch
 begin
        /setstrokeadjust where {pop true setstrokeadjust} if
        slice begin
        dup q dup mul mod s idiv /i exch def
        dup q dup mul mod s mod /j exch def
        q dup mul idiv procarray exch get
        /xl j width s div mul def
        /xg j 1 add width s div mul def
        /yl i height s div mul def
        /yg i 1 add height s div mul def
        uniform
                {
                1 1
                }
                {
                width 0 dtransform
                dup mul exch dup mul add sqrt dup 1 add exch div
                0 height dtransform
                dup mul exch dup mul add sqrt dup 1 add exch div
                } ifelse
        width 0 cache
                {
                xl 4 index mul yl 4 index mul xg 6 index mul yg 6 index mul
                setcachedevice
                }
                {
                setcharwidth
                } ifelse
        gsave
        scale
        newpath
        xl yl moveto
        xg yl lineto
        xg yg lineto
        xl yg lineto
        closepath
        clip
        newpath
 end
 end
        exec
        grestore
        } def
key currentdict definefont
end
} def
/patterncachesize
{
gsave
newpath
0 0 moveto
width 0 lineto
width height lineto
0 height lineto
closepath
patternmatrix setmatrix
pathbbox
exch ceiling 4 -1 roll floor sub 3 1 roll
ceiling exch floor sub
mul 1 add
grestore
} def
/patterncachelimit
{
cachestatus 7 1 roll 6 npop 8 mul
} def
/patternpath
{
exch dup begin setfont
ctm setmatrix
concat
slice exch /b exch slice /q get dup mul mul put
FontMatrix concat
uniform
        {
        width 0 dtransform round width div exch round width div exch
        0 height dtransform round height div exch height div exch
        0 0 transform round exch round exch
        ptm astore setmatrix
        }
        {
        ptm currentmatrix pop
        } ifelse
{currentpoint} stopped not
        {
        2 npop
        pathbbox
        true
        4 index 3 index eq
        4 index 3 index eq
        and
                {
                pop false
                        {
                        {2 npop}
                        {3 npop true}
                        {7 npop true}
                        {pop true}
                        pathforall
                        } stopped
                        {
                        5 npop true
                        } if
                } if
                {
                height div ceiling height mul 4 1 roll
                width div ceiling width mul 4 1 roll
                height div floor height mul 4 1 roll
                width div floor width mul 4 1 roll
                2 index sub height div ceiling cvi exch
                3 index sub width div ceiling cvi exch
                4 2 roll moveto
                FontMatrix mtx invertmatrix
                dup dup 4 get exch 5 get rmoveto
                ptm ptm concatmatrix pop
                slice /s
                patterncachesize patterncachelimit div ceiling sqrt ceiling cvi
                dup slice /q get gt
                        {
                        pop slice /q get
                        } if
                put
                0 1 slice /s get dup mul 1 sub
                        {
                        slice /b get add
                        gsave
                        0 1 str length 1 sub
                                {
                                str exch 2 index put
                                } for
                        pop
                        dup
                                {
                                gsave
                                ptm setmatrix
                                1 index str length idiv {str show} repeat
                                1 index str length mod str exch 0 exch getinterval show
                                grestore
                                0 height rmoveto
                                } repeat
                        grestore
                        } for
                2 npop
                }
                {
                4 npop
                } ifelse
        } if
end
} def
/patternclip
{
clip
} def
/patternstrokepath
{
strokepath
} def
/patternmatrix
matrix def
/patternfill
{
dup type /dicttype eq
        {
        Adobe_pattern_AI3 /patternmatrix get
        } if
gsave
patternclip
Adobe_pattern_AI3 /patternpath get exec
grestore
newpath
} def
/patternstroke
{
dup type /dicttype eq
        {
        Adobe_pattern_AI3 /patternmatrix get
        } if
gsave
patternstrokepath
true
        {
                {
                        {
                        newpath 
                        moveto
                        }
                        {
                        lineto
                        }
                        {
                        curveto
                        }
                        {
                        closepath
                        3 copy
                        Adobe_pattern_AI3 /patternfill get exec
                        } pathforall
                3 npop
                } stopped
                        {
                        5 npop
                        patternclip
                        Adobe_pattern_AI3 /patternfill get exec
                        } if
        }
        {
        patternclip
        Adobe_pattern_AI3 /patternfill get exec
        } ifelse
grestore
newpath
} def
/patternashow
{
3 index type /dicttype eq
        {
        Adobe_pattern_AI3 /patternmatrix get 4 1 roll
        } if
        {
        2 npop (0) exch
        2 copy 0 exch put pop
        gsave
        false charpath currentpoint
        6 index 6 index 6 index
        Adobe_pattern_AI3 /patternfill get exec
        grestore
        newpath moveto
        2 copy rmoveto
        } exch cshow
5 npop
} def
/patternawidthshow
{
6 index type /dicttype eq
        {
        Adobe_pattern_AI3 /patternmatrix get 7 1 roll
        } if
        {
        2 npop (0) exch
        2 copy 0 exch put 
        gsave
        _sp eq {5 index 5 index rmoveto} if
        false charpath currentpoint
        9 index 9 index 9 index
        Adobe_pattern_AI3 /patternfill get exec
        grestore
        newpath moveto
        2 copy rmoveto
        } exch cshow
8 npop
} def
/patternashowstroke
{
4 index type /dicttype eq
        {
        patternmatrix /patternmatrix get 5 1 roll
        } if
4 1 roll
        {
        2 npop (0) exch
        2 copy 0 exch put pop
        gsave
        false charpath
        currentpoint
        4 index setmatrix
        7 index 7 index 7 index
        Adobe_pattern_AI3 /patternstroke get exec
        grestore
        newpath moveto
        2 copy rmoveto
        } exch cshow
6 npop
} def
/patternawidthshowstroke
{
7 index type /dicttype eq
        {
        patternmatrix /patternmatrix get 8 1 roll
        } if
7 1 roll
        {
        2 npop (0) exch
        2 copy 0 exch put
        gsave
        _sp eq {5 index 5 index rmoveto} if
        false charpath currentpoint
        7 index setmatrix
        10 index 10 index 10 index
        Adobe_pattern_AI3 /patternstroke get exec
        grestore
        newpath moveto
        2 copy rmoveto
        } exch cshow
9 npop
} def
currentdict readonly pop end
setpacking
%%EndResource

%%BeginResource: procset Adobe_IllustratorA_AI3 1.0 1
%%Title: (Adobe Illustrator (R) Version 3.0 Abbreviated Prolog)
%%Version: 1.0 
%%CreationDate: (7/22/89) ()
%%Copyright: ((C) 1987-1990 Adobe Systems Incorporated All Rights Reserved)

currentpacking true setpacking
userdict /Adobe_IllustratorA_AI3 61 dict dup begin put
% initialization
/initialize				% - initialize -
{
% 47 vars, but leave slack of 10 entries for custom Postscript fragments
userdict /Adobe_IllustratorA_AI3_vars 57 dict dup begin put

% paint operands
/_lp /none def
/_pf {} def
/_ps {} def
/_psf {} def
/_pss {} def
/_pjsf {} def
/_pjss {} def
/_pola 0 def
/_doClip 0 def

% paint operators
/cf	currentflat def	% - cf flatness

% typography operands
/_tm matrix def
/_renderStart [/e0 /r0 /a0 /o0 /e1 /r1 /a1 /i0] def 
/_renderEnd [null null null null /i1 /i1 /i1 /i1] def
/_render -1 def
/_rise 0 def
/_ax 0 def			% x character spacing	(_ax, _ay, _cx, _cy follows awidthshow naming convention)
/_ay 0 def			% y character spacing
/_cx 0 def			% x word spacing
/_cy 0 def			% y word spacing
/_leading [0 0] def
/_ctm matrix def
/_mtx matrix def
/_sp 16#020 def
/_hyphen (-) def
/_fScl 0 def
/_cnt 0 def
/_hs 1 def
/_nativeEncoding 0 def
/_useNativeEncoding 0 def
/_tempEncode 0 def
/_pntr 0 def
/_tDict 2 dict def

% typography operators
/Tx {} def
/Tj {} def

% compound path operators
/CRender {} def

% printing
/_AI3_savepage {} def

% color operands
/_gf null def
/_cf 4 array def
/_if null def
/_of false def
/_fc {} def
/_gs null def
/_cs 4 array def
/_is null def
/_os false def
/_sc {} def
/_i null def
Adobe_IllustratorA_AI3 begin
Adobe_IllustratorA_AI3
	{
	dup xcheck
		{
		bind
		} if
	pop pop
	} forall
end
end
Adobe_IllustratorA_AI3 begin
Adobe_IllustratorA_AI3_vars begin
newpath
} def
/terminate				% - terminate -
{
end
end
} def
% definition operators
/_					% - _ null
null def
/ddef				% key value ddef -
{
Adobe_IllustratorA_AI3_vars 3 1 roll put
} def
/xput				% key value literal xput -
{
dup load dup length exch maxlength eq
	{
	dup dup load dup
	length 2 mul dict copy def
	} if
load begin def end
} def
/npop				% integer npop -
{
	{
	pop
	} repeat
} def
% marking operators
/sw					% ax ay string sw x y 
{
dup length exch stringwidth
exch 5 -1 roll 3 index 1 sub mul add
4 1 roll 3 1 roll 1 sub mul add
} def
/swj				% cx cy fillchar ax ay string swj x y
{
dup 4 1 roll
dup length exch stringwidth 
exch 5 -1 roll 3 index 1 sub mul add
4 1 roll 3 1 roll 1 sub mul add 
6 2 roll /_cnt 0 ddef
{1 index eq {/_cnt _cnt 1 add ddef} if} forall pop
exch _cnt mul exch _cnt mul 2 index add 4 1 roll 2 index add 4 1 roll pop pop
} def
/ss					% ax ay string matrix ss -
{
4 1 roll
	{				% matrix ax ay char 0 0 {proc} -
	2 npop 
	(0) exch 2 copy 0 exch put pop
	gsave
	false charpath currentpoint
	4 index setmatrix
	stroke
	grestore
	moveto
	2 copy rmoveto
	} exch cshow
3 npop
} def
/jss				% cx cy fillchar ax ay string matrix jss -
{
4 1 roll
	{				% cx cy fillchar matrix ax ay char 0 0 {proc} -   
	2 npop 
	(0) exch 2 copy 0 exch put 
	gsave
	_sp eq 
		{
		exch 6 index 6 index 6 index 5 -1 roll widthshow  
		currentpoint
		}
		{
		false charpath currentpoint
		4 index setmatrix stroke
		}ifelse
	grestore
	moveto
	2 copy rmoveto
	} exch cshow
6 npop
} def

% path operators
/sp					% ax ay string sp -
{
	{
	2 npop (0) exch
	2 copy 0 exch put pop
	false charpath
	2 copy rmoveto
	} exch cshow
2 npop
} def
/jsp					% cx cy fillchar ax ay string jsp -
{
	{					% cx cy fillchar ax ay char 0 0 {proc} -
	2 npop 
	(0) exch 2 copy 0 exch put 
	_sp eq 
		{
		exch 5 index 5 index 5 index 5 -1 roll widthshow  
		}
		{
		false charpath
		}ifelse
	2 copy rmoveto
	} exch cshow
5 npop
} def

% path construction operators
/pl				% x y pl x y
{
transform
0.25 sub round 0.25 add exch
0.25 sub round 0.25 add exch
itransform
} def
/setstrokeadjust where
	{
	pop true setstrokeadjust
	/c				% x1 y1 x2 y2 x3 y3 c -
	{
	curveto
	} def
	/C
	/c load def
	/v				% x2 y2 x3 y3 v -
	{
	currentpoint 6 2 roll curveto
	} def
	/V
	/v load def
	/y				% x1 y1 x2 y2 y -
	{
	2 copy curveto
	} def
	/Y
	/y load def
	/l				% x y l -
	{
	lineto
	} def
	/L
	/l load def
	/m				% x y m -
	{
	moveto
	} def
	}
	{%else
	/c
	{
	pl curveto
	} def
	/C
	/c load def
	/v
	{
	currentpoint 6 2 roll pl curveto
	} def
	/V
	/v load def
	/y
	{
	pl 2 copy curveto
	} def
	/Y
	/y load def
	/l
	{
	pl lineto
	} def
	/L
	/l load def
	/m
	{
	pl moveto
	} def
	}ifelse

% graphic state operators
/d					% array phase d -
{
setdash
} def
/cf	{} def			% - cf flatness
/i					% flatness i -
{
dup 0 eq
	{
	pop cf
	} if
setflat
} def
/j					% linejoin j -
{
setlinejoin
} def
/J					% linecap J -
{
setlinecap
} def
/M					% miterlimit M -
{
setmiterlimit
} def
/w					% linewidth w -
{
setlinewidth
} def

% path painting operators
/H					% - H -
{} def
/h					% - h -
{
closepath
} def
/N					% - N -
{
_pola 0 eq 
	{
	_doClip 1 eq {clip /_doClip 0 ddef} if 
	newpath
	} 
	{
	/CRender {N} ddef
	}ifelse
} def
/n					% - n -
{N} def
/F					% - F -
{
_pola 0 eq 
	{
	_doClip 1 eq 
		{
		gsave _pf grestore clip newpath /_lp /none ddef _fc 
		/_doClip 0 ddef
		}
		{
		_pf
		}ifelse
	} 
	{
	/CRender {F} ddef
	}ifelse
} def
/f					% - f -
{
closepath
F
} def
/S					% - S -
{
_pola 0 eq 
	{
	_doClip 1 eq 
		{
		gsave _ps grestore clip newpath /_lp /none ddef _sc 
		/_doClip 0 ddef
		}
		{
		_ps
		}ifelse
	} 
	{
	/CRender {S} ddef
	}ifelse
} def
/s					% - s -
{
closepath
S
} def
/B					% - B -
{
_pola 0 eq 
	{
	_doClip 1 eq 	% F clears _doClip
	gsave F grestore 
		{
		gsave S grestore clip newpath /_lp /none ddef _sc
		/_doClip 0 ddef
		} 
		{
		S
		}ifelse
	}
	{
	/CRender {B} ddef
	}ifelse
} def
/b					% - b -
{
closepath
B
} def
/W					% - W -
{
/_doClip 1 ddef
} def
/*					% - [string] * -
{
count 0 ne 
	{
	dup type (stringtype) eq {pop} if
	} if 
_pola 0 eq {newpath} if
} def

% group operators
/u					% - u -
{} def
/U					% - U -
{} def
/q					% - q -
{
_pola 0 eq {gsave} if
} def
/Q					% - Q -
{
_pola 0 eq {grestore} if
} def
/*u					% - *u -
{
_pola 1 add /_pola exch ddef
} def
/*U					% - *U -
{
_pola 1 sub /_pola exch ddef 
_pola 0 eq {CRender} if
} def
/D					% polarized D -
{pop} def
/*w					% - *w -
{} def
/*W					% - *W -
{} def

% place operators
/`					% matrix llx lly urx ury string ` -
{
/_i save ddef
6 1 roll 4 npop
concat
userdict begin
/showpage {} def
false setoverprint
pop
} def
/~					% - ~ -
{
end
_i restore
} def

% color operators
/O					% flag O -
{
0 ne
/_of exch ddef
/_lp /none ddef
} def
/R					% flag R -
{
0 ne
/_os exch ddef
/_lp /none ddef
} def
/g					% gray g -
{
/_gf exch ddef
/_fc
{ 
_lp /fill ne
	{
	_of setoverprint
	_gf setgray
	/_lp /fill ddef
	} if
} ddef
/_pf
{
_fc
fill
} ddef
/_psf
{
_fc
ashow
} ddef
/_pjsf
{
_fc
awidthshow
} ddef
/_lp /none ddef
} def
/G					% gray G -
{
/_gs exch ddef
/_sc
{
_lp /stroke ne
	{
	_os setoverprint
	_gs setgray
	/_lp /stroke ddef
	} if
} ddef
/_ps
{
_sc
stroke
} ddef
/_pss
{
_sc
ss
} ddef
/_pjss
{
_sc
jss
} ddef
/_lp /none ddef
} def
/k					% cyan magenta yellow black k -
{
_cf astore pop
/_fc
{
_lp /fill ne
	{
	_of setoverprint
	_cf aload pop setcmykcolor
	/_lp /fill ddef
	} if
} ddef
/_pf
{
_fc
fill
} ddef
/_psf
{
_fc
ashow
} ddef
/_pjsf
{
_fc
awidthshow
} ddef
/_lp /none ddef
} def
/K					% cyan magenta yellow black K -
{
_cs astore pop
/_sc
{
_lp /stroke ne
	{
	_os setoverprint
	_cs aload pop setcmykcolor
	/_lp /stroke ddef
	} if
} ddef
/_ps
{
_sc
stroke
} ddef
/_pss
{
_sc
ss
} ddef
/_pjss
{
_sc
jss
} ddef
/_lp /none ddef
} def
/x					% cyan magenta yellow black name gray x -
{
/_gf exch ddef
findcmykcustomcolor
/_if exch ddef
/_fc
{ 
_lp /fill ne
	{
	_of setoverprint
	_if _gf 1 exch sub setcustomcolor
	/_lp /fill ddef
	} if
} ddef
/_pf
{
_fc
fill
} ddef
/_psf
{
_fc
ashow
} ddef
/_pjsf
{
_fc
awidthshow
} ddef
/_lp /none ddef
} def
/X					% cyan magenta yellow black name gray X -
{
/_gs exch ddef
findcmykcustomcolor
/_is exch ddef
/_sc
{
_lp /stroke ne
	{
	_os setoverprint
	_is _gs 1 exch sub setcustomcolor
	/_lp /stroke ddef
	} if
} ddef
/_ps
{
_sc
stroke
} ddef
/_pss
{
_sc
ss
} ddef
/_pjss
{
_sc
jss
} ddef
/_lp /none ddef
} def

% locked object operator
/A					% value A -
{
pop
} def

currentdict readonly pop end
setpacking

% annotate page operator
/annotatepage
{
} def
%%EndResource
%AI3-Grid.0 18 18 3 0 0 0 3
%%EndProlog
%%BeginSetup
%%IncludeFont: Reporter-Two
Adobe_cmykcolor /initialize get exec
Adobe_cshow /initialize get exec
Adobe_customcolor /initialize get exec
Adobe_pattern_AI3 /initialize get exec
Adobe_typography_AI3 /initialize get exec
Adobe_IllustratorA_AI3 /initialize get exec
%%EndSetup
