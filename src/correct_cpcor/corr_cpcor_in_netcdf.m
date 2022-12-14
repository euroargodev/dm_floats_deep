% ========================================================
%   USAGE :   corr_cpcor_in_netcdf(flt_name)
%             corr_cpcor_in_netcdf(flt_name,'NEW_CPCOR',-13.5e-8)
%   PURPOSE : correct PSAL with a new CPCor value -> PSAL_ADJUSTED
%             and write an intermediate netcdf file (that will be the input for create_float_source.m and MAIN_write_dmqc_files.m)
%             This code should be adapted if DM correction are needed for pressure (e.g Apex floats)
% -----------------------------------
%   INPUT :
%    floatname  (char)  e.g. '6900258'
%   OPTIONNAL INPUT :
%    'NEW_CPCOR'     (float)    '-13.5e-8' (default): median CPCor values used to correct float salinity data
%    'NEW_M'         (float)    '1' (default) : multiplicative factor for
%    conservative conductivity
% -----------------------------------
%   OUTPUT :
% -----------------------------------
%   HISTORY  : created C. Cabanes - 2020
%-------------------------------------
%  EXTERNAL LIB
%  package +libargo:  addpath('dm_floats_deep/lib/')
%  GSW matlab routines:  addpath('dm_floats_deep/lib/gsw_matlab_v3_04_TR/')
% ========================================================

function corr_cpcor_in_netcdf(flt_name,varargin)

if isnumeric(flt_name)
    floatname      =cellstr( num2str(flt_name));
else
    if iscell(flt_name)==0
        floatname=cellstr(flt_name);
    end
end

CONFIG=load_configuration('./config.txt');

n=length(varargin);

if n/2~=floor(n/2)
    error('check the imput arguments')
end


f=varargin(1:2:end);
c=varargin(2:2:end);
s = cell2struct(c,f,2);

% SBE values
global CTcor_SBE  CPcor_SBE
CPcor_SBE = -9.5700E-8;
CTcor_SBE =  3.2500E-6;


% New Default values
PARAM.NEW_CPCOR=-13.5e-8;
PARAM.NEW_M=1;
if isfield(s,'NEW_CPCOR')==1;PARAM.NEW_CPCOR=s.NEW_CPCOR;end;
if isfield(s,'NEW_M')==1;PARAM.NEW_M=s.NEW_M;end;
disp(' ')
disp(['NEW CPCOR is ' num2str(PARAM.NEW_CPCOR)])
if PARAM.NEW_M~=1
disp(['NEW M value is ' num2str(PARAM.NEW_M)])
end

