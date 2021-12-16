{smcl}
{* *! version 0.1  15.12.2021}

{viewerjumpto "Syntax" "cbdata##syntax"}{...}
{viewerjumpto "Description" "cbdata##description"}{...}
{viewerjumpto "Options" "cbdata##options"}{...}
{viewerjumpto "Examples" "cbdata##examples"}{...}
{viewerjumpto "Author" "cbdata##author"}{...}

{title:Title}

{phang}
{bf:cbdata} {hline 2} Prepare data for codebook

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:cbdata} [{cmd:using} {it:{help filename}}], [{cmdab:ls:path(}{it:string}{cmd:)}
{cmd:lsonly} {cmd:save(}{it:string}{cmd:)} {cmd:replace} {cmd:panel}
{cmdab:lang:uage(}{it:string}{cmd:)}]


{synoptset 17}{...}
{marker cbdata_options}{...}
{synopthdr :options}
{synoptline}
{synopt:{opt ls:path()}}define folder of LimeSurvey survey file(s){p_end}
{synopt:{opt lsonly}}use just LimeSurvey survey file{p_end}
{synopt:{opt save()}}path and name of output file{p_end}
{synopt:{opt replace}}overwrite existing output file{p_end}
{synopt:{opt lang:uage()}}keep selected questionnaire language{p_end}
{synopt:{opt noa:uto()}}suppress autodetection of connected variable names{p_end}
{synopt:{opt var:pre()}}define list of prefixes of connected variable names{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}{cmd:cbdata} creates a dataset that can be used to create a codebook with
{it:{help cbout}}. There are three possibilities of which data source the
dataset can be generated from:{p_end}
{pstd}{p_end}

{p 8 8 2}1. Stata memory or .dta/.xls(x)-file only:{p_end}
{p 12 12 2}Use data in memory or define a {it:{help filename}} with using{p_end}
{pstd}{p_end}

{p 8 8 2}2. LimeSurvey .txt structure file(s):{p_end}
{p 12 12 2}Choose the folder that containts the LS structure files with
{opt ls:path()} and define option {opt lsonly}. Multiple LS files are treated as
parts of a single survey.{p_end}
{pstd}{p_end}

{p 8 8 2}3. Combine Stata memory/.dta/.xls(x) and LimeSurvey .txt structure file:{p_end}
{p 12 12 2}Use data in memory or define a {it:{help filename}} with using and
choose the folder that containts the LS structure files with {opt ls:path()}.
Variables are merged with their names, so they should not be changed.{p_end}

{marker options_cbdata}{...}
{title:Options for cbdata}

{phang}{opt save()}

{phang}{opt replace}


{phang}{opt ls:path()}

{phang}{opt lsonly}

{phang}{opt var:stub} pay attention to order of varstubs -> finds via
regular expressions, shorter forms are in longer varnames -> change order in option

stata trys to find subvars when name of variables around are the same except
the last character and same amount of answers -> auto detect per default -> option NOAUTO:detect

if more subvars than 9 (count switch from 9 - 10), auto detect can't find all, needs to be specified
given stubnames will overwright auto detect and also find variables they are next to each other


{phang}{opt lang:uage()}


{marker examples}{...}
{title:Examples}

{pstd}Overall workflow in combination with {cmd:cbdata} to prepare the data:{p_end}

{phang2}{cmd:. cbdata, lsdata("limesurvey_data")}{p_end}

{pstd}Add additional labels for the matrix and multiple choice variables
or notes:{p_end}

{phang2}{cmd:. replace label "Satisfaction" if variable == "sat"}{p_end}
{phang2}{cmd:. replace note "Not part of final data set" if variable == "ybirth"}{p_end}

{pstd}Use the data set in memory so save stand alone file with german labels:{p_end}

{phang2}{cmd:. cbtex, save(variables.tex) replace german clr(Gray!30)}{p_end}


{marker author}{...}
{title:Author}

{pstd}Stefan Munnes, {browse "mailto:munnes@wzb.eu":munnes@wzb.eu},
WZB - Social Science Center Berlin.{p_end}
{pstd}For additional information see
{browse "https://github.com/StefanMunnes/CodebookGenerator":Github.}{p_end}



other-Variables from Stata needs to be named the same + with other in the end
stonly -> if label -> tabulate, otherwise string or numeric
