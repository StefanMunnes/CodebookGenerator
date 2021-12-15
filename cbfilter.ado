* version 0.1 2020-11-30 munnes@wzb.eu
* limesurvey data to table of filters in tex file
* imports limesurvey data and make table of dependecies and filters in tex file

program define cbfilter

syntax, LSpath(string) [save(string) replace german]

version 12

*-------------------------------------------------------------------------------

*** LimeSurvey data prep

* 1. load (multiple) limesurvey file(s)
if `"`lspath'"' == "" local lspath = "."
local lsfiles: dir `"`lspath'"' file "limesurvey_survey_*.txt"

local nfile = 0
foreach file of local lsfiles {

  display "`file'"

  local ++nfile

  if `"`lspath'"' == "." local pathfile = "`file'"
  else local pathfile = "`lspath'/`file'"

	import delimited "`pathfile'", clear ///
    delimiters("\t") encoding("UTF-8") stringcols(_all)

  // if panel, save number of order for wave report in codebook
  quietly: gen survey = `nfile' if `nfile' > 1

  tempfile lsdata`nfile'
  quietly: save `lsdata`nfile''
}

clear

forval i = 1/`nfile' {
	quietly: append using `lsdata`i''
}

*-------------------------------------------------------------------------------

// rename variables
rename name variable
rename relevance depends


// subvar = general variable name of matrix/multiple-answer variable for subvars
gen 		subvar = variable if inlist(typescale, "M", "F", "K")
replace subvar = subvar[_n - 1] if class == "SQ"

// add name of matrix or multipleanswer question to subvariables suffix
replace variable = subvar + variable if typescale == "0"


keep if inlist(class, "Q", "SQ")
keep class variable depends

*-------------------------------------------------------------------------------

quietly {

  // gen lssort to keep order of sub-variables later on
  gen lssort = _n


  * clean up filter arguments
  replace depends = "" if depends == "1" // if no question-filter, delete 1

  local count = 1
  while `count' > 0 {
    replace depends = ustrregexrf(depends, " Y", " 1 ")
    replace depends = ustrregexrf(depends, " N", " 0 ")
    replace depends = ustrregexrf(depends, "_", "")
    replace depends = ustrregexrf(depends, "&&", "and")
    replace depends = ustrregexrf(depends, "\(", "") ///
      if !regexm(depends, " or ")
    replace depends = ustrregexrf(depends, "\)", "") ///
      if !regexm(depends, " or ")
    replace depends = ustrregexrf(depends, ".NAOK", "")
    replace depends = ustrregexrf(depends, `"""', "")
    replace depends = ustrregexrf(depends, ".NAOK", "")

    count if ustrregexm(depends, `".NAOK|"|&&"') // \(+|
    local count = r(N)
  }

  replace depends = strtrim(depends)
}

*-------------------------------------------------------------------------------


gen filters1 = ""
gen filters2 = ""

//rename


local N: display _N
forval row = 1/`N' {

	local var: display variable[`row']

	local check = `N' - `row' + 1

	display "variable: `var', check: `check', row: `row', `N'"

	forval chkrow = 1/`check' {

		quietly: replace filters1 = filters1  + ///
      "\hbox{\strut " + variable[_n + `chkrow'] + "}" ///
			in `row' if regexm(depends[_n + `chkrow'], "`var'")
		quietly: replace filters2 = filters2  + ///
      "\hbox{\strut " + depends[_n + `chkrow'] + "}" ///
			in `row' if regexm(depends[_n + `chkrow'], "`var'")
	}
}

replace filters1 = "\vtop{" + filters1 + "}" if filters1 != ""
replace filters2 = "\vtop{" + filters2 + "}" if filters2 != ""


drop if depends == "" & filters1 == "" & filters2 == "" & class == "SQ"
drop if depends == "" & filters1 == "" & filters2 == "" & class[_n-1] != "SQ"

*-------------------------------------------------------------------------------

* start the tex document
capture: file close cb
file open cb using `"`save'"', write replace

file write cb `"\documentclass{article}"' _n
if `"`german'"' != "" file write cb `"\usepackage[ngerman]{babel}"' _n
file write cb `"\usepackage[utf8]{inputenc}"' _n
file write cb `"\usepackage[T1]{fontenc}"' _n
file write cb `"\usepackage{lmodern}"' _n
file write cb `"\usepackage[margin=1.5cm, includeheadfoot]{geometry}"' _n
file write cb `"\usepackage{booktabs}"' _n
file write cb `"\usepackage{xltabular}"' _n
if `"`clrtblrow'"' != "" file write cb `"\usepackage[table, dvipsnames]{xcolor}"' _n
file write cb `"\usepackage{underscore}"' _n
file write cb `"\setlength\parindent{0pt}"' _n(2)
file write cb `"\begin{document}"' _n(2)

if `"`clrtblrow'"' != "" file write cb "\rowcolors{2}{white}{`clrtblrow'}" _n
file write cb "\begin{xltabular}{\linewidth}{@{}llllX@{}}" _n
file write cb "\toprule" _n
file write cb "\multicolumn{2}{l}{\textbf{Variable}} & \textbf{Depends on} & \textbf{Filters} & \textbf{Condition} \\ \midrule \endfirsthead"  _n
file write cb "\multicolumn{2}{l}{\textbf{Variable}} & \textbf{Depends on} & \textbf{Filters} & \textbf{Condition} \\ \midrule \endhead"  _n

* loop over each row/variable
local max = _N
forvalues var = 1/`max' {

  local variable = variable[`var']
  local varclass = class[`var']
  local depends  = depends[`var']
  local filters1 = filters1[`var']
  local filters2 = filters2[`var']

  if "`varclass'" == "Q" {
    file write cb `"\midrule \multicolumn{2}{l}{`variable'} &"'
  }
  else {
    file write cb `"& `variable' &"'
  }
  file write cb `"`depends' & `filters1' & `filters2' \\"'
}

file write cb "\bottomrule" _n
file write cb "\end{xltabular}" _n
file write cb `"\end{document}"'

file close cb

end
