* version 0.1 2020-11-17 munnes@wzb.eu
* limesurvey data and dta to data set for cbout
* imports limesurvey data combines with reformed stata data to prepare for cbout

program define cbdata, nclass

syntax [using/], [LSpath(string) LANGuage(string) lsonly ///
  save(string) replace panel ///
  varpre(string) NOAuto]

version 12

*-------------------------------------------------------------------------------

* error message if no using, empty dataset and not lsonly
quietly: count
if r(N) == 0 & `"`using'"' == "" & `"`lsonly'"' == "" {
  noi di in red `"no data specified; load a .dta-file, define {opt using} or use the option {opt lsonly}"'
  exit 198
}

* error message if using and lsonly
if `"`using'"' != "" & `"`lsonly'"' != "" {
  noi di in red `"there is no need to use a dataset if option {opt lsonly} is specified"'
  exit 198
}

* error message if lsonly and varpre
if `"`lsonly'"' != "" & `"`varpre'"' != "" {
  noi di in red `"the option {opt varpre} is only usefull when stata use only"'
  exit 198
}

* error message if file exists and replace not specified (ripped from dataout.ado)
cap confirm file `"`save'"'
if !_rc & "`replace'" != "replace" {
  noi di in red `"`save' already exists; specify {opt replace}"'
  exit 198
}

* add dat to using if not present
//if `"`using'"' != "" & !strmatch(`"`using'"', "\.dta$") local using = `"`using'.dta"'
//if `"`save'"'  != "" & !strmatch(`"`save'"', "\.dta$")  local save = `"`save'.dta"'

/* NEEDS TO BE TESTED
* error message if option panel but not multiple surveys
if `"`panel'"' != "" & "`survey_n'" == "1" {
  noi di in red `"option {opt panel} is just allowed if multiple files where prepared"'
  exit 198
} */

* add lspath to current directory if lsonly and in same folder
if `"`lsonly'"' != "" & `"`lspath'"' == "" local lspath = "."

*-------------------------------------------------------------------------------

// if option save file is specified, preserve to restore original data
if `"`save'"' != "" preserve

*-------------------------------------------------------------------------------

*** 1. Statistical data prep (if no lsonly)

if `"`lsonly'"' == "" {

  *** 1.1 load/import statistical data

  * if using .dta --> use Stata data
  if regexm(`"`using'"', "\.dta$") {

    display `"Load stata file: `using'"'

    use `"`using'"', clear
  }

  * if using .xlsx -> import excel-file and clean up
  if regexm(`"`using'"', "\.xlsx$") {

    display `"Import excel file: `using'"'

    import excel `"`using'"', clear firstrow allstring

    * drop help and structure variables from LimeSurvey
    capture: drop id
    capture: drop submitdate
    capture: drop lastpage
    capture: drop startlanguage
    capture: drop seed
    capture: drop token
    capture: drop startdate
    capture: drop datestamp

    * get rid of structure variables like interviewtime/questiontime
    quietly: d, varlist
    local lastvar: word `r(k)' of `r(varlist)'
    capture: drop interviewtime - `lastvar'

    * get rid of automaticly assigned variable labels
    foreach var of varlist _all {
      label var `var' ""
    }


    *** transform variables to get value labels and frequencies for categories

    quietly {

      * save order of variables for later sorting
      ds
      local var_order = r(varlist)

      foreach var of varlist * {

        * replace other categories -> as last value
        replace `var' = "zzzzz" if `var' == "-oth-"

        * filter out string variables
        capture: tab `var', nofreq
        if ///
          `r(r)' < 30 & /// not more than 50 unique values
          !regexm("`var'", "other$") & /// not other in the end of varname
          real(regexr("`: type `var''", "str", "")) < 10 { // max length of value

            encode `var', gen(`var'___str)
            drop `var'
            rename `var'___str `var'
        }

        * try to destring numeric variables (with more than 60 values)
        destring `var', replace
      }

      * order from saved varlist
      order `var_order'
    }
  }


  *** 1.2 create statistical data set (for stata data and raw excel file)

  * get number of observations for codebook
  global nobs = _N


  *** store variable & value labels and format/type of loaded statistical data
  mata: matLab = mata_getlabels()


  *** get variable statistics (freqs) and save as matrix
  matrix drop _all

  quietly {

    * 1. for numeric variables
    ds, not(type str# strL)

    if "`r(varlist)'" != "" {

      tabstat `r(varlist)', s(count mean sd min max) col(stat) save

      matrix matStat = r(StatTotal)
      matrix matStat = matStat'
    }
    else { // generate empty matrix to add strings if no numeric variables

      matrix matStat = J(1, 5, .)
      matrix colnames matStat = N mean sd min max
    }

    * 2. for string variables (not important for excel)
    ds, has(type str# strL)

    foreach var in `r(varlist)' {

      count if `var' != ""

      matrix stat_`var' = r(N), ., ., ., .
      matrix rowname stat_`var' = `var'

      matrix matStat = matStat \ stat_`var'
    }


    *** get frequencies for labeld answers categories and save as matrices
    matrix matTab = J(1, 2, .)
    matrix colnames matTab = code freq

    foreach var of varlist * {

      if "`: value label `var''" != "" { // just value labeld variables

        tab `var', matrow(code_`var') matcell(tab_`var') nofreq // miss

        capture: matrix tab_`var' = code_`var', tab_`var'
        if _rc == 0 {

          matrix rownames tab_`var' = `var'
          matrix matTab = matTab \ tab_`var'
        }
      }
    }


    *** create temp stata files from matrices
    foreach mat in matStat matTab {

      clear
      svmat `mat', names(col)

      * get names of variables by subsetting matrix rownames
      local names : rownames `mat'
      gen name = ""

      forvalues i = 1/`: word count `names'' {
        replace name = `"`: word `i' of `names''"' in `i'
      }

      tempfile data_`mat'
      save `data_`mat''
    }

    clear

    *** get data set with labels from labeld original data set
    getmata(name label sttype format code text) = matLab

    * create sort variable for (new) variable order
    gen stsort = _n, before(name)

    * destring code
    destring code, replace


    *** add answer frequencies to wide format labled answer data
    merge 1:1 name code using `data_matTab', nogen noreport // keep(1 3)

    * fill empty slots with known informations
    foreach var of varlist label sttype format {
      bysort name (label): replace `var' = `var'[_N] if `var' == ""
    }

    * correct sorting (add small steps to smallest value in order of code)
    bysort name (stsort): gen stsort_min = stsort[1]
    bysort name (code): replace stsort = stsort_min + (_n / 100)

    drop stsort_min

    sort stsort
    replace stsort = _n

    * replace empty answer freqs with 0 if answer label
    replace freq = 0 if mi(freq) & text != ""

    * code to string for later matching with LimeSurvey data
    capture: tostring code, replace

    *** create wide format for answers -> rowwise to variable * # of answers
    * number of answers (if multiple answers)
    bysort name: gen stanswer_n = _N if _N > 1

    sum stanswer_n, mean
    if `r(N)' > 0 {
      foreach num of numlist 1/`r(max)' {

        foreach part in code text freq {
          bysort name (stsort): gen stanswer_`part'_`num' = `part'[`num']
        }
      }
    }

    drop code text freq

    * keep just first observation from transformed long answer format
    bysort name: keep if _n == 1


    *** merge statistical (freq) of variables to label data
    merge 1:1 name using `data_matStat', nogenerate noreport keep(1 3)

    drop if name == "r1" & mi(N) // == "" // drop empty first row of initialized matrix


    *** if LS: save for merge; if just stata data: finalize data
    if "`lspath'" != "" {

      tempfile stData
      save `stData'
    }
    else {

      *** create subvars for wide format
      gen subvar = ""
      gen subvar_n = .

      * 1. use auto detect with length of one if not forbidden
      if "`noauto'" == "" {

        * extract prefix of subvar
        gen auto_code 	= ustrright(name, 1) + "$"
        gen auto_subvar = regexr(name, auto_code, "")

        * tag duplicates of non missing answer code & text
        duplicates t auto_subvar *_code_* *_text_* if !mi(stanswer_n), gen(auto_dup)

        sort stsort

        * mark as same if next to each other and duplicates
        gen auto_same = (auto_subvar == auto_subvar[_n + 1] | ///
                         auto_subvar == auto_subvar[_n - 1]) & ///
                        !mi(auto_dup) & auto_dup > 0

        * set subvar just if surring is same and empty
        replace subvar = auto_subvar if auto_same

        drop auto*
      }

      * 2. loop over given varpres to get subvar names
      foreach var of local varpre {
        replace subvar = "`var'" if regexm(name, "^`var'")
      }

      * 3. create wide format from subvar names
      count if subvar != ""
      if `r(N)' > 0 {

        * gen code of subvar: substract subvar name from variable name
        gen subvar_code = regexr(name, subvar, "") if subvar != ""

        * count max of subvars
        bysort subvar (stsort): replace subvar_n = _N if subvar != ""

        sum subvar_n, mean
        forval num = 1/`r(max)' {

          bysort subvar (stsort): gen subvar_code_`num' = subvar_code[`num'] ///
            if subvar != ""
          bysort subvar (stsort): gen subvar_text_`num' = label[`num'] ///
            if subvar != ""
          capture: bysort subvar (stsort): gen subvar_freq_`num' = N[`num'] ///
            if subvar != ""
        }

        drop subvar_code

        * keep just first observation per subvar
        bysort subvar: drop if _n > 1 & subvar != ""

        * get subvar name as real variable name
        replace name = subvar if subvar != ""
        replace label = "" if subvar != ""
      }


      *** put other variable in extra column for output
      gen other_sub = regexr(name, "other$", "")
      bysort other_sub (stsort): gen other_var = name[_n + 1] if _N == 2
      bysort other_sub (stsort): gen other_freq = N[_n + 1] if _N == 2
      bysort other_sub (stsort): keep if _N == 1 | (_N == 2 & _n == 1)


      *** replace format for cbout
      replace sttype = "stN" if regexm(format, "%[0-9]+.[0-9]+[a-z]")
      replace sttype = "stD" if regexm(format, "%t")
      replace sttype = "stS" if regexm(sttype, "str")
      replace sttype = "stL" if  mi(subvar_n) & !mi(stanswer_n)
      replace sttype = "stF" if !mi(subvar_n) & !mi(stanswer_n)
      replace sttype = "stM" if !mi(subvar_n) & ///
        ((stanswer_n == 1 & stanswer_code_1 == "1") | ///
         (stanswer_n == 2 & (stanswer_code_1 == "1" | stanswer_code_2 == "1")))


      *** keep just correct statistic informations
      sum stanswer_n, mean
      forval num = 1/`r(max)' {

        replace stanswer_freq_`num' = . if !mi(subvar_n)	// no answer freqs if subquestions
      }

      replace N = . if !mi(subvar_n) // no overall variable freqs if subquestions

      recode mean sd min max (nonmiss = .) if sttype != "stN" // variable stats just for numeric

      * create new and final sorting variable
      sort stsort
      gen sort = _n

      rename name variable
      rename label varlabel
    }
  }
}

