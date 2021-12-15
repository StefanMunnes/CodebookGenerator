program define cbgen, nclass

syntax [using/], save(string) [replace ///
  LSpath(string) LANGuage(string) lsonly panel ///
  VARstub(string) NOAuto ///
  drop(varlist) add(varlist) lslab textno ///
  german CLRtblrow(string) tblmax(integer 16) NOSTatistics lsdrop stdrop ///
  frag NONUMbering LANDscape]

version 12

* 1. use cbdata to create data for cbout
local cbdata_opts = `""'

if "`lspath'" != ""  local cbdata_opts = `"`cbdata_opts' lspath("`lspath'")"'
if "`varstub'" != "" local cbdata_opts = `"`cbdata_opts' varstub("`varstub'")"'

if "`using'" == "" cbdata, `cbdata_opts' `replace' `lsonly' `noauto'
else cbdata using "`using'", `cbdata_opts' `replace' `lsonly' `noauto'


* 2. use cbout to create output file

cbout, save("`save'") `replace' `nonumbering' `german' // `frag'

end

exit
