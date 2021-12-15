{smcl}
{* *! version 0.1  22nov2020}{...}
{viewerjumpto "Syntax" "cbdata##syntax"}{...}
{viewerjumpto "Description" "cbdata##description"}{...}
{viewerjumpto "Options" "cbdata##options"}{...}
{viewerjumpto "Examples" "cbdata##examples"}{...}
{viewerjumpto "Author" "cbdata##author"}{...}

{title:Title}

{phang}
{bf:cbdata} {hline 2} Prepare data of LimeSurvey (and Stata) for Codebook

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
{synopt:{opt ls:path( )}}define Folder of LimeSurvey survey file(s){p_end}
{synopt:{opt lsonly}}use just LimeSurvey survey file{p_end}
{synopt:{opt save( )}}path and name of output file{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt panel}}not ready{p_end}
{synopt:{opt lang:uage( )}}not ready{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}{cmd:cbdata} creates a data set from one or more LimeSurvey structure survey
files (and a Stata data set), which can be used to create a codebook with
{cmd: {help: cbtex}}.{p_end}
{pstd}If you don't define a {it:{help filename}}, the one in the memory will be
used. If you don't define a directory with the option {opt: lspath()} where the
LS files can be found, the working directory will be used.
If you choose the option {opt lsonly} the data set will be created just from
one or more LimeSurvey survey files. By default, multiple LS files are treated
as parts of a single survey. With the (panel) option, the single  files are
treated as separate survey waves to be marked as such in in the final
questionnaire and differences can be described.{p_end}
{pstd}{bf: Limitation} Variables are merged with their names,
so they should not be changed.{p_end}


other-Variables from Stata needs to be named the same + with other in the end


stonly -> if label -> tabulate, otherwise string or numeric


{marker options_cbdata}{...}
{title:Options for cbdata}

{phang}{opt ls:path( )}

{phang}{opt lsonly}

{phang}{opt var:stub} pay attention to order of varstubs -> finds via
regular expressions, shorter forms are in longer varnames -> change order in option

stata trys to find subvars when name of variables around are the same except
the last character and same amount of answers -> auto detect per default -> option NOAUTO:detect

if more subvars than 9 (count switch from 9 - 10), auto detect can't find all, needs to be specified
given stubnames will overwright auto detect and also find variables they are next to each other


{phang}{opt save( )}

{phang}{opt replace}

{phang}{opt panel}

{phang}{opt lang:uage( )}


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