*-------------------------------------------------------------------------------

*** 2. LimeSurvey data prep

if `"`lspath'"' != "" { //just if LimeSurvey path is given (not stonly)

  *** 2.1 load (multiple) limesurvey file(s)

  local lsfiles: dir `"`lspath'"' file "limesurvey_survey_*.txt"

  * produce error note if no valid LS-Structure file is in the path
  if `: word count `lsfiles'' == 0  {
    noi di in red `"no LimeSurvey structure file found: limesurvey_survey_*.txt"'
    exit 198
  }

  local nfile = 0
  foreach file of local lsfiles {

    display "Load LimeSurvey structure file: `file'"

    local ++nfile

    if `"`lspath'"' == "." local pathfile = "`file'"
    else local pathfile = "`lspath'/`file'"

    import delimited "`pathfile'", clear stringcols(_all) bindquotes(strict) ///
      maxquotedrows(unlimited) delimiters("\t") encoding("UTF-8")

    // if panel, save number of order for wave report in codebook
    quietly: gen survey = `nfile' if `: word count `lsfiles'' > 1

    tempfile lsdata`nfile'
    quietly: save `lsdata`nfile''
  }

  clear

  forval i = 1/`nfile' {
    quietly: append using `lsdata`i''
  }

  *-----------------------------------------------------------------------------

  *** 2.2 recode and prepare dataset
  quietly {

  * get admin (-email), start- & enddate, surveytitle and language(s)
  gen rownumb = _n

  foreach cat in admin adminemail startdate expires surveyls_title ///
    language additional_languages {

    sum rownumb if name == "`cat'", meanonly
    capture: local nts_`cat' = text[`r(min)'] // if not listed, add empty string
    if _rc != 0 local nts_`cat' = ""

  }

  label data `"`nts_surveyls_title'"'

  notes : `"`nts_admin'"'      // # 1
  notes : `"`nts_adminemail'"'  // # 2
  notes : `"`nts_startdate'"'  // # 3
  notes : `"`nts_expires'"'    // # 4
  notes : `"`nts_language'"'   // # 5
  if `"`nts_additional_languages'"' != "" {
    notes replace _dta in 5 : `"`nts_language' + `nts_additional_languages'"'
  }


  * rename variables
  rename name variable
  rename typescale lstype
  rename relevance filter

  * create empty column for variable label
  gen varlabel = ""

  * keep just base language, or also one translation defined in option
  // get local of baselangeuage defined in limesurvey data
  levelsof text if variable == "language", local(baselang)

  // error message if not multiple languages or choosen one isn't part of LS dataset
  levelsof language, local(lslanguages)
  if strlen(`"`lslanguages'"') < 2 {
     noi display in red "There are no more languages to choose from."
     exit 198
  }
  else {
    if !regexm(`"`lslanguages'"', `"`language'"') {
      local validlangs = subinstr(`"`lslanguages'"', `"`baselang'"', "", .)
      noi display in red `"The choosen language is not part of the LimeSurvey dataset."'
      noi display in red `"Please use one of the following: `validlangs'."'
      exit 198
    }
  }

  keep if language == `baselang' | language == "`language'"

  * add welcometext (& endtext) to data for codebook
  replace variable = "welcometext" if variable == "surveyls_welcometext"
  replace variable = "endtext"     if variable == "surveyls_endtext"
  replace class = "T" if inlist(variable, "welcometext", "endtext")
  replace lstype = "WT" if variable == "welcometext"
  replace lstype = "ET" if variable == "endtext"

  * keep just Questiongroups, Questions, Sub-Questions and Answers
  keep if inlist(class, "G", "Q", "SQ", "A", "T")

  * gen lssort to keep order of sub-variables later on
  gen lssort = _n

  * replace end text with highest number to have it in the end
  replace lssort = _N + 100 if lstype == "ET"

  sort lssort

  * generate variable name of matrix/multiple-answer variable for subvars
  gen     subvar = variable if class[_n + 1] == "SQ"
  replace subvar = subvar[_n - 1] if class == "SQ"

  * create new suborder for multi-scale SQ/Answer, to get right order (from alternate)
  // important for ordering of axis -> all y- and x-scales together/behind
  gen 		subvar2 = subvar
  replace subvar2 = subvar2[_n - 1] if class == "A"

  replace lstype = "0" if lstype == "" & inlist(class, "SQ", "A")

  gen 		lssort1 = lssort if class == "Q"
  replace	lssort1 = lssort1[_n - 1] if inlist(class, "SQ", "A")

  bysort subvar2 (lssort): gen lssort2 = lssort * real(lstype) + _n ///
    if inlist(class, "SQ", "A")

  replace lssort = lssort1 + (lssort2 / 10000) if inlist(class, "SQ", "A")

  drop lssort? subvar2

  * count number of matrix/multiple-answer variables
  bysort subvar (lssort): gen subvar_n = _N - 1 if subvar != ""

  * count length of separated x- and y- subquestions
  bysort subvar (lssort): egen subvar_n1 = total(lstype == "0") // occurence of first scale
  gen subvar_n2 = subvar_n - subvar_n1 // occurence of seccond scale

  recode subvar_n? (nonmi = .) if inlist(subvar_n2, 0, .) // keep values just for 2 scalers

  * add prefix of variable to code of subquestion (for merging and clean up)
  gen     name = variable, after(variable)
  replace name = subvar + variable if class == "SQ"


  * drop (wrong) other_replace_text when no other category
  replace other_replace_text = "" if other == "N"

  * recode 0 values for hidden and random_order (version 3.4)
  replace hidden = "" if hidden == "0"
  replace random_order = "" if random_order == "0"

  * recode mandatoy, keep just "Y"
  replace mandatory = "" if mandatory == "N"

  *-----------------------------------------------------------------------------

  *** 2.3 clean up text

  * 2.3.1 question and help text
  foreach var of varlist text help {

    * transform usefull html-tags of style to latex code
    replace `var' = ustrregexra(`var', "<strong>", "\\textbf{")
    replace `var' = ustrregexra(`var', "</strong>", "}")
    replace `var' = ustrregexra(`var', "<u>", "\\underline{")
    replace `var' = ustrregexra(`var', "</u>", "}")
    replace `var' = ustrregexra(`var', "<br[ /]*>", " \\newline ") if class != "A"
    replace `var' = ustrregexra(`var', "</p>", " \\newline ") if class != "A"

    * remove rest of uneccesary html-tags
    replace `var' = ustrregexra(`var', "</*.+?>", " ")
    replace `var' = ustrregexra(`var', "&nbsp;[ ]*", " ")

    replace `var' = regexr(`var', "\\newline[ ]*(\\newline)*[ ]*$", "") // no newline at the end

    replace `var' = strtrim(`var')
    replace `var' = stritrim(`var')
  }


  * 2.3.2 remove variable adding from LS
  foreach var of varlist text filter default {
    replace `var' = ustrregexra(`var', ".NAOK", "")
  }


  * 2.3.3 clean up filter arguments
  replace filter = "" if filter == "1" // if no question-filter, delete 1

  //replace filter = ustrregexra(filter, " Y", " 1 ")
  //replace filter = ustrregexra(filter, " N", " 0 ")
  replace filter = ustrregexra(filter, "&&", "and")
  // replace filter = ustrregexra(filter, "^\(", "") ///
  //   if !regexm(filter, " or ")
  // replace filter = ustrregexra(filter, "\)$", "") ///
  //   if !regexm(filter, " or ")
  replace filter = ustrregexra(filter, `"""', "")

  replace filter = strtrim(filter)


  * 2.3.4 clean up default
  replace default = regexr(default, "^{", "")
  replace default = regexr(default, "}$", "")


  * 2.3.5 remove category separator
  capture: replace category_separator = category_separator[_n - 1] if inlist(class, "SQ", "A")
  if _rc == 0 {
    replace category_separator = "^[ ]*[" + category_separator + "]" if category_separator != ""
    replace text = regexr(text, category_separator, "") if inlist(class, "SQ", "A") ///
      & category_separator != ""
  }

  * 2.3.6 remove "Array" as placeholder in subquestions and answers
  replace text = "" if text == "Array" & inlist(class, "SQ", "A")

  *---------------------------------------------------------------------------

  *** 2.4 add name and filter of question group to all variables

  sort lssort

  gen 		group = variable if class == "G"
  replace group = regexr(group, "[0-9]+ ", "")
  replace group = group[_n-1] if !inlist(class, "G", "T")

  gen     grp_fltr = filter if class == "G"
  replace grp_fltr = grp_fltr[_n-1] if !inlist(class, "G", "T")

  gen     grp_rand = random_group if class == "G"
  replace grp_rand = grp_rand[_n-1] if !inlist(class, "G", "T")

  drop if class == "G" // drop group observations

  *---------------------------------------------------------------------------

  *** 3. merge LimeSurvey data with statistics and (stata) label data

  if `"`lsonly'"' == "" {

    *** 3.1 merge data
    merge m:1 name using `stData', noreport update replace

    sort lssort


    *** 3.2 create new variable to get #obs from merged vars (order & special matrices)
    gen mergevars = ""

    // order
    replace mergevars = name if lstype == "R"

    // multi column matrix
    replace mergevars = name if lstype[_n - 1] == "1" & class[_n - 1] == "Q"
    replace mergevars = name if class == "SQ" & mergevars[_n - 1] != ""


    *** 3.3 loop over special variables to get common name to get merged infos
    levelsof mergevars, local(mergevalues)

    foreach mergevar of local mergevalues {

     * remove last number
     replace mergevars = substr(name, 1, length(name) - 1) ///
       if regexm(name, `"`mergevar'"') & _merge == 2
     // !!! just the last number  will be removed, order with more than 9 rows
    }


    *** 3.4 loop over numeric/text matrix variables to make regular expression to
    *   extract base names from matrix variables from data set to get # of obs
    gen matvars = name if inlist(lstype, ";", ":")
    gen index = _n

    levelsof matvars, local(matvalues)
    foreach matvar of local matvalues {

      sum index if name == "`matvar'", meanonly

      local subvars = subvar_n[`r(min)']

      local sub1 = ""
      local sub2 = ""

      forval subvar = 1/`subvars' {

        local varnum = `r(min)' + `subvar'

        if lstype[`varnum'] == "0" local sub1 = "`sub1'" + variable[`varnum'] + "|"
        if lstype[`varnum'] == "1" local sub2 = "`sub2'" + variable[`varnum'] + "|"
      }

      replace mergevar = regexr(name, "`matvar'(`sub1')_(`sub2')", "`matvar'") ///
        if _merge == 2 & regexm(name, "`matvar'")
      }

    replace mergevars = matvars if matvars != ""

    * get maximum # of observations and replace N of LS-variables
    bysort mergevar: egen N_temp = max(N)
    replace N = N_temp if mergevar != "" | matvars != ""

    * get lowest sorting number from subvars for main variable
    bysort subvar: egen stsort_temp = min(stsort)
    replace stsort = stsort_temp if stsort == . & subvar != ""

    * get lowest sorting number from mergevars for main variable
    bysort mergevars: egen stsort_temp2 = min(stsort)
    replace stsort = stsort_temp2 if stsort == . & mergevars != ""


    drop if mergevar != "" & _merge == 2
    drop mergevar matvars index *_temp* _merge
  }

  *---------------------------------------------------------------------------

  *** 4. transform dataset -> wideformat

  *** 4.1 reform matrix/multiple-answer variables -> subvariables/-answers to wide
  sum subvar_n, mean
  forval num = 1/`r(max)' {

    bysort subvar (lssort): gen subvar_code_`num' = variable[`num' + 1] ///
      if subvar != ""
    bysort subvar (lssort): gen subvar_text_`num' = text[`num' + 1] ///
      if subvar != ""
    bysort subvar (lssort): gen subvar_fltr_`num' = filter[`num' + 1] ///
      if subvar != ""
    capture: bysort subvar (lssort): gen subvar_freq_`num' = N[`num' + 1] ///
      if subvar != ""
  }

  * count number of subvar-filters (for latex-table extra filter-column)
  egen subvar_fltr_n = rownonmiss(subvar_fltr_*), strok

  * drop subvars (subquestions in LS)
  drop if class == "SQ"


  *** 4.2 reform answers of multiple and categorial questions to wide format
  sort lssort

  gen     lsanswer = variable if class[_n + 1] == "A"
  replace lsanswer = lsanswer[_n - 1] if class == "A"

  * count number of lsanswers
  bysort lsanswer (lssort): gen lsanswer_n = _N - 1 if lsanswer != ""

  * count numbers of separated answer scales
  bysort lsanswer (lssort): egen lsanswer_n1 = total(lstype == "0")
  gen lsanswer_n2 = lsanswer_n - lsanswer_n1

  recode lsanswer_n? (nonmi = .) if inlist(lsanswer_n2, 0, .)


  *** put frequencies from stanswer_freqs from wide to long for lsanswer_freqs
  if "`lsonly'" == "" {

    sum stanswer_n, mean
    if `r(N)' > 0 {
      forval num = 1/`r(max)' {

        * replace freq with stanswer_freq if codes are the same
        bysort lsanswer (lssort): replace N = stanswer_freq_`num'[1] ///
          if stanswer_code_`num'[1] == name
      }
    }
  }

  *** create wide format for lsanswers
  sum lsanswer_n, mean
  if `r(N)' > 0 {
    forval num = 1/`r(max)' {

      bysort lsanswer (lssort): gen lsanswer_code_`num' = variable[`num' + 1] ///
        if lsanswer != ""
      bysort lsanswer (lssort): gen lsanswer_text_`num' = text[`num' + 1] ///
        if lsanswer != ""
      bysort lsanswer (lssort): gen lsanswer_fltr_`num' = filter[`num' + 1] ///
        if lsanswer != ""
      capture: bysort lsanswer (lssort): gen lsanswer_freq_`num' = N[`num' + 1] ///
        if lsanswer != ""
    }
  }

  drop if class == "A"

  * count number of answer-filters (for latex-table extra filter-column)
  capture: egen lsanswer_fltr_n = rownonmiss(lsanswer_fltr_*), strok

  * add missing name of variable to variable
  replace variable = name if variable == ""

  *-----------------------------------------------------------------------------

  * ...

  if "`lsonly'" == "" {

    *** put other variable in extra column for output
    gen other_sub = regexr(name, "other$", "")
    bysort other_sub (stsort): gen other_var = name[_n + 1] if _N == 2
    bysort other_sub (stsort): gen other_freq = N[_n + 1] if _N == 2
    bysort other_sub (stsort): keep if _N == 1 | (_N == 2 & _n == 1)


    *** replace format for cbout
    replace sttype = "stN" if regexm(format, "%[0-9]+.[0-9]+[a-z]")
    replace sttype = "stD" if regexm(format, "%t")
    replace sttype = "stS" if regexm(sttype, "str")
    replace sttype = "stL" if  mi(subvar_n) & !mi(stanswer_n)
    replace sttype = "stF" if !mi(subvar_n) & !mi(stanswer_n)
    /*replace sttype = "stM" if !mi(subvar_n) & ///
      ((stanswer_n == 1 & stanswer_code_1 == "1") | ///
       (stanswer_n == 2 & (stanswer_code_1 == "1" | stanswer_code_2 == "1")))*/


    *** keep just correct statistic informations
    sum stanswer_n, mean
    if `r(N)' > 0 {
      forval num = 1/`r(max)' {

        replace stanswer_freq_`num' = . if !mi(subvar_n)	// no answer freqs if subquestions
      }
    }

    replace N = . if !mi(subvar_n) // no overall variable freqs if subquestions

    recode mean sd min max (nonmiss = .) if sttype != "stN" // variable stats just for numeric


    * add missing questtype information from limesurvey to sttype
    replace sttype = lstype if sttype == ""
  }

  }

  *-----------------------------------------------------------------------------

  *** 5. if stata data added: combined sorting variable

  quietly {

    capture: d stsort
    if _rc == 0 {

      * create drop variables (to choose later which will stay)
      gen drop_ls = stsort == .
      gen drop_st = lssort == .

      * create combined sort variable (LS = base, Stata keep together)
      gsort -stsort -lssort

      gen sort = lssort

      replace sort = sort[_n - 1] if mi(sort) & !mi(sort[_n - 1])
      replace sort = sort + (stsort /10000) if !mi(stsort)
      replace sort = stsort if mi(sort)

      sort sort
      replace sort = _n
    }
    else {

      * create new sort variable (for LS only)
      sort lssort
      gen sort = _n
    }

    *** fill missing information about group and survey
    replace group    = group[_n-1]    if group == "" & !inlist(lstype, "WT", "ET")
    replace grp_fltr = grp_fltr[_n-1] if group == group[_n-1]
    replace grp_rand = grp_rand[_n-1] if group == group[_n-1]

    replace survey   = survey[_n-1]   if mi(survey)
  }
}

*-------------------------------------------------------------------------------

* 6. keep just important variables and order (check if statistics available)

*** generate empty variables (if missing)
* string
foreach var in varlabel filter text help other other_replace_text other_var ///
  random_group random_order validation mandatory prefix suffix hidden ///
  group grp_fltr grp_rand maximum_chars min_num_value_n max_num_value_n ///
  date_format date_max date_min numbres_only other_numbers_only default {

  capture: gen `var' = ""
}
* numeric
foreach var in subvar_n1 subvar_n2 N mean sd min max ///
  other_freq survey drop_ls drop_st {

  capture: gen `var' = .
}

keep sort variable varlabel ??type filter text help ///
  subvar_* ??answer_* group grp_fltr grp_rand ///
  N mean sd min max ///
  other other_replace_text other_var other_freq ///
  hidden random* validation mandatory prefix suffix survey default ///
  maximum_chars *_num_value_n date_* *_only drop_??

order sort variable varlabel ??type filter text help ///
  subvar_* ??answer_* group grp_fltr grp_rand ///
  N mean sd min max ///
  other other_replace_text other_var other_freq ///
  hidden random* validation mandatory prefix suffix survey default ///
  maximum_chars *_num_value_n date_* *_only drop_??


* add number of observations as note for output
notes: "$nobs" // # 6

*-------------------------------------------------------------------------------
/*
quietly {

  * yes/no question: add values manualy (ToDo: add multiple languages)
  forval num = 1/2 {
    capture: gen lsanswer_code_`num'
    capture: gen lsanswer_text_`num'
  }

  replace lsanswer_code_1 = "N"   if lstype == "Y"
  replace lsanswer_text_1 = "No"  if lstype == "Y"
  replace lsanswer_code_2 = "Y"   if lstype == "Y"
  replace lsanswer_text_2 = "Yes" if lstype == "Y"

  replace lsanswer_n = 2 if lstype == "Y"
}
*/
*-------------------------------------------------------------------------------

* if option save is defined, save data and restore to original file in memory
if `"`save'"' != "" {

  compress

  save `"`save'"', replace

  capture: restore
}

end


*** Definition of mata function to get labels of Stata file
// code (partly) taken from codebookout.ado
// http://fmwww.bc.edu/RePEc/bocode/c/codebookout.ado

clear mata

mata:
function mata_getlabels() {

  nv = st_nvar()
  matLab = J(0, 6, "")  // rows * cols with elements = ""

  for(i = 1; i <= nv; i++) {

    if(st_varvaluelabel(i) != "") {

      st_vlload(st_varvaluelabel(i), values = ., text = .)
      a1 = st_varname(i), st_varlabel(i), st_vartype(i), st_varformat(i)
      a2 = (strofreal(values), text)

      len = length(a2[, 1])

      for (j = 1; j <= len; j++) {
        a3 = a1, a2[j,]
        matLab = matLab\a3
      }
    }
    else {
      b = st_varname(i), st_varlabel(i), st_vartype(i), st_varformat(i), "", ""
      matLab = matLab\b
    }
  }
  return(matLab)
}
end

exit
