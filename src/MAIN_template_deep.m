% Main template to process deep floats in DM  
% Should be run in the directory ./src/
% Other steps can be necessary to fully process deep floats in DM (pressure adjustements, thermal lag adjustements...)

% configuration file : config.txt
% tested with Matlab '9.9.0.1467703 (R2020b)'


clear all 
close all

path(pathdef)
addpath(genpath('../lib/gsw_matlab_v3_04_TR'))
addpath('../lib/seawater_330_its90/')
addpath('../lib/')

flt_name = 6902882;

% 1. Cpcor correction is applied in intermediate netcdf files (PSAL_ADJUSTED)
% These intermediate files are not intended to be distributed on the gdac.
addpath(genpath('./correct_cpcor/'))

corr_cpcor_in_netcdf(flt_name,'NEW_CPCOR',-13.58e-8);

% 2. Creates the OWC source file using adjusted PARAM
addpath(genpath('./ow_source/'))

create_float_source(flt_name,'force','adjusted');

% 3. RUN OWC and obtain calibration files (see https://github.com/ArgoDMQC/matlab_owc)

% 4. Creates final DMQC files with CpCOR adjustement, OWC correction if any and final Calibration/History sections.

addpath(genpath('./create_dm_files/'))

MAIN_write_dmqc_files(flt_name)


