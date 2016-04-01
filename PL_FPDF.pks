CREATE OR REPLACE PACKAGE PL_FPDF AS
/*******************************************************************************
* Logiciel : PL_FPDF                                                           *
* Version :  0.9.3                                                             *
* Date :     13/06/2006                                                        *
* Auteur :   Pierre-Gilles Levallois                                           *
* Licence :  GPL                                                               *
*                                                                              *
********************************************************************************
* Cette librairie PL/SQL est un portage de la version 1.53 de FPDF, célèbre    *
* classe PHP développée par Olivier PLATHEY (http://www.fpdf.org/)             *
********************************************************************************
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
********************************************************************************/
-- Public types and subtypes.
subtype word is varchar2(80);

type tv4000a is table of varchar2(4000) index by word;

--Point type use in polygons creation
type point is record (x number, y number);

type tab_points is table of point index by pls_integer;

-- Constantes globales
FPDF_VERSION constant varchar2(10) := '1.53'; 
PL_FPDF_VERSION constant varchar2(10) := '0.9.3'; 
noParam tv4000a;

-- methods added to FPDF
function GetCurrentFontSize return number;
function GetCurrentFontStyle return varchar2;
function GetCurrentFontFamily return varchar2;
procedure SetDash(pblack in number default 0, pwhite in number default 0);
function GetLineSpacing return number;
Procedure SetLineSpacing (pls in number);
-- Allows to create a polygon with a table of points
-- pclose define if the polygon is closed or not
procedure Poly(points in tab_points, pclose in boolean, pstyle in varchar2 default '');
procedure Triangle(px in number, py in number, psize in number, 
                   porientation in varchar2 default 'left', pstyle in varchar2 default '');

procedure SetLineDashPattern(pdash in varchar2 default '[] 0');

-- FPDF public methods
procedure Ln(h number default null);
function  GetX return number;
procedure SetX(px in number);
function  GetY return number;
procedure SetY(py in number);
procedure SetXY(x in number,y in number);
procedure SetHeaderProc(headerprocname in varchar2, paramTable tv4000a default noParam);
procedure SetFooterProc(footerprocname in varchar2, paramTable tv4000a default noParam);
procedure SetMargins(left in number, top in number, right in number default -1);
procedure SetLeftMargin(pMargin in number);
procedure SetTopMargin(pMargin in number);
procedure SetRightMargin(pMargin in number);
procedure SetAutoPageBreak(pauto in boolean, pMargin in number default 0);
procedure SetDisplayMode(zoom in varchar2, layout in varchar2 default 'continuous');
procedure SetCompression(p_compress in boolean default false);
procedure SetTitle(ptitle in varchar2);
procedure SetSubject(psubject in varchar2);
procedure SetAuthor(pauthor in varchar2);
procedure SetKeywords(pkeywords in varchar2);
procedure SetCreator(pcreator in varchar2);
procedure SetAliasNbPages(palias in varchar2 default '{nb}');
procedure Header;
procedure Footer;
function  PageNo return number;
procedure SetDrawColor(r in number, g in number default -1, b in number default -1);
procedure SetFillColor (r in number, g in number default -1, b in number default -1);
procedure SetTextColor (r in number, g in number default -1, b in number default -1);
procedure SetLineWidth(width in number);
procedure Line(x1 in number, y1 in number, x2 in number, y2 in number);
procedure Rect(px in number, py in number, pw in number, ph in number, pstyle in varchar2 default '');
function  AddLink return number;
procedure SetLink(plink in number, py in number default 0, ppage in number default -1);
procedure Link(px in number, py in number, pw in number, ph in number, plink in varchar2);
procedure Text(px in number, py in number, ptxt in varchar2);
function  AcceptPageBreak return boolean;
procedure AddFont (family in varchar2, style in varchar2 default '', filename in varchar2 default '');
procedure SetFont(pfamily in varchar2,pstyle in varchar2 default '', psize in number default 0);
function GetStringWidth(pstr in varchar2) return number;
procedure SetFontSize(psize in number);
procedure Cell
		 (pw in number,
		  ph in number default 0,
		  ptxt in varchar2 default '',
		  pborder in varchar2 default '0',
		  pln in number default 0,
		  palign in varchar2 default '',
		  pfill in number default 0,
		  plink in varchar2 default '');
--Now return the number of line created with multiCell
function MultiCell
  ( pw in number,
    ph in number default 0,
	ptxt in varchar2,
	pborder in varchar2 default '0',
	palign in varchar2 default 'J',
	pfill in number default 0,
	phMax in number default 0) return number;

procedure MultiCell
  ( pwidth in number,
    pheight in number default 0,
    ptext in varchar2,
    pbrdr in varchar2 default '0',
    palignment in varchar2 default 'J',
    pfillin in number default 0,
    phMaximum in number default 0);
    
procedure Write(pH in varchar2, ptxt in varchar2, plink in varchar2 default null);
procedure image ( pFile in varchar2, 
		  		pX in number, 
				  pY in number, 
				  pWidth in number default 0,
				  pHeight in number default 0,
				  pType in varchar2 default null,
				  pLink in varchar2 default null);
				  
procedure Output(pname in varchar2 default null, pdest in varchar2 default null);

procedure OpenPDF;
procedure ClosePDF;
procedure AddPage(orientation in varchar2 default '');
procedure fpdf  (orientation in varchar2 default 'P', unit in varchar2 default 'mm', format in varchar2 default 'A4');
procedure Error(pmsg in varchar2);
procedure DebugEnabled;
procedure DebugDisabled;
function GetScaleFactor return number;
function getImageFromUrl(p_Url in varchar2) return ordsys.ordImage;

--
-- Sample codes.
--
procedure helloworld;
procedure testImg;
procedure test(pdest in varchar2 default 'D');
procedure MyRepetitiveHeader(param1 in varchar2, param2 in varchar2);
procedure MyRepetitiveFooter;
procedure testHeader;
--------------------------------------------------------------------------------
-- Affiche le numéro de page en base de page
--------------------------------------------------------------------------------
procedure lpc_footer;

END PL_FPDF;
/