% find Core files.
for ifloat=1:length(floatname)
    thefloatname=floatname{ifloat};
    thedacname='';
    IncludeDescProf=1;
    [file_list] = libargo.select_float_files_on_ftp(thefloatname,thedacname,CONFIG.DIR_FTP,'C',IncludeDescProf);
   
   

    for ifiles=1:length(file_list)
        
        % read single-cycle files
        %------------------------
        file_name = [CONFIG.DIR_FTP thedacname '/' thefloatname '/profiles/' file_list{ifiles} ];
        if ~exist([CONFIG.DIR_DM_CPCOR thedacname '/' thefloatname '/profiles/'])
        mkdir([CONFIG.DIR_DM_CPCOR thedacname '/' thefloatname '/profiles/']);
        end
        file_name_out = [CONFIG.DIR_DM_CPCOR thedacname '/' thefloatname '/profiles/' file_list{ifiles} ];
        [F,Dim,G] = libargo.read_netcdf_allthefile(file_name);
        F = libargo.replace_fill_bynan(F);
        Forig = F;
        
        isprimary = find(libargo.findstr_tab(F.vertical_sampling_scheme.data,'Primary sampling'));
        notisprimary = find(libargo.findstr_tab(F.vertical_sampling_scheme.data,'Near-surface sampling'));
        F.data_mode.data(notisprimary)='A';
        
        % Fill adjusted fields and error :
        % -------------------------------
        % TEMP_ADJUSTED
        F.temp_adjusted.data = F.temp.data;
        F.temp_adjusted_qc.data = F.temp_qc.data;
        
        F.temp_adjusted_error.data = 0.002*ones(Dim.n_prof.dimlength,Dim.n_levels.dimlength);
        F.temp_adjusted_error.data(isnan(F.temp_adjusted.data)) = NaN;
        
        % PRES_ADJUSTED if not already filled
        all_fillval = libargo.check_isfillval_prof(F,'pres_adjusted_error');
        % For provor/arvor there is no pressure correction in DM. CHANGE here if correction is needed
        F.pres_adjusted.data = F.pres.data;
        F.pres_adjusted_qc.data = F.pres_qc.data;
        
        F.pres_adjusted_error.data = (2.5/6000)*F.pres_adjusted.data+2; % improved error for deep floats.
       
       % PSAL_ADJUSTED
        F.psal_adjusted_error.data = 0.004*ones(Dim.n_prof.dimlength,Dim.n_levels.dimlength);
        F.psal_adjusted_error.data(isnan(F.temp_adjusted.data)) = NaN;
        
        cnew=[PARAM.NEW_CPCOR,PARAM.NEW_M];
        psal_argo_new = change_cpcor(F,cnew);
        
        F.psal_adjusted.data = psal_argo_new;
        
        
        % FILL N_CALIB=1 with  CPCOR calibration infos
        % other PSAL adjustments (OWC) will be filled in N_CALIB>1
        n_calib=1;
        theparameters = strtrim(squeeze(F.parameter.data(isprimary,n_calib,:,:)));
        
        %PSAL
        ind_psal = ismember(cellstr(theparameters),'PSAL');
        
        thestr=(['new conductivity = original conductivity * (1 + delta*TEMP + CPcor_SBE*PRES) / (1 + delta*TEMP_ADJUSTED + CPcor_new*PRES_ADJUSTED)']);
        l_thestr=length(thestr);
        F.scientific_calib_equation.data(isprimary,n_calib,ind_psal,:) = F.scientific_calib_equation.FillValue_;
        F.scientific_calib_equation.data(isprimary,n_calib,ind_psal,1:l_thestr) = thestr;
       
        thestr=(['CPcor_new = ' num2str(PARAM.NEW_CPCOR) '; CPcor_SBE = ' num2str(CPcor_SBE) '; delta = ' num2str(CTcor_SBE)]);		
        l_thestr=length(thestr);
        F.scientific_calib_coefficient.data(isprimary,n_calib,ind_psal,:) = F.scientific_calib_coefficient.FillValue_;
        F.scientific_calib_coefficient.data(isprimary,n_calib,ind_psal,1:l_thestr) = thestr;
      
        thestr=(['New conductivity computed by using a different CPcor value from that provided by Sea-Bird.']);
        l_thestr=length(thestr);
        F.scientific_calib_comment.data(isprimary,n_calib,ind_psal,:) = F.scientific_calib_comment.FillValue_;
        F.scientific_calib_comment.data(isprimary,n_calib,ind_psal,1:l_thestr) = thestr;
        
        thedate=datestr(now,'yyyymmddHHMMSS');
        F.scientific_calib_date.data(isprimary,n_calib,ind_psal,:)=thedate;
        
        %Fill N_CALIB==1 for PRES  (here :no adjustement. CHANGE if any)
        ind_pres = ismember(cellstr(theparameters),'PRES');
        
        thestr=(['PRES_ADJUSTED = PRES']);
        l_thestr=length(thestr);
        F.scientific_calib_equation.data(isprimary,n_calib,ind_pres,:) = F.scientific_calib_equation.FillValue_;
        F.scientific_calib_equation.data(isprimary,n_calib,ind_pres,1:l_thestr) = thestr;
      
        thestr=(['none']);
        l_thestr=length(thestr);
        F.scientific_calib_coefficient.data(isprimary,n_calib,ind_pres,:) = F.scientific_calib_coefficient.FillValue_;
        F.scientific_calib_coefficient.data(isprimary,n_calib,ind_pres,1:l_thestr) = thestr;

        thestr=(['This float is autocorrecting pressure. Data is good within the specified error.']);
        l_thestr=length(thestr);
        F.scientific_calib_comment.data(isprimary,n_calib,ind_pres,:) = F.scientific_calib_comment.FillValue_;
        F.scientific_calib_comment.data(isprimary,n_calib,ind_pres,1:l_thestr) = thestr;
        F.scientific_calib_date.data(isprimary,n_calib,ind_pres,:)=thedate;
        
        %Fill N_CALIB==1 for TEMP (no adjustement here)
        ind_temp = ismember(cellstr(theparameters),'TEMP');
        thestr=(['TEMP_ADJUSTED = TEMP']);
        l_thestr=length(thestr);
        F.scientific_calib_equation.data(isprimary,n_calib,ind_temp,:) = F.scientific_calib_equation.FillValue_;
        F.scientific_calib_equation.data(isprimary,n_calib,ind_temp,1:l_thestr) = thestr;
       
        thestr=(['none']);
        l_thestr=length(thestr);
        F.scientific_calib_coefficient.data(isprimary,n_calib,ind_temp,:) = F.scientific_calib_coefficient.FillValue_;
        F.scientific_calib_coefficient.data(isprimary,n_calib,ind_temp,1:l_thestr) = thestr;
      
        thestr=(['Data is good within the specified error.']);
        l_thestr=length(thestr);
        F.scientific_calib_comment.data(isprimary,n_calib,ind_temp,:) = F.scientific_calib_comment.FillValue_;
        F.scientific_calib_comment.data(isprimary,n_calib,ind_temp,1:l_thestr) = thestr;
        F.scientific_calib_date.data(isprimary,n_calib,ind_temp,:)=thedate;
       
        
        % INITIALIZE N_CALIB=2 for further  adjustements (OWC)
        n_calib=2;
        thesize=size(F.scientific_calib_equation.data);
        format_version=str2num(F.format_version.data');
        
        for iprof=1:thesize(1)
            for iparam=1:thesize(3)
                F.scientific_calib_equation.data(iprof,n_calib,iparam,:)=F.scientific_calib_equation.FillValue_;
                F.scientific_calib_coefficient.data(iprof,n_calib,iparam,:)=F.scientific_calib_coefficient.FillValue_;
                F.scientific_calib_comment.data(iprof,n_calib,iparam,:)=F.scientific_calib_comment.FillValue_;
                if format_version<2.3
                    F.calibration_date.data(iprof,n_calib,iparam,:)=F.calibration_date.FillValue_;
                else
                    F.scientific_calib_date.data(iprof,n_calib,iparam,:)=F.scientific_calib_date.FillValue_;
                end
            end
        end
        Dim.n_calib.dimlength=2;
        
        %================== HISTORY fields
        %define new_hist=N_HISTORY+1
        %if PARAM.NEW_CPCOR~=-13.5e-8  % add a new history step

            allfields = fieldnames(F);
            ii = strfind(allfields,'history_');
            is_history = find(~cellfun('isempty',ii));
            n_prof=isprimary;
            F = libargo.check_FirstDimArray_is(F,'N_HISTORY');
            
            if strfind(squeeze(F.history_software.data(Dim.n_history.dimlength,n_prof,:))','DMCP')
                new_hist = Dim.n_history.dimlength;   % erase the previous one => we are just running again corr_cpcor
            else
                new_hist = Dim.n_history.dimlength+1; % add an other entry
                
                
                % initialize a new history
                if Dim.n_history.dimlength~=0
                    [F_ex,Dim_ex]=libargo.extract_profile_dim(F,Dim,'N_HISTORY',1);
                    for ik = is_history'
                        oneChamp =allfields{ik};
                        ii=F_ex.(oneChamp).data~=F_ex.(oneChamp).FillValue_;
                        F_ex.(oneChamp).data(ii)=F_ex.(oneChamp).FillValue_;
                    end
                    [F,Dim] = libargo.cat_profile_dim(F,F_ex,Dim,Dim_ex,'N_HISTORY');
                else
                    for ik = is_history'
                        oneChamp =allfields{ik};
                        siz(1)=1;
                        for tk=2:length(F.(oneChamp).dim)
                            siz(tk) = Dim.(lower(F.(oneChamp).dim{tk})).dimlength;
                        end
                        F.(oneChamp).data = repmat(FLD_ex.(oneChamp).FillValue_,siz);
                        Dim.n_history.dimlength=1;
                    end
                end
            end
            
            % fill HISTORY section
            institution=CONFIG.OPERATOR_INSTITUTION;
            l_in=length(institution);
            F.history_institution.data(new_hist,n_prof,:)= F.history_institution.FillValue_;
            F.history_institution.data(new_hist,n_prof,1:l_in)=institution;
            
            step='ARSQ';
            F.history_step.data(new_hist,n_prof,:)=F.history_step.FillValue_;
            F.history_step.data(new_hist,n_prof,:)=step;
            
            soft='DMCP';
            l_so=length(soft);
            F.history_software.data(new_hist,n_prof,:)=F.history_software.FillValue_;
            F.history_software.data(new_hist,n_prof,1:l_so)=soft;
            
            
            soft_release='1.0';
            l_so_r=length(soft_release);
            F.history_software_release.data(new_hist,n_prof,:)=F.history_software_release.FillValue_;
            F.history_software_release.data(new_hist,n_prof,1:l_so_r)=soft_release;
%             reference=' ';
%             l_ref=length(reference);
%             F.history_reference.data(new_hist,n_prof,:)=F.history_reference.FillValue_;
%             F.history_reference.data(new_hist,n_prof,1:l_ref)=reference;
            
            action='IP';
            l_ac=length(action);
            F.history_action.data(new_hist,n_prof,:)=F.history_action.FillValue_;
            F.history_action.data(new_hist,n_prof,1:l_ac)=action;
            
            F.history_date.data(new_hist,n_prof,:)=thedate;
            
            parameter='PSAL';
            l_pa=length(parameter);
            F.history_parameter.data(new_hist,n_prof,:)=F.history_parameter.FillValue_;
            F.history_parameter.data(new_hist,n_prof,1:l_pa)=parameter;
            
        %end
        Fres=F;
        F=libargo.replace_nan_byfill(F);
        libargo.create_netcdf_allthefile(F,Dim,file_name_out,G)
        
        
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function psal_argo_new = change_cpcor(F,cnew)

global CTcor_SBE  CPcor_SBE


pres_argo = F.pres.data;
pres_argo_corr = F.pres_adjusted.data;
psal_argo = F.psal.data;
temp_argo = F.temp.data;
temp_argo_corr = F.temp_adjusted.data;

cond_argo = gsw_C_from_SP(psal_argo,temp_argo,pres_argo);

% back out the float raw conductivities using the nominal CTD
% values from SBE.
a1 = (1 + CTcor_SBE.*temp_argo + CPcor_SBE.*pres_argo);
cond_argo_raw = cond_argo.*a1;


CPcor_new = cnew(1);
M = cnew(2);
b1 = (1 + CTcor_SBE.*temp_argo_corr + CPcor_new.*pres_argo_corr);

cond_argo_new = M*cond_argo_raw./b1;

% compute the corresponding psal
psal_argo_new = gsw_SP_from_C(cond_argo_new,temp_argo_corr,pres_argo_corr);

