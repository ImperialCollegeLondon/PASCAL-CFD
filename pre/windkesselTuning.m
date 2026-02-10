%% WINDKESSEL TUNING SCRIPT
% v1 - W.Kaihong - May 2022 - Base code for single patient.
% v2 - A.Vignolo - Nov 2023 - Code documentation and extention for
%          an arbitrary number of patients. Input is redirected to a master
%          project Excel file. Missing arteries management was improved,
%          with multipe available procedures. Multi-reference capabilities
%          for literature flow split factores was implemented.
% v3 - A.Vignolo - Dec 2023 - Bug fix, radius should be in mm for resistace
%          computation. Additional correction, according to Raymond et al
%          (2009) is implemented for cases yielding negative Rp values.
%          This patients, usually corresponding to small abdominal aortic
%          branches, are listed in a new output file.
% v4 - A.Vignolo - Feb 2025 - Integrated warnings for results.
%
% This script implements the methodology for calculating the parameters for
% three-parameter Windkessel models for the aortic branches described in
% Pirola et al (2019) (see both the paper and the supplementary material).
% Input data should contain cross-section area for each patient, for all
% the arteries considered (Inlet, IA, LCCA, LSA, CA, SMA, RRA, LRA, RIA,
% LIA). Areas are assumed to be in mm.
clc;
clearvars;

%% Define input parameters and some options
% Manually check that the path for the input data file, the sheet names,
% and the selected ranges match the structure of your case. Check the
% 'Import data' section within this script.

% Define what to do with intermediate missing branches. Options:
    % 1 - Split flow among the LRI and the RIA, proportionally to their outler area.
    % 2 - Split flow among all considered branches, proportionally to their outlet area.
missingArteryManagment = 2;

% Define which reference to use for flow split factors
    % 1 - Split factors are taken from Kaihong's numbers, unknown author
    %     Includes IA, LCCA, LSA, CA, SMA, RRA, LRA, RIA, LIA.
    % 2 - Split factor are taken from Moore & Ku (1994). Includes CA, SMA,
    %     RRA, LRA, IMA, RIA, LIA. 
flowSplitFactorReference = 2;

% List of programmed outlet branches (union of all the arteries consiered
% in the available flow split ratio references)
outletBranchesProgrammed = {'IA', 'LCCA', 'LSA', 'CA', 'SMA', 'RRA', 'LRA', 'IMA', 'RIA', 'LIA'};
    % Indicate if they correspond to the Aortic Arch (1), the Abdominal
    % Aorta (2) or the Iliac Bifurcation (3)
    outletBranchesProgrammed_group = [1, 1, 1, 2, 2, 2, 2, 2, 3, 3];
    % Set table (also helps as conistency check)
    outletBranchesProgrammed_table = table(outletBranchesProgrammed',...
        outletBranchesProgrammed_group'              ,...
        'VariableNames',{'branchName','branchGroup'} ,...
        'RowNames',outletBranchesProgrammed);

% List of branches within the domain:
    % If the artery is listed and its area is set to zero or is not defined
    % in the input file, its corresponding outflow will be divided
    % according to the missingArteryManagment option. Meant for cases when
    % an intermediate branch is missing.
    %
    % If the artery is not listed, its flow will not be redirected and the
    % rest of the split factors will simply be scaled. Meant for cases when
    % the simulation domain starts after a specific branch and the inlet
    % waveform has been adjusted to account for this.
branchesWithinDomain = {'CA', 'SMA', 'RRA', 'LRA', 'RIA', 'IMA', 'LIA'};

% Control ranges for results (trigger warnings)
    % Proximal resistance, Rc
    ranges.Rc.min = 1.0E7; ranges.Rc.max = 2.0E9;
    % Distal resistance, Rp
    ranges.Rp.min = 1.0E7; ranges.Rp.max = 2.0E9;
    % Compliance
    ranges.C.min  = 5.0E-10; ranges.C.max = 2.0E-8;

