{smcl}
{* *! version 0.1  18nov2020}{...}
{viewerjumpto "Syntax" "cbout##syntax"}{...}
{viewerjumpto "Description" "cbout##description"}{...}
{viewerjumpto "Options" "cbout##options"}{...}
{viewerjumpto "Examples" "cbout##examples"}{...}
{viewerjumpto "Author" "cbout##author"}{...}

{title:Title}

{phang}
{bf:cbout} {hline 2} Write codebook as tex file from prepared data set

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:cbout} [{cmd:using} {it:{help filename}}], {cmd:save(}{it:string}{cmd:)}
[{cmd:replace} {cmd:lslab} {cmd:frag} {cmd:german}
{cmdab:clr:tblrow(}{it:string}{cmd:)} {cmd:tblmax(}{it:integer}{cmd:)}
{cmd:textno}]


{synoptset 17}{...}
{marker cbout_options}{...}
{synopthdr :options}
{synoptline}
{synopt:{opt save( )}}define filename and type of output{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt drop(varlist)}}suppress standard variable characteristics{p_end}
{synopt:{opt add(varlist)}}add addtitional variable characteristics{p_end}
{synopt:{opt lslab}}use the original labels from LimeSurvey{p_end}
{synopt:{opt frag}}produce only TeX fragment to include in main file{p_end}
{synopt:{opt german}}codebook labels in german language{p_end}
{synopt:{opt clr:tblrow(### ### ###)}}RGB color highlighting of the tables{p_end}
{synopt:{opt tblmax(#)}}set max length of value tables{p_end}
{synopt:{opt textno}}suppress text-only display{p_end}
{synopt:{opt titlepage}}adds titlepage with survy information{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:cbout} creates a codebook from the dataset in memory or specified by
{it:{help filename}} in LaTeX format. A dataset prepared by {cmd:{help cbdata}} is
necessary to have the correct format and all information.{p_end}
{pstd}By default a fully functional standalone file is created. With the {opt frag}
option, only a simple file is created, which the user can include in a more
complex tex file with additional information. In any case, the following LaTeX packages
are required {it:geometry}, {it:tabularx}, {it:booktabs}, {it:babel},
{it:xcolor} and {it:underscore}. {p_end}


{marker options_cbout}{...}
{title:Options for cbout}

{phang}
{opt save( )} needs a path and filename for the stored output file. The output
format is automatically selected via the necessary specification of the file
extension. You can choose between {bf:.tex}, {bf:.docx} or {bf:.pdf}.

{phang}
{opt replace} permits {opt save} to overwrite an existing dataset.

{phang}
{opt drop()} takes a {help varlist} of variable characteristics that should be
suppressed for the output. The default output characteristics are:
{it: lstype - Questiontype}, {it: filter - Filter}, {it: text - Questiontext},
{it: help - Helptext}, {it: other_replace_text - Open question},
{it: suffix - Suffix}, {it:random_group - Randomization group} and
{it: random-order - Random order}.

{phang}
{opt add()} takes an additional {help varlist} of variables to be presented
as a variable characteristics in the output, e.g. notes or source. Empty cells
for a variable are not displayed. A variable label in the desired language must
be added for display, otherwise the variable name will be used. By entering a
{help varlist}, the order can also be changed. Unnecessary variables can be
removed using the {opt drop()} option.

{phang}
{opt lslab} use just the original labels from LimeSurvey instead of Stata ones.
If no Stata dataset was used, this is the default setting.

{phang}
{opt frag} indicates if the tex file is saved only as a fragment to be inserted
by the user into a larger tex file. Otherwise the output file will be a fully
functional stand alone tex file with necessary informations in the header.
See {bf: Description} for necessary latex packages.

{phang}
{opt german} specifies all additional terms in the codebook in german language.
The default is english.

{phang}
{opt clrtblrow(### ### ###)} specifies which color the rows of the variable and
value tables should be colored. Must define a RGB code (### ## ###). The default
is a light grey. If the output format is .tex, no color change can
be considered with the {opt frag} option. Also the .pdf-Fromat don't support
colored output.

{phang}
{opt tblmax(#)} to avoid problems with over long value tables define a max length
of values to be reported. The default is 16 lines. Start and end are preserved,
the middle values are shortened away.

{phang}
{opt textno} text-only displays like intro, outro and variables with just shown
text will be suppressed.

{phang}
{opt titlepage} adds a titlepage to the codebook with information extracted
mostly from the LimeSurvey file. These information are the survey title (data label),
admin name (note 1), admin email (note 2), start date (note 3), end date (note 4)
and languages (note 5). The number of observations are extracted from the data file
if possible (note 6). It's possible to change the notes (also to empty) after cbdata
if you want different information to be reported (or not shown). Number of
question groups and variables are automatically counted.



{marker examples}{...}
{title:Examples}

{pstd}Overall workflow in combination with {cmd:cbdata} to prepare the data:{p_end}

{phang2}{cmd:. cbdata, lsdata("limesurvey_data")}{p_end}

{pstd}Add additional labels for the matrix and multiple choice variables
or notes:{p_end}

{phang2}{cmd:. replace label "Satisfaction" if variable == "sat"}{p_end}
{phang2}{cmd:. replace note "Not part of final data set" if variable == "ybirth"}{p_end}

{pstd}Use the data set in memory so save stand alone file with german labels:{p_end}

{phang2}{cmd:. cbout, save(variables.tex) replace german clr(Gray!30)}{p_end}


{marker author}{...}
{title:Author}

{pstd}Stefan Munnes, {browse "mailto:munnes@wzb.eu":munnes@wzb.eu},
WZB - Social Science Center Berlin.{p_end}
{pstd}For additional information see
{browse "https://github.com/StefanMunnes/CodebookGenerator":Github.}{p_end}
