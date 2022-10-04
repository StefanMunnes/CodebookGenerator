* version 0.1 2020-11-19 dta to tex munnes@wzb.eu
* export pre-recoded dta dataset to list of variables in tex format for codebook
*

program define cbout

syntax [using/], save(string) [replace drop(varlist) add(varlist) lslab droptext ///
  german CLRtblrow(string) tblmax(integer 16) NOSTatistics lsdrop stdrop ///
  frag titlepage NONUMVar NONUMGroup LANDscape MARGins(integer 15)]

version 12

// Opt: Statistics: just delete Stats --> in Code -> print if not empty
pause on
* Errors -----------------------------------------------------------------------

* error message if no save file is specified (ripped from dataout.ado)
if `"`save'"' == "" {
  noi di in red "must specify {opt save( )}"
  exit 198
}

*  extract output format or error message if no valid file extension
if regexm(`"`save'"', "(\.)(pdf$|docx$|tex$)") {
  local output = regexs(2)
}
else {
  noi di in red "one of the following output formats must be defined: .pdf, .docx or .tex"
  exit 198
}

* error message if file exists and replace not specified (ripped from dataout.ado)
capture: confirm file `"`save'"'
if !_rc & "`replace'" != "replace" {
  noi di in red `"`save' already exists; specify {opt replace}"'
  exit 198
}