%% Define flow split ratios according to the selected reference
% Select tha appropriate reference
switch flowSplitFactorReference
    case 1
        referenceArteries = {'IA', 'LCCA', 'LSA', 'CA', 'SMA', 'RRA', 'LRA', 'RIA', 'LIA'};
        Q_SR = table(referenceArteries'                                             ,...
                     [0.116, 0.031, 0.064, 0.2, 0.085, 0.154, 0.154, 0.098, 0.098]' ,...
                     'VariableNames',{'branchName','SR'}                            ,...
                     'RowNames',referenceArteries');
    case 2 % Moore & Ku (1994)
        referenceArteries = {'CA', 'SMA', 'RRA', 'LRA', 'RIA', 'LIA', 'IMA'};
        Q_SR = table(referenceArteries'                          ,...
                     [0.59, 0.40, 0.40, 0.40, 0.40, 0.40, 0.13]' ,...
                     'VariableNames',{'branchName','SR'}         ,...
                     'RowNames',referenceArteries');
end

%% Import data
% Area of the outlet branches should be loaded to the area table:
%   - Each row is associated with a patient, and should be named
%     accordingly.
%   - The first column should be named 'Case' and contain the case name.
%   - Subsequent columns should correspond to each branching artery, and
%     contain the outlet area in mm2 for the arteries being explicitly
%     represented within the domain. An artery can be implicitly
%     represented by either having no associated column or by setting its
%     area to zero. These columns should be named with the same names
%     defined for the outletBranchesProgrammed cell array.
% Clinical data should be loaded into into the clinicalData table,
% where each row corresponds to to each patient and is named as the case.
% The variables (columns) should be:
%   - Case: containing a cell array with the case name for each patient.
%   - SP  : average systolic pressure, in mmHg.
%   - DP  : average diastolic pressure, in mmHg.
%   - Qin : average estimated inflow to the domain, in mL/s.
%
%  (Conversion of areas, SP, DP and Qin to SI base units is to be performed
%  within the script, after everything is loaded into the corresponding
%  tables)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%% LOAD YOUR DATA HERE %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% /////////////////////////////////////////////////////////////////////////
%   TO BE USED IN CASE Qin IS NOT LOADED BUT CALCULATED WITHIN THE SCRIPT  
% /////////////////////////////////////////////////////////////////////////
% NOTE: Qin can be directly loaded if it was calculted externally (e.g. on
%       a spreadsheet containing all data). Alternatively, the following
%       calculation can be used (uncomment after loading data). Notice that
%       in this case you will need to load the heart rate (HR) into the
%       clinicalData table! Do it in bpm and then ensure that the resulting
%       Qin is in mL/s, and is then converted to m3/s at the end of the
%       section.
%
% %%%%%%%&%%%%%%%%%%%%%%%%%%% LOAD HR DATA HERE %%%%%%%%%&%%%%%%%%%%%%%%%%%
%
% Compute the fraction of the stroke volume reaching the domain, Vp
%   Cardiac Output is estimated via the Liljestrand & Zander formula (1940)
%   The result is corrected by the factor k proposed by Koenig et al (2015)
%   The fraction of the SV reching the simulation domain is estimated from
%   the diverted fraction (user input, divFrac)
%
%   The resulting equation is:
%              Qin = [(SP-DP)/(SP+DP)] * k * (1-divFrac) * HR
%   Notice pressure should be expressed in mmHg and that the result is in
%   L/min (if HR is in bpm). It is converted to mL/s by dividing by 60 and
%   multiplying by 1e3.
% divFrac = 0.25; % Estimated for the descending aorta, from Moore & Ku (1994)
% k = 0.282; % Estimated for the whole population based on the reported data
% Qin = (1-divFrac)*k*clinicalData.HR*((clinicalData.SP - clinicalData.DP)./(clinicalData.SP + clinicalData.DP))*(1e3/60); % In mL/s
% clinicalData = [clinicalData,table(Qin)];
% /////////////////////////////////////////////////////////////////////////

% Make row names the same as case names
clinicalData.Properties.RowNames = clinicalData.Case;
% Convert areas to m2
area{:,2:size(area,2)} = area{:,2:size(area,2)} * 1e-6;
% Convert pressure to Pa and Qin to m3/s
clinicalData{:,{'SP','DP'}} = clinicalData{:,{'SP','DP'}} * 133.322;
clinicalData{:,'Qin'} = clinicalData{:,'Qin'} / 1e6;

%% Consistency check
% All the reference arteries should be listed within the programmed
% arteries cell array (need to know to which section the artery belongs)
if ~all(ismember(referenceArteries,outletBranchesProgrammed))
    error('Some arteries within the reference are not listed within the outletBranchesProgrammed cell array');
end

%% Correct split factors in case of missing or non-considered arteries
% Get the radius for each outlet
radius = area;
radius{:,2:size(area,2)} = sqrt(radius{:,2:size(area,2)} / pi);

% Loop patients
for iPatient = 1:size(area,1)
    % Set string ID for this patient
    iPatientStr = area.Case{iPatient};

% Redirect flow from intermediate arteries not considered as selected
    % Initialize corrected struct (redimensionalized by patient)
    Q_SR_corr.(iPatientStr) = Q_SR;

    % Loop listed arteries for flow split factor list
    for iArtery = 1:size(Q_SR,1)
        % Get this artery name
        iArteryName = Q_SR.branchName{iArtery};
        % Check if this artery needs special management
        if any(strcmp(iArteryName, area.Properties.VariableNames)) && ... % The artery is listed...
           area.(iArteryName)(iPatient) ~= 0                              % ... and has a non-zero area
            % This artery is fully represented, no correction
            % needed. Proceed to next artery.
            continue
        else % Artery is either not listed or it has a zero area. Either way, what to do depends on if it is within the domain.
            % Check if this artery is within the domain
            if any(strcmp(iArteryName,branchesWithinDomain))
                % Artery has been considered in the domain, but not
                % represented. Redirect flow according to the
                % selected setting.
                switch missingArteryManagment
                    case 1 % Redirect flow to Iliac Arteries
                        % Compute area ratios for the Iliac Arteries
                        areaRatio_LIA = area.LIA(iPatient) ./ (area.LIA(iPatient) + area.RIA(iPatient));
                        areaRatio_RIA = 1 - areaRatio_LIA;
                        % Split this artery's flow
                        RIA_index = find(strcmp(Q_SR_corr.(iPatientStr).branchName,'RIA'));
                        LIA_index = find(strcmp(Q_SR_corr.(iPatientStr).branchName,'LIA'));
                        Q_SR_corr.(iPatientStr).SR(RIA_index) = Q_SR_corr.(iPatientStr).SR(RIA_index) + Q_SR_corr.(iPatientStr).SR(iArtery)*areaRatio_RIA;
                        Q_SR_corr.(iPatientStr).SR(LIA_index) = Q_SR_corr.(iPatientStr).SR(LIA_index) + Q_SR_corr.(iPatientStr).SR(iArtery)*areaRatio_LIA;
                        Q_SR_corr.(iPatientStr).SR(iArtery) = 0;
                    case 2 % Redirect flow among all other arteries
                        % Loop all arteries
                        for jArtery = 1:size(Q_SR,1)
                            % Get jArtery's name
                            jArteryName = Q_SR.branchName(jArtery);
                            % If this is the artery being redistributed,
                            % skip step, it might not be listed in the area
                            % table and would cause an error
                            if strcmp(iArteryName,jArteryName)
                                continue
                            end
                            % Compute this artery's area ratio
                            areaRatio_jArtery = area{iPatient,jArteryName} ./ sum(area{iPatient,3:end},2);
                            Q_SR_corr.(iPatientStr).SR(jArtery) = Q_SR_corr.(iPatientStr).SR(jArtery) + Q_SR_corr.(iPatientStr).SR(iArtery)*areaRatio_jArtery;
                        end
                        Q_SR_corr.(iPatientStr).SR(iArtery) = 0;
                end
            else % Artery is not considered in the domain.
                % Set this flow factor to zero
                Q_SR_corr.(iPatientStr).SR(iArtery) = 0;
                % Rescale flow split factors accordingly.
                Q_SR_corr.(iPatientStr).SR = Q_SR_corr.(iPatientStr).SR ./ (1 - Q_SR.SR(iArtery));
            end
        end
    end
end

%% Readjust split factors by cross-section area grouping by region and compute outflow
% Now the aorta will be divided into three main parts, the Arch, the
% Abdominal Aorta and the Iliac Bifurcation. Flow for each region will be
% computed based on the literature (corrected) split factors. Within each
% region, outlet flow for each branch will be split based on area
% proportion.

% IMPORTANT! Notice that every fully represented artery (considered within
% the domain and listed with a non-zero area within the area table) should
% have an associated flow split factor. This has not been ensured up to
% this point, that is, there could be arteries listed with a non-zero area
% included for the model that do not have a specific split factor within
% the selected literature reference. The proposed methodology avoids this
% problem, as each aortic section's flow is computed by means of area
% proportions, distributing the section's flow. It is only needed to know
% to which section the artery with no split factor belongs.
%
% An much simpler alterntive to this program would consist in computing the
% flow for each section from the literature's split factors and then
% distributing it, without correcting the flow factors first. However, this
% would not allow for all the branches within a section to be missing.

% Preallocate outlet flow for each patient and for each outlet
Qout = area;
Qout = removevars(Qout,'Inlet');
Qout{:,2:end} = deal(0);

% Loop patients
for iPatient = 1:size(area,1)
    % Set string ID for this patient
    iPatientStr = area.Case{iPatient};

    % Calculate the flow within each main section for this patient
        % Preallocate flow
        Qaux = [0 0 0];
        % Loop groups
        for i = 1:3
            % Get arteries from this group
            iGroupArteries = outletBranchesProgrammed_table.branchName(outletBranchesProgrammed_table.branchGroup==i);
            % Some of the arteries might have not been considered in the
            % reference used. Select only the interesection
            iGroupArteriesInRef = intersect(iGroupArteries,referenceArteries);
            % Set flow
            if isempty(iGroupArteriesInRef)
                Qaux(i) = 0;
            else
                Qaux(i) = clinicalData.Qin(iPatient) * sum(Q_SR_corr.(iPatientStr){iGroupArteriesInRef,'SR'});
            end

            % Get group arteries for which areas were set
            iGroupArteriesInInput = intersect(iGroupArteries,area.Properties.VariableNames);
            for iArtery = 1:length(iGroupArteriesInInput)
                iArteryName = iGroupArteriesInInput{iArtery};
                areaFactor = area{iPatientStr,iArteryName} / sum(area{iPatientStr,iGroupArteriesInInput});
                Qout{iPatientStr,iArteryName} = Qaux(i) * areaFactor;
            end
        end
end

%% Calculate average cycle pressure (time averaged)
% Calculate mean pressure based on systolic (max) and diastolic (min) pressures.
% Traditional formula by Bos et al (2007)
% Pmean = (1/3)*(pressure.SP - pressure.DP) + pressure.DP;
% Corrected formula proposed by Verrij et al (2008)
Pmean = 0.4*(clinicalData.SP - clinicalData.DP) + clinicalData.DP; 

%% Compute Windkessel model parameters for each patient and each outlet
% Preallocate tables for total (Rt), proximal (Rc) and distal (Rp)
% resistance, and for distal compiance (C).
Rt = Qout; Rc = Qout; Rp = Qout; C = Qout;

% Calculate total resistance
Rt{:,2:end} = Pmean ./ Qout{:,2:end};

% Calculate the c parameter for each outlet
    % Literature constants
    a2 = 13.3; b2 = 0.3;
    % Compute (radius should be in mm for the formula, hence the 1000 factor)
    c = a2 ./ ((2*1000*radius{:,3:end}).^b2);

% Calculate the characteristic impedance (proximal resistance)
    % Define blood density (kg/m3)
    rho = 1060;
    % Calculate
    Rc{:,2:end} = (rho * c) ./ area{:,3:end};

% Calculate the peripheral resistance (distal resistance)
Rp{:,2:end} = Rt{:,2:end} - Rc{:,2:end};

% Correction: in case Rp is negative, it is assumed that Rc/Rt is a fixed
% ratio. According to Reymond et al (2009), Rc/Rt (that is R1/Rt, ratio of
% proximal to total resistance), varies in the range [0.05– 0.4]. An output
% file containing a list of the cases that had to be corrected is produced.
    correctionRatio = 0.22;
    correctedPatientsCounter = 0;
    % Open ouput text file
    fileID = fopen(fullfile('.',sprintf('%s.out',mfilename)),"w");
    fprintf(fileID,'----- PROGRAM EXECUTION START: %s - %s ------------------------------------------------------------------\n',mfilename,datetime);
    fprintf(fileID,'This has been automatically generated at timestamp %s, while executing %s\n',datetime,mfilename);
    fprintf(fileID,'This output indicates:\n');
    fprintf(fileID,'\t - which patients and arteries had to be corrected for their Rc values, to obtain positive Rp values.\n');
    fprintf(fileID,'\t - warnings for the ranges obtained.\n');
    fprintf(fileID,'\t This preprocessing tool has been generated by Andrés Vignolo, see documentation for more details.\n\n');
    fprintf(fileID,'CORRECTIONS FOR RESISTANCES CALCULATIONS\n');
    fprintf(fileID,'----------------------------------------------------------------------------------------------------------------------------\n');
    % Loop patients
    for iPatient = 1:size(area,1)
        % Set string ID for this patient
        iPatientStr = area.Case{iPatient};
        % Set corrected patient flag
        correctedPatientFlag = 0;
        for iArtery = 1:size(Rp,2)-1
            iArteryStr = Rp.Properties.VariableNames{1+iArtery};
            if Rp{iPatientStr,iArteryStr} <= 0
                correctedPatientFlag = 1;
                beforeValue_Rc = Rc{iPatientStr,iArteryStr};
                beforeValue_Rp = Rp{iPatientStr,iArteryStr};
                Rc{iPatientStr,iArteryStr} = correctionRatio * Rt{iPatientStr,iArteryStr};
                Rp{iPatientStr,iArteryStr} = Rt{iPatientStr,iArteryStr} - Rc{iPatientStr,iArteryStr};
                fprintf(fileID,'Case: %6s \t Branch: %3s \t Before correction: Rc=%.1E and Rp=%.1E \t After correction: Rc=%.1E and Rp=%.1E\n',...
                    iPatientStr,iArteryStr,beforeValue_Rc,beforeValue_Rp,Rc{iPatientStr,iArteryStr},Rp{iPatientStr,iArteryStr});
            end
        end
        correctedPatientsCounter = correctedPatientsCounter + correctedPatientFlag;
    end
    fprintf(fileID,'\n\n\tTotal number of corrected patients: %d\n\n\n',correctedPatientsCounter);
    fprintf(fileID,'\n\n----- PROGRAM EXECUTION END   : %s - %s ------------------------------------------------------------------\n',mfilename,datetime);
    fclose(fileID);

% Calculate the compliace
    % Define the characteristic time constant (pressure exponetial decay)
    tau = 1.79;
    % Calculate
    C{:,2:end} = tau ./ Rt{:,2:end};

%% Perform checks on results
fprintf(fileID,'RANGE WARNINGS ACCORDING TO TYPICAL VALUES\n');
fprintf(fileID,'----------------------------------------------------------------------------------------------------------------------------\n');

% Check Rc values
    % Finde indeces
    [i_Rc,j_Rc] = find((Rc{:,2:end} < ranges.Rc.min)|(Rc{:,2:end} > ranges.Rc.max));
    % Proceed if there are any corrections to be made
    if length(i_Rc)>=1
        % Shift to account for the first (Case) column
        j_Rc = j_Rc + 1;
        % Generate base warning text
        warningStringBase_Rc = 'Case: %6s \t Branch: %3s \t Rc=%.2e is outside of the preset typical control range (%.2e,%.2e)\n';
        % Loop and issue warnings to output file
        for iWarning_Rc = 1:length(i_Rc)
            % Define case's indeces
            i = i_Rc(iWarning_Rc);
            j = j_Rc(iWarning_Rc);
            % Identify parameters
            caseStr = Rc.Case{i};
            caseBranch = Rc.Properties.VariableNames{j};
            caseRc  = Rc{i,j};
            % Issue warning
            fprintf(fileID,warningStringBase_Rc,caseStr,caseBranch,caseRc,ranges.Rc.min,ranges.Rc.max);
        end
    end

% Check Rp values
    % Finde indeces
    [i_Rp,j_Rp] = find((Rp{:,2:end} < ranges.Rp.min)|(Rc{:,2:end} > ranges.Rp.max));
    % Proceed if there are any corrections to be made
    if length(i_Rp)>=1
        % Shift to account for the first (Case) column
        j_Rp = j_Rp + 1;
        % Generate base warning text
        warningStringBase_Rp = 'Case: %6s \t Branch: %3s \t Rp=%.2e is outside of the preset typical control range (%.2e,%.2e)\n';
        % Loop and issue warnings to output file
        for iWarning_Rp = 1:length(i_Rp)
            % Define case's indeces
            i = i_Rp(iWarning_Rp);
            j = j_Rp(iWarning_Rp);
            % Identify parameters
            caseStr = Rc.Case{i};
            caseBranch = Rc.Properties.VariableNames{j};
            caseRc  = Rc{i,j};
            % Issue warning
            fprintf(fileID,warningStringBase_Rp,caseStr,caseBranch,caseRc,ranges.Rp.min,ranges.Rp.max);
        end
    end

% Check C values
    % Find indeces
    [i_C,j_C] = find((C{:,2:end} < ranges.C.min)|(C{:,2:end} > ranges.C.max));
    % Proceed if there are any corrections to be made
    if length(i_C)>=1
        % Shift to account for the first (Case) column
        j_C = j_C + 1;
        % Generate base warning text
        warningStringBase_C = 'Case: %6s \t Branch: %3s \t C=%.2e is outside of the preset typical control range (%.2e,%.2e)\n';
        % Loop and issue warnings to output file
        for iWarning_C = 1:length(i_C)
            % Define case's indeces
            i = i_C(iWarning_C);
            j = j_C(iWarning_C);
            % Identify parameters
            caseStr = C.Case{i};
            caseBranch = C.Properties.VariableNames{j};
            caseC  = C{i,j};
            % Issue warning
            fprintf(fileID,warningStringBase_C,caseStr,caseBranch,caseC,ranges.C.min,ranges.C.max);
        end
    end
fprintf(fileID,'\n\n\tTotal number of range warnings: %d\n',length(i_Rc)+length(i_Rp)+length(i_C));

%% Export results to an Excel file
outputFileName = sprintf('%s_out.xlsx',mfilename);
writetable(Rp,outputFileName,"Sheet",'WK_Rp','WriteRowNames',false);
writetable(Rc,outputFileName,"Sheet",'WK_Rc','WriteRowNames',false);
writetable(C ,outputFileName,"Sheet",'WK_C' ,'WriteRowNames',false);
