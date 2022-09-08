# dm_floats_deep
Matlab tools for creating OWC input files (with Cpcor corrected) and writing D_files from OWC results : for DEEP floats


* in **\/src\/correct_cpcor** you will find routines for correcting PSAL with a new CPCor value -> PSAL_ADJUSTED
and write intermediate netcdf files (that will be the input for create_float_source.m and MAIN_write_dmqc_files.m)
* in **\/src\/ow_source** you will find routines for creating OWC software input file (i.e. .mat file in /float_source/) from the netcdf files.
* in **\/src\/create_dm_files** you will find routines for writing core Argo D-files using salinity calibration from OWC software


## How to use?
Modify \/src\/config.txt  to set your own paths

Use Main_template_deep.m to process deep floats in Delayed Mode.