* define (default) table row color or error message if color was wrongly specified
if `"`clrtblrow'"' == "" {
  if `"`output'"' == "tex" local rgb = "245, 245, 245"
  if `"`output'"' != "tex" local rgb = "245 245 245"
}
if `"`clrtblrow'"' != "" {
  if !ustrregexm(`"`clrtblrow'"', "[0-9]{1,3} [0-9]{1,3} [0-9]{1,3}") {
    noi di in red "the color for {opt clrtblrow} is wrong specified"
    exit
  }
  if "`output'" == "tex" local rgb = subinstr(`"`clrtblrow'"', " ", ",", 2)
  if "`output'" != "tex" local rgb = `clrtblrow'
}

*-------------------------------------------------------------------------------

* add dta to filenames if not present
if `"`using'"' != "" & !strmatch(`"`using'"', "*.dta*") local using = `"`using'.dta"'

* set option lslab if just LimeSurvey data is used (no stsort)
capture: confirm variable stanswer_n
if _rc != 0 local lslab = "lslab"

* define if LimeSurvey (ls) or Stata (st) is database for answers
if `"`lslab'"' != "" local db = "ls"
if `"`lslab'"' == "" local db = "st"

* define local of number of surveys
quietly: levelsof survey, local(surveys)
local survey_n: word count `surveys'

* define (default) varlist for presentation of variable characteristics
local varlist = `"type filter text help other_replace_text suffix random_group random_order N other_var"'

if "`drop'" != "" unab vdrop : `drop'
if "`add'" != "" unab vadd : `add'

local varlist : list local(varlist) - local(vdrop) // remove drop variables
local varlist : list local(varlist) - local(vadd) // remove additional variables
local varlist = `"`varlist' `vadd'"' // new varlist with rest and new variables

* check margins value
if !inrange(`margins', 0, 50) {
  noi di in red "The value `margins' for the margins is not valid."
  exit 198
}

*-------------------------------------------------------------------------------

preserve

* load dataset, if file is specified, otherwise took dataset in use
if `"`using'"' != "" {
  use `"`using'"', clear
}

*-------------------------------------------------------------------------------

*** dataprep
quietly {

  gen type  = `db'type
  gen qtype = type

  * drop LimeSurvey or Stata only variables if choosen per Option
  if "`lsdrop'" != "" drop if drop_ls
  if "`stdrop'" != "" drop if drop_st

  * drop variables that just show text and welcome/end text if option is defined
  if `"`droptext'"' != "" drop if inlist(type, "X", "WT", "ET")

  * drop WT or ET if empty
  drop if inlist(type, "WT", "ET") & text == ""


  * add number of survey to groupname if multiple surveys
  replace group = group + " [" + strofreal(survey) + "]" if !mi(survey)

  * keep just first occurence of group name/filter/random (heading in loop)
  bysort survey group (sort): replace group = "" if _n != 1
  replace grp_fltr = "" if group == ""
  replace grp_rand = "" if group == ""

  sort sort

  * add numbering of questions (if not supressed)
  if "`nonumvar'" == "" {
    if variable[1] == "welcometext" {
      replace variable = string(_n - 1) + ". " + variable ///
        if !inlist(variable, "welcometext", "endtext")
    }
    else replace variable = string(_n) + ". " + variable
  }

  * add roman numbering of groups (if not supressed)
  if "`nonumgroup'" == "" {

    gen group_tmp = .
    local group_tmp = 1

    quietly: count
    forval rown = 1/`r(N)' {

      if group[`rown'] != "" {
        replace group_tmp = `group_tmp' if _n == `rown'
        local ++group_tmp
      }
    }

    *** add group numbering
    replace group = string(group_tmp) + ". " + group if group != ""


    /* add later roman numbering

    https://helloacm.com/how-to-convert-arabic-integers-to-roman-numerals/

    lab define roman ///
      1000 "M" ///
      900 "CM" ///
      500 "D" ///
      400 "CD" ///
      100 "C" ///
      90 "XC" ///
      50 "L" ///
      40 "XL" ///
      30 "XXX" ///
      20 "XX" ///
      10 "X" ///
      9 "IX" ///
      5 "V" ///
      4 "IV" ///
      1 "I"
    */
  }

  * get number of groups and variables for titlepage (and add to notes)
  if "`titlepage'" != "" {

    count if group != ""
    notes : "`r(N)'"  // # 7
    if `r(N)' == 0 replace notes _dta in 7 : ""

    count if !inlist(type, "WT", "ET")
    notes : "`r(N)'"  // # 8
  }


  * deal with special characters if tex output
  if `"`output'"' == "tex" {
    ds *, has(type string)
    foreach var of varlist `r(varlist)' {
      replace `var' = ustrregexra(`var', "%", "\\%")
      replace `var' = ustrregexra(`var', "&", "\\&")
    }
  }


  * recode answers for max table length (default or given length over option)
  sum `db'answer_n, mean
  if r(N) > 0 & r(max) > `tblmax' {

    local tblmax2 = floor(abs(`tblmax')/2) // half of max, for front and end
    local tblmid = `tblmax2' + 1 // middle column/row with ... (after front = +1)

    capture: tostring `db'answer_code*, replace

    * SM: Problem mit Filtern, wenn in Stata mehr Antworten als in LimeSurvey

    // add middle category
    replace `db'answer_code_`tblmid' = "..." if `db'answer_n > `tblmax' ///
      & !mi(`db'answer_n)
    replace `db'answer_text_`tblmid' = "..." if `db'answer_n > `tblmax' ///
      & !mi(`db'answer_n)
    capture: replace `db'answer_fltr_`tblmid' = "..." if `db'answer_n > `tblmax' ///
      & !mi(`db'answer_n)
    capture: replace `db'answer_freq_`tblmid' = . if `db'answer_n > `tblmax' ///
      & !mi(`db'answer_n)

    // loop over each row = variable
    local max = _N
    forval varnum = 1/`max' {

      // loop over half of max rows, to get end further forward, if more rows than max
      if `db'answer_n[`varnum'] > `tblmax' & !mi(`db'answer_n[`varnum']) {

        local var = variable[`varnum']
        display in red "List of answer options shortened for: `var'" // as text

        forval count = 1/`tblmax2' {

          local tbldiff = `db'answer_n[`varnum'] - `tblmax' // # of excess answers
          local tblend1 = `tblmid' + `count' //
          local tblend2 = `tblmid' + `tbldiff' + `count' - 1

          replace `db'answer_code_`tblend1' = `db'answer_code_`tblend2' if _n == `varnum'
          replace `db'answer_text_`tblend1' = `db'answer_text_`tblend2' if _n == `varnum'
          capture: replace `db'answer_fltr_`tblend1' = `db'answer_fltr_`tblend2' ///
            if _n == `varnum'
          capture: replace `db'answer_freq_`tblend1' = `db'answer_freq_`tblend2' ///
            if _n == `varnum'
        }
      }
    }

    // correct number of answers to max + 1 (for middle)
    replace `db'answer_n = `tblmax' + 1 if `db'answer_n > `tblmax' & !mi(`db'answer_n)
  }


  * create empty stanswer_freq_n for loop
  foreach mode in subvar stanswer {

    capture: gen `mode'_fltr_n = .
    replace `mode'_fltr_n = 0 if mi(`mode'_fltr_n)
  }

  capture: gen lsanswer_freq_1 = .
  capture: gen subvar_freq_1 = .


  * recode statistics to missing if Option is choosen
  if "`nostatistics'" != "" {
    quietly: recode N - max *_freq* (nonmiss = .)
  }

  * clean text if no tex output
  if `"`output'"' != "tex" {

    foreach var of varlist *text* help {

      // replace `var' = ustrregexra(`var', "}", "") if regexm(`var', "\\[a-z]+{")
      // replace `var' = ustrregexra(`var', "[ ]*\\(newline|textbf{|underline{)", "")

    //  replace `var' = strtrim(`var')
    //  replace `var' = stritrim(`var')
    }
  }

  sort sort

  *-----------------------------------------------------------------------------

  *** define labels depending on language selection (english default

  if `"`german'"' != "" {

    * label variable characteristics (if not manually relabeled)
    if "`: variable label type'" == "" lab var type "Fragetyp"
    if "`: variable label filter'" == "" lab var filter "Filter"
    if "`: variable label text'" == "" lab var text "Fragetext"
    if "`: variable label help'" == "" lab var help "Hilfetext"
    if "`: variable label other_replace_text'" == "" lab var other_replace_text "Offene Frage"
    if "`: variable label suffix'" == "" lab var suffix "Suffix"
    if "`: variable label random_group'" == "" lab var random_group "Randomisierungsgruppe"
    if "`: variable label random_order'" == "" lab var random_order "Reihenfolge"
    if "`: variable label other_var'" == "" lab var other_var "Sonstige Variable"


    *** label question type with codes and wording (if not manually relabeled)

    * Stata
    replace type = "Stata: Matrix" if type == "stF"
    replace type = "Stata: Mehrfachauswahl" if type == "stM"
    replace type = "Stata: Kategorisch" if type == "stL"
    replace type = "Stata: Zahleneingabe" if type == "stN"
    replace type = "Stata: Texteingabe" if type == "stS"
    replace type = "Stata: Datum" if type == "stD"

    * LimeSurvey
    // Matrix
    replace type = "Matrix (5 Punkte Auswahl)" if type == "A"
    replace type = "Matrix (10 Punkte Auswahl)" if type == "B"
    replace type = "Matrix (Ja/Nein/Unsicher)" if type == "C"
    replace type = "Matrix (Zunahme / Gleich / Abnahme)" if type == "E"
    replace type = "Matrix" if type == "F"
    replace type = "Matrix nach Spalte" if type == "H"
    replace type = "Matrix Dual Matrix" if type == "1"
    replace type = "Matrix (Zahlen)" if type == ":"
    replace type = "Matrix (Text)" if type == ";"

    // Fragemasken
    replace type = "Datum" if type == "D"
    replace type = "Geschlecht" if type == "G"
    replace type = "Numerische Eingabe" if type == "N"
    replace type = "Mehrfache numerische Eingabe" if type == "K"
    replace type = "Reihenfolge" if type == "R"
    replace type = "Textbaustein" if type == "X"
    replace type = "Ja/Nein" if type == "Y"
    replace type = "Sprachwechsel" if type == "I"
    replace type = "Gleichung" if type == "*"

    // Mehrfachauswahl
    replace type = "Mehrfachauswahl" if type == "M"
    replace type = "Mehrfachauswahl plus Kommentarfeld" if type == "P"

    // Einfachauswahl
    replace type = "Liste Klappbox" if type == "!"
    replace type = "5 (5 Punkte Auswahl)" if type == "5"
    replace type = "Liste Optionsfelder" if type == "L"
    replace type = "Liste mit Kommetarfeld" if type == "O"

    // Textfragen
    replace type = "Mehrfache kurze Texte" if type == "Q"
    replace type = "Mehrfache numerische Eingabe" if type == "K"
    replace type = "Kurzer freier Text" if type == "S"
    replace type = "Langer freier Text" if type == "T"
    replace type = "Ausführlicher freier Text" if type == "U"


    replace hidden = "versteckt" if hidden == "1"
    replace mandatory = "verpflichtend" if mandatory == "Y"
    replace random_order = "Zufällige Reihenfolge" if random_order == "1"
    replace other_replace_text = "Sonstiges" if other == "Y" & other_replace_text == ""

    * add labels for subvar or answer table header
    local lab_title_3 = "Startdatum"
    local lab_title_4 = "Enddatum"
    local lab_title_5 = "Sprache"
    local lab_title_6 = "N"
    local lab_title_7 = "Fragegruppen"
    local lab_title_8 = "Variablen"

    local lab_var = "Variable"
    local lab_cod = "Kodierung"
    local lab_lab = "Beschriftung"
    local lab_mea = "Mittelwert"
    local lab_sd  = "St. Abweichung."

    local lab_grf = "Gruppenfilter"
    local lab_rdg = "Randomisierungsgruppe"

    local lab_bgn = "Willkommensnachricht"
    local lab_end = "Endnachricht"

  }
  else {

    * label variable characteristics (if not manually relabeled)
    if "`: variable label type'" == "" lab var type "Questiontype"
    if "`: variable label filter'" == "" lab var filter "Filter"
    if "`: variable label text'" == "" lab var text "Questiontext"
    if "`: variable label help'" == "" lab var help "Helptext"
    if "`: variable label other_replace_text'" == "" lab var other_replace_text "Open question"
    if "`: variable label suffix'" == "" lab var suffix "Suffix"
    if "`: variable label random_group'" == "" lab var random_group "Randomization group"
    if "`: variable label random_order'" == "" lab var random_order "Order"
    if "`: variable label other_var'" == "" lab var other_var "Other Variable"


    *** label question type with codes and wording (if not manually relabeled)

    * Stata
    replace type = "Stata: Array" if type == "stF"
    replace type = "Stata: Multiple choice" if type == "stM"
    replace type = "Stata: Single choice" if type == "stL"
    replace type = "Stata: Numeric input" if type == "stN"
    replace type = "Stata: Text input" if type == "stS"
    replace type = "Stata: Date" if type == "stD"

    * LimeSurvey
    // Arrays
    replace type = "Array (5 point choice)" if type == "A"
    replace type = "Array (10 point choice)" if type == "B"
    replace type = "Array (Yes/No/Uncertain)" if type == "C"
    replace type = "Array (Increase/Same/Decrease)" if type == "E"
    replace type = "Array" if type == "F"
    replace type = "Array by column" if type == "H"
    replace type = "Array dual scale" if type == "1"
    replace type = "Array (Numbers)" if type == ":"
    replace type = "Array (Texts)" if type == ";"

    // Mask questions
    replace type = "Date/Time" if type == "D"
    replace type = "Gender" if type == "G"
    replace type = "Numerical input" if type == "N"
    replace type = "Multiple numerical input" if type == "K"
    replace type = "Ranking" if type == "R"
    replace type = "Text display" if type == "X"
    replace type = "Yes/No" if type == "Y"
    replace type = "Equation" if type == "*"

    // Multiple choice questons
    replace type = "Multiple choice" if type == "M"
    replace type = "Multiple choice with comments" if type == "P"

    // Single choice questions
    replace type = "5 point choice" if type == "5"
    replace type = "List (Dropdown)" if type == "!"
    replace type = "List (Radio)" if type == "L"
    replace type = "List with comment" if type == "O"

    // Text questions
    replace type = "Short free text" if type == "S"
    replace type = "Long free text" if type == "T"
    replace type = "Huge free text" if type == "U"
    replace type = "Multiple short text" if type == "Q"


    replace hidden = "hidden" if hidden == "1"
    replace mandatory = "mandatory" if mandatory == "Y"
    replace random_order = "Random order" if random_order == "1"
    replace other_replace_text = "Other" if other == "Y" & other_replace_text == ""
    replace other_replace_text = "Other variable" if other == "Y" & other_replace_text == ""

    * add labels for subvar or answer table header
    local lab_title_3 = "Start date"
    local lab_title_4 = "End date"
    local lab_title_5 = "Language"
    local lab_title_6 = "N"
    local lab_title_7 = "Questiongroups"
    local lab_title_8 = "Variables"

  local lab_var = "Variable"
    local lab_cod = "Coding"
    local lab_lab = "Label"
    local lab_mea = "Mean"
    local lab_sd  = "St. Deviation"

    local lab_grf = "Groupfilter"
    local lab_rdg = "Randomization group"

    local lab_bgn = "Welcometext"
    local lab_end = "Endtext"
  }
}

*-------------------------------------------------------------------------------

* filter by output format, start with tex, following by docx and pdf
if "`output'" == "tex" {

  * start the tex document
  capture: file close cb
  file open cb using `"`save'"', write replace

  * if not a stand alone fragment -> add  header to tex document
  if "`frag'" == "" {
    file write cb `"\documentclass{article}"' _n
    if `"`german'"' != "" file write cb `"\usepackage[ngerman]{babel}"' _n
    file write cb `"\usepackage[utf8]{inputenc}"' _n
    file write cb `"\usepackage[T1]{fontenc}"' _n
    file write cb `"\usepackage{lmodern}"' _n
    file write cb `"\usepackage[margin=`margins'mm, `landscape']{geometry}"' _n // includeheadfoot
    file write cb `"\usepackage{tabularx}"' _n
    file write cb `"\usepackage{booktabs}"' _n
    if `"`clrtblrow'"' != "" {
      file write cb `"\usepackage[table, dvipsnames]{xcolor}"' _n
      file write cb `"\definecolor{gray}{RGB}{`rgb'}"' _n
    }
    file write cb `"\usepackage{underscore}"' _n
    file write cb `"\setlength\parindent{0pt}"' _n
    // file write cb `"\titleclass{\section}{top}"' _n
    file write cb `"  \let\oldsection\section"' _n
    file write cb `"\renewcommand\section{\clearpage\oldsection}"' _n(2)
    file write cb `"\begin{document}"' _n(2)
  }

  ******************************************************************************

  * loop over each variable (row of dataset)
  local max = _N
  forvalues var = 1/`max' {

    display as text variable[`var']

    * save text of welcome/end text as local to write in tex
    local text = text[`var']

    * write Welcome-/Endtext as section
    if type[`var'] == "WT" {
      file write cb `"\section*{`lab_bgn'}"' _n
      file write cb `"`text'"' _n(2)

      continue // skip to next variable (row of loop)
    }
    if type[`var'] == "ET" {
      file write cb `"\section*{`lab_end'}"' _n
      file write cb `"`text'"' _n(2)

      continue // skip to next variable (row of loop)
    }

    * if first var of group -> add group name as section + filter & random
    if group[`var'] != "" {

      * save text of group/filter/random as local to write in tex
      local group    = group[`var']
      local grp_fltr = grp_fltr[`var']
      local grp_rand = grp_rand[`var']

      file write cb `"\section{`group'}"' _n


      * add line for filter and random if at least one is provided
      if `"`grp_fltr'"' != "" | `"`grp_rand'"' != "" {
        if `"`grp_fltr'"' != "" file write cb `"`lab_grf': `grp_fltr'"' _n
        if `"`grp_rand'"' != "" file write cb `"`lab_rdg': `grp_rand'"' _n
        file write cb `"\vspace{.5cm} \newline"' _n
      }
    }

    * create variable title with variablename & label (if stata and provided)
    local variable = variable[`var']
    local varlabel = varlabel[`var']
    if `"`varlabel'"' != "" local title = `"`variable' --- `varlabel'"'
    else local title = `"`variable'"'

    * write minipage for each variable in tex document
    file write cb "\begin{minipage}{\textwidth}" _n
    file write cb `"\subsection*{`title'}"' _n

    * create information table of variable characteristics
    file write cb "\begin{tabularx}{\textwidth}{p{2.5cm}X}" _n

    *** loop through default/choosen varlist of variable characteristics
    foreach cat of local varlist {

      local cat_str = `cat'[`var']
      if `"`cat_str'"' != "" & `"`cat_str'"' != "."  {

        * get label for output from variable label or varname if no label
        local cat_lab: variable label `cat'
        if "`cat_lab'" == "" local cat_lab = "`cat'"

        * add mandatoy and/or hidden to questiontype
        if "`cat'" == "type" & (mandatory[`var'] != "" | hidden[`var'] != "") {
          if mandatory[`var'] != "" local cat_str = `"`cat_str' - "' + mandatory[`var']
          if hidden[`var'] != ""    local cat_str = `"`cat_str' - "' + hidden[`var']
        }

        * add N if other variable is given
        if "`cat'" == "other_var" & !mi(other_freq[`var']) {
          local cat_str = `"`cat_str' (N: "' + string(other_freq[`var']) + ")"
        }

        * skip file write if N if statistics will be shown seperatly
        if "`cat'" == "N" & !mi(mean[`var']) continue

        file write cb `"\textbf{`cat_lab'} & `cat_str' \\"' _n
      }
    }

    file write cb "\end{tabularx}" _n

    ***** loop for table of subvar and answer tables *****
    foreach mode in subvar `db'answer {

      * define mode specific label
      if "`mode'" == "subvar" 	  local mode_lab = `"`lab_var'"'
      if "`mode'" == "`db'answer" local mode_lab = `"`lab_cod'"'

      * check if subvar and answer available
      if !mi(`mode'_n[`var']) & qtype[`var'] != ":" {

        if `mode'_fltr_n[`var'] == 0 & `mode'_freq_1[`var'] == . local cond = 1
        if `mode'_fltr_n[`var'] >  0 & `mode'_freq_1[`var'] == . local cond = 2
        if `mode'_fltr_n[`var'] == 0 & `mode'_freq_1[`var'] < .  local cond = 3
        if `mode'_fltr_n[`var'] >  0 & `mode'_freq_1[`var'] < .  local cond = 4

        file write cb "\vspace{.5cm} \newline" _n
        file write cb "\bgroup" _n
        if `"`clrtblrow'"' != "" file write cb "\rowcolors{2}{white}{`clrtblrow'}" _n

        * begin table (if filter and freq 4 cols)
        if `cond' == 1 file write cb "\begin{tabularx}{\textwidth}{p{2.5cm}X}" _n
        if `cond' == 2 file write cb "\begin{tabularx}{\textwidth}{p{2.5cm}p{11cm}X}" _n
        if `cond' == 3 file write cb "\begin{tabularx}{\textwidth}{p{2.5cm}p{14cm}X}" _n
        if `cond' == 4 file write cb "\begin{tabularx}{\textwidth}{p{2.5cm}p{10cm}p{1.5cm}X}" _n

        file write cb "\toprule" _n

        * add table header (if filter 3 cols)
        if `cond' == 1 file write cb `"\textbf{`mode_lab'} & \textbf{`lab_lab'} \\"' _n
        if `cond' == 2 file write cb `"\textbf{`mode_lab'} & \textbf{`lab_lab'} & \textbf{Filter} \\"' _n
        if `cond' == 3 file write cb `"\textbf{`mode_lab'} & \textbf{`lab_lab'} & \textbf{N} \\"' _n
        if `cond' == 4 file write cb `"\textbf{`mode_lab'} & \textbf{`lab_lab'} & \textbf{N} & \textbf{Filter} \\"' _n

        file write cb "\midrule" _n

        * loop over number of subvars or answers
        local max_n = `mode'_n[`var']
        foreach row of numlist 1/`max_n' {

          local code = `mode'_code_`row'[`var']
          local text = `mode'_text_`row'[`var']
          capture: local fltr = `mode'_fltr_`row'[`var']
          capture: local freq = `mode'_freq_`row'[`var']

          * add row (if filter 3 cols)
          if `cond' == 1 file write cb `"`code' & `text' \\"' _n
          if `cond' == 2 file write cb `"`code' & `text' & `fltr' \\"' _n
          if `cond' == 3 file write cb `"`code' & `text' & `freq' \\"' _n
          if `cond' == 4 file write cb `"`code' & `text' & `freq' & `fltr' \\"' _n
        }

        * end table
        file write cb "\bottomrule" _n
        file write cb "\end{tabularx}" _n
        file write cb "\egroup" _n
      }
    }

    *** create 2 tables for special two-way arrays
    if qtype[`var'] == ":" {

      if subvar_fltr_n[`var'] == 0 local cond = 1
      if subvar_fltr_n[`var'] >  0 local cond = 2

      file write cb "\vspace{.5cm} \newline" _n
      file write cb "\bgroup" _n
      if `"`clrtblrow'"' != "" file write cb "\rowcolors{2}{white}{`clrtblrow'}" _n

      * begin table (if filter and freq 4 cols)
      if `cond' == 1 file write cb "\begin{tabularx}{\textwidth}{p{2.5cm}X}" _n
      if `cond' == 2 file write cb "\begin{tabularx}{\textwidth}{p{2.5cm}p{11cm}X}" _n

      file write cb "\toprule" _n

      * add table header (if filter 3 cols)
      if `cond' == 1 file write cb `"\textbf{Variable X} & \textbf{`lab_lab'} \\"' _n
      if `cond' == 2 file write cb `"\textbf{Variable X} & \textbf{`lab_lab'} & \textbf{Filter} \\"' _n

      file write cb "\midrule" _n

      * loop over number of subvars or answers
      local max_n1 = subvar_n1[`var']
      foreach row of numlist 1/`max_n1' {

        local code = subvar_code_`row'[`var']
        local text = subvar_text_`row'[`var']
        capture: local fltr = subvar_fltr_`row'[`var']

        * add row (if filter 3 cols)
        if `cond' == 1 file write cb `"`code' & `text' \\"' _n
        if `cond' == 2 file write cb `"`code' & `text' & `fltr' \\"' _n
      }

      * end table
      file write cb "\bottomrule" _n
      file write cb "\end{tabularx}" _n
      file write cb "\egroup" _n

      *** 2. table for y-axis Variable
      file write cb "\vspace{.25cm} \newline" _n
      file write cb "\bgroup" _n
      if `"`clrtblrow'"' != "" file write cb "\rowcolors{2}{white}{`clrtblrow'}" _n

      * begin table
      file write cb "\begin{tabularx}{\textwidth}{p{2.5cm}X}" _n
      file write cb "\toprule" _n

      * add table header
      file write cb `"\textbf{Variable Y} & \textbf{`lab_lab'} \\"' _n
      file write cb "\midrule" _n

      * loop over number of subvars or answers
      local min_n2 = `max_n1' + 1
      local max_n2 = subvar_n[`var']
      foreach row of numlist `min_n2'/`max_n2' {

        local code = subvar_code_`row'[`var']
        local text = subvar_text_`row'[`var']

        * add row (if filter 3 cols)
        file write cb `"`code' & `text' \\"' _n
      }

      * end table
      file write cb "\bottomrule" _n
      file write cb "\end{tabularx}" _n
      file write cb "\egroup" _n
    }


    **** table for statistics for numeric variables ****
    if !mi(mean[`var']) {

      foreach st of varlist N - max {
        local st_`st' = round(`st'[`var'], 0.01)
      }

      file write cb "\vspace{.5cm} \newline" _n
      file write cb "\bgroup" _n
      file write cb "\begin{tabularx}{\textwidth}{XXXXX}" _n

      file write cb `"\textbf{N} & \textbf{`lab_mea'} & \textbf{`lab_sd'} & \textbf{Mininum} & \textbf{Maximum} \\"' _n
      file write cb "\midrule" _n

      file write cb `"`st_N' & `st_mean' & `st_sd' & `st_min' & `st_max' \\"' _n

      file write cb "\bottomrule" _n
      file write cb "\end{tabularx}" _n
      file write cb "\egroup" _n
    }

    * end minipage add space to next minipage
    file write cb "\end{minipage}" _n
    file write cb "\vspace{1cm}" _n(2)
  }

  * end the tex document
  if "`frag'" == "" {
    file write cb `"\end{document}"' _n
  }

  file close cb
}

********* output for docx and pdf **********************************************

else {

  * specifie table option just for docx output
  if "`output'" == "docx" local tblopt_l = `"layout(autofitcontents)"'
  if "`output'" == "docx" local tblopt_c = `"shading(`rgb')"'
  if "`output'" == "pdf"  local tblopt_l = `"spacing(after, .4cm)"'
  if "`output'" == "pdf"  local tblopt_c = `""'

  local margins = `margins' / 10 // value for margins from mm to cm

  capture: put`output' clear
  put`output' begin, `landscape' margin(all, `margins' cm) font(arial)


  *** Titlepage
  if "`titlepage'" != "" {

    put`output' paragraph, halign(center)
    put`output' text (" ")
    put`output' paragraph, halign(center) spacing(before, 2cm)
    put`output' text ("Codebook:"), bold font(, 26)

    // survey title
    put`output' paragraph, halign(center)
    put`output' text ("`: data label'"), bold font(, 28)

    // author/admin + email
    put`output' paragraph, halign(center) spacing(before, 1.5cm)
    put`output' text (`_dta[note1]'), bold font(, 20)
    if "`_dta[note2]'" != "" {
      put`output' paragraph, halign(center)
      put`output' text (`_dta[note2]'), bold font(, 20)
    }

    // date of codebook creation
    put`output' paragraph, halign(center) spacing(before, .5cm)
    put`output' text ("$S_DATE"), bold font(, 20)

    put`output' paragraph, halign(center) spacing(after, 2cm)
    put`output' text (" ")

    // table with other survey information
    put`output' table title_tbl = (1, 2), halign(center) border(all, nil) width(80%)

    local tbl_row = 1

    forval num = 3/8 {

      display "`tbl_row' & `num': " `_dta[note`num']'

      if `_dta[note`num']' != "" {
        put`output' table title_tbl(`tbl_row', 1) = ("`lab_title_`num'':"), bold halign(right) font(, 16)
        put`output' table title_tbl(`tbl_row', 2) = (`_dta[note`num']'), font(, 16)

        * add extra row
        put`output' table title_tbl(`tbl_row', .), addrows(1) nosplit

        local ++tbl_row
      }
    }

    put`output' sectionbreak
  }


  *** loop over varlist
  local max = _N
  foreach var of numlist 1/`max' {

    display as text variable[`var']

    * write Welcome-/Endtext as section header
    if inlist(type[`var'], "WT", "ET") {

      if type[`var'] == "ET" put`output' sectionbreak
      put`output' paragraph, spacing(after, .2cm)
      if type[`var'] == "WT" put`output' text ("`lab_bgn'"), bold font(, 22)
      if type[`var'] == "ET" put`output' text ("`lab_end'"), bold font(, 22)

      local text = text[`var']

      put`output' paragraph, spacing(after, 2cm)
      put`output' text (`"`text'"') //, font(, 14)

      continue // skip to next variable (row of loop)
    }

    * if first var of group -> add group name as section + filter & random
    if group[`var'] != "" {

      * add group title
      if `var' > 1 put`output' sectionbreak // just sectionbreak if welcometext
      put`output' paragraph, spacing(after, .2cm)
      put`output' text (group[`var']), bold font(, 22)

      * add table for filter and random if at least one is provided
      if grp_fltr[`var'] != "" | grp_rand[`var'] != "" {

        put`output' table tblgr`var' = (1, 2), border(all, nil) width(100%) `tblopt_l'

        local tblgrrow`var' = 1 // local row indicator for if condition table

        * add table row for filter if provided
        if grp_fltr[`var'] != "" {
          put`output' table tblgr`var'(`tblgrrow`var'', 1) = ("`lab_grf':"), bold
          put`output' table tblgr`var'(`tblgrrow`var'', 2) = (grp_fltr[`var'])

          if grp_rand[`var'] != "" put`output' table tblgr`var'(`tblgrrow`var'', .), addrows(1) nosplit

          local ++tblgrrow`var' // set up table row indicator + 1
        }
        * add table row for random group name if provided
        if grp_rand[`var'] != "" {
          // put`output' table tblgr`var'(`tblgrrow`var'', .), addrows(1) nosplit
          put`output' table tblgr`var'(`tblgrrow`var'', 1) = ("`lab_rdg':"), bold
          put`output' table tblgr`var'(`tblgrrow`var'', 2) = (grp_rand[`var'])
        }
      }
    }

    * create title with variablename & label (if stata and provided)
    local variable = variable[`var']
    local varlabel = varlabel[`var']
    if `"`varlabel'"' != "" local title = `"`variable' - `varlabel'"'
    else local title = `"`variable'"'

    put`output' paragraph, spacing(after, .2cm)
    put`output' text ("`title'"), bold font(, 14)

    * initialize table for variable characteristics
    put`output' table tbl`var' = (1, 2), border(all, nil) width(100%) `tblopt_l'

    * loop through default/choosen varlist of variable characteristics
    local row = 1 // initialize row counter
    foreach cat of local varlist {

      local cat_str = `cat'[`var']
      if `"`cat_str'"' != "" & `"`cat_str'"' != "." {

        * get label for output from variable label or varname if no label
        local cat_lab: variable label `cat'
        if "`cat_lab'" == "" local cat_lab = "`cat'"

        * add mandatoy and/or hidden to questiontype
        if "`cat'" == "type" & (mandatory[`var'] != "" | hidden[`var'] != "") {
          if mandatory[`var'] != "" local cat_str = `"`cat_str' - "' + mandatory[`var']
          if hidden[`var'] != ""    local cat_str = `"`cat_str' - "' + hidden[`var']
        }

        * add N if other variable is given
        if "`cat'" == "other_var" & !mi(other_freq[`var']) {
          local cat_str = `"`cat_str' (N: "' + string(other_freq[`var']) + ")"
        }

        * skip file write if N if statistics will be shown seperatly
        if "`cat'" == "N" & !mi(mean[`var']) continue

        * add variable characteristic label and values
        put`output' table tbl`var'(`row', 1) = ("`cat_lab'"), bold
        put`output' table tbl`var'(`row', 2) = (`"`cat_str'"')

        * add extra row
        put`output' table tbl`var'(`row', .), addrows(1) nosplit

        local ++row
      }
    }

    put`output' table tbl`var'(`row', .), drop // remove last empty row


    ***** loop for table of subvar and answer tables *****
    foreach mode in subvar `db'answer {

      * define mode specific label
      if "`mode'" == "subvar" 	  local mode_lab = `"`lab_var'"'
      if "`mode'" == "`db'answer" local mode_lab = `"`lab_cod'"'

      * check if subvar and answer available
      if !mi(`mode'_n[`var']) & qtype[`var'] != ":" {

        if `mode'_fltr_n[`var'] == 0 & `mode'_freq_1[`var'] == . local cond = 1
        if `mode'_fltr_n[`var'] >  0 & `mode'_freq_1[`var'] == . local cond = 2
        if `mode'_fltr_n[`var'] == 0 & `mode'_freq_1[`var'] < .  local cond = 3
        if `mode'_fltr_n[`var'] >  0 & `mode'_freq_1[`var'] < .  local cond = 4

        * create table (if filter 3 cols)
        if `cond' == 1 put`output' table tbl`mode'`var' = (1, 2), border(all, nil) width(100%) `tblopt_l'
        if `cond' == 2 put`output' table tbl`mode'`var' = (1, 3), border(all, nil) width(100%) `tblopt_l'
        if `cond' == 3 put`output' table tbl`mode'`var' = (1, 3), border(all, nil) width(100%) `tblopt_l'
        if `cond' == 4 put`output' table tbl`mode'`var' = (1, 4), border(all, nil) width(100%) `tblopt_l'

        * add table header (if filter 3 cols)
        put`output' table tbl`mode'`var'(1, 1) = ("`mode_lab'"), bold border(top) border(bottom)
        put`output' table tbl`mode'`var'(1, 2) = ("`lab_lab'"), bold border(top) border(bottom)
        if `cond' == 2 put`output' table tbl`mode'`var'(1, 3) = ("Filter"), bold border(top) border(bottom)
        if `cond' == 3 put`output' table tbl`mode'`var'(1, 3) = ("N"), bold border(top) border(bottom)
        if `cond' == 4 put`output' table tbl`mode'`var'(1, 3) = ("N"), bold border(top) border(bottom)
        if `cond' == 4 put`output' table tbl`mode'`var'(1, 4) = ("Filter"), bold border(top) border(bottom)

        local tblrows = `mode'_n[`var'] + 1 // count max table rows (+ 1 b/c header)

        forval tblrow = 2/`tblrows' {

          local row = `tblrow' - 1 // row = table row - header = # of subvar/answer

          * add row for each subvar/answer if not last row (every second colored background)
          if mod(`row', 2) == 0 put`output' table tbl`mode'`var'(`row',.), addrows(1) nosplit `tblopt_c' // odd
          if mod(`row', 2) == 1 put`output' table tbl`mode'`var'(`row',.), addrows(1) nosplit // even

          * add content for each row
          put`output' table tbl`mode'`var'(`tblrow', 1) = (`mode'_code_`row'[`var'])
          put`output' table tbl`mode'`var'(`tblrow', 2) = (`mode'_text_`row'[`var'])
          if `cond' == 2 put`output' table tbl`mode'`var'(`tblrow', 3) = (`mode'_fltr_`row'[`var'])
          if `cond' == 3 put`output' table tbl`mode'`var'(`tblrow', 3) = (`mode'_freq_`row'[`var'])
          if `cond' == 4 put`output' table tbl`mode'`var'(`tblrow', 3) = (`mode'_freq_`row'[`var'])
          if `cond' == 4 put`output' table tbl`mode'`var'(`tblrow', 4) = (`mode'_fltr_`row'[`var'])
        }

        * add line at bottom if last row
        if mod(`tblrows', 2) == 0 put`output' table tbl`mode'`var'(`tblrows',.), border(bottom) nosplit `tblopt_c' // odd
        if mod(`tblrows', 2) == 1 put`output' table tbl`mode'`var'(`tblrows',.), border(bottom) nosplit // even
      }
    }

    *** create 2 tables for special two-way arrays
    if qtype[`var'] == ":" {

      *** Table 1 (Variable X)
      if subvar_fltr_n[`var'] == 0 & subvar_freq_1[`var'] == . local cond = 1
      if subvar_fltr_n[`var'] >  0 & subvar_freq_1[`var'] == . local cond = 2

      * begin table (if filter 3 cols)
      if `cond' == 1 put`output' table tblsubvar`var'1 = (1, 2), border(all, nil) width(100%) `tblopt_l'
      if `cond' == 2 put`output' table tblsubvar`var'1 = (1, 3), border(all, nil) width(100%) `tblopt_l'

      * add table header (if filter 3 cols)
      put`output' table tblsubvar`var'1(1, 1) = ("Variable X"), bold border(top) border(bottom)
      put`output' table tblsubvar`var'1(1, 2) = ("`lab_lab'"), bold border(top) border(bottom)
      if `cond' == 2 put`output' table tblsubvar`var'1(1, 3) = ("Filter"), bold border(top) border(bottom)


      local tblrows = subvar_n1[`var'] + 1 // count max table rows (+ 1 b/c header)

      forval tblrow = 2/`tblrows' {

        local row = `tblrow' - 1 // row = table row - header = # of subvar/answer

        * add row for each subvar/answer if not last row (every second colored background)
        if mod(`row', 2) == 0 put`output' table tblsubvar`var'1(`row',.), addrows(1) nosplit `tblopt_c' // odd
        if mod(`row', 2) == 1 put`output' table tblsubvar`var'1(`row',.), addrows(1) nosplit // even

        * add content for each row
        put`output' table tblsubvar`var'1(`tblrow', 1) = (subvar_code_`row'[`var'])
        put`output' table tblsubvar`var'1(`tblrow', 2) = (subvar_text_`row'[`var'])
        if `cond' == 2 put`output' table tblsubvar`var'1(`tblrow', 3) = (subvar_fltr_`row'[`var'])
      }

      * add line at bottom if last row
      if mod(`tblrows', 2) == 0 put`output' table tblsubvar`var'1(`tblrows',.), border(bottom) nosplit `tblopt_c' // odd
      if mod(`tblrows', 2) == 1 put`output' table tblsubvar`var'1(`tblrows',.), border(bottom) nosplit // even


      *** Table 1 (Variable Y)
      put`output' table tblsubvar`var'2 = (1, 2), border(all, nil) width(100%) `tblopt_l'

      * add table header
      put`output' table tblsubvar`var'2(1, 1) = ("Variable Y"), bold border(top) border(bottom)
      put`output' table tblsubvar`var'2(1, 2) = ("`lab_lab'"), bold border(top) border(bottom)

      local tblrows2 = subvar_n2[`var'] + 1 // count max table rows (+ 1 b/c header)
      forval tblrow = 2/`tblrows2' {

        local row = `tblrow' - 1  // row = table row - header = # of subvar/answer
        local row2 = `row' + subvar_n1[`var']

        * add row for each subvar/answer if not last row (every second colored background)
        if mod(`row', 2) == 0 put`output' table tblsubvar`var'2(`row',.), addrows(1) nosplit `tblopt_c' // odd
        if mod(`row', 2) == 1 put`output' table tblsubvar`var'2(`row',.), addrows(1) nosplit // even

        * add content for each row
        put`output' table tblsubvar`var'2(`tblrow', 1) = (subvar_code_`row2'[`var'])
        put`output' table tblsubvar`var'2(`tblrow', 2) = (subvar_text_`row2'[`var'])
      }

      * add line at bottom if last row
      if mod(`tblrows2', 2) == 0 put`output' table tblsubvar`var'2(`tblrows2',.), border(bottom) nosplit `tblopt_c' // odd
      if mod(`tblrows2', 2) == 1 put`output' table tblsubvar`var'2(`tblrows2',.), border(bottom) nosplit // even
    }


    **** table for statistics for numeric variables ****
    if !mi(mean[`var']) {

      foreach st of varlist N - max {
        local st_`st' = round(`st'[`var'], 0.01)
      }

      put`output' table tblst`var' = (1, 5), border(all, nil) width(100%) `tblopt_l'

      put`output' table tblst`var'(1, 1) = ("N"), bold border(top) border(bottom)
      put`output' table tblst`var'(1, 2) = ("`lab_mea'"), bold border(top) border(bottom)
      put`output' table tblst`var'(1, 3) = ("`lab_sd'"), bold border(top) border(bottom)
      put`output' table tblst`var'(1, 4) = ("Minimum"), bold border(top) border(bottom)
      put`output' table tblst`var'(1, 5) = ("Maximum"), bold border(top) border(bottom)

      put`output' table tblst`var'(1, .), addrows(1) nosplit

      put`output' table tblst`var'(2, 1) = (`st_N')
      put`output' table tblst`var'(2, 2) = (`st_mean')
      put`output' table tblst`var'(2, 3) = (`st_sd')
      put`output' table tblst`var'(2, 4) = (`st_min')
      put`output' table tblst`var'(2, 5) = (`st_max')

      put`output' table tblst`var'(2, .), border(bottom) nosplit
    }
  }

  put`output' save `"`save'"', replace
}

restore

end

exit
