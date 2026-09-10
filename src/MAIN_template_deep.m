% Main template to process deep floats in DM  
% Should be run in the directory ./src/
% Other steps can be necessary to fully process deep floats in DM (pressure adjustements, thermal lag adjustements...)

% configuration file : config.txt
% tested with Matlab '9.9.0.1467703 (R2020b)'

% EXTERNAL LIB
% Already in ../lib: seawater_330_its90 and +libargo package.
% You will need to install GSW matlab routines( https://github.com/TEOS-10/GSW-Matlab/releases) - tested with version 3.04


clear all 
close all

path(pathdef)
addpath(genpath('../lib/gsw_matlab_v3_04'))
addpath('../lib/seawater_330_its90/')
addpath('../lib/')

flt_name = 6902882;

% 1. Determine the Cpcor Correction
%    if reference CTD are available (e.g launch CTD, nearby CTD) you can compute an optimum Cpcor_new value
%    see : https://github.com/ArgoDMQC/Deep_Argo_DMTools/tree/master/DM_CPCor
%    In delayed-mode, the optimized CPcor_new value should be used whenever it is available and is checked to be robust.
%    Otherwise, the recommended CPcor_new value (-11.7e-8) should be used.
%    see Argo DMQC Manual, section 3.10 for more details.

% 2. Cpcor correction is applied in intermediate netcdf files (PSAL_ADJUSTED)
% These intermediate files are not intended to be distributed on the gdac.
% Ok for the Deep Arvor float. Requires modification for floats that do not auto-correct pressure.
addpath(genpath('./correct_cpcor/'))

corr_cpcor_in_netcdf(flt_name,'NEW_CPCOR',-11.7e-8);

% 3. Creates the OWC source file using adjusted PARAM
addpath(genpath('./ow_source/'))

create_float_source(flt_name,'force','adjusted');

% 4. RUN OWC and obtain calibration files (see https://github.com/ArgoDMQC/matlab_owc)

% 5. Creates final DMQC files with CpCOR adjustement, OWC correction if any and final Calibration/History sections.

addpath(genpath('./create_dm_files/'))

MAIN_write_dmqc_files(flt_name)

% In the interactive part:
% To the question 'How do you want to store calibration information?', answer 'N_CALIB=N_CALIB+1'
% and to the question 'Has salinity previously adjusted for Cpcor?' , answer   'YES'


