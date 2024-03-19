%% BUILD ANSYS CFX-PRE EXPRESSIONS FOR EACH PATIENT
% v1 - A.Vignolo - Nov 2023 - First implementation.
% v2 - A.Vignolo - Dec 2023 - Updated to include expression for saving
%                             time, allowing for single runs (no init).
%
% This script generates plain text files containing all of the expressions
% required to set up patient specific simulations. This script is set to an
% example of the descending aorta, considering the celiac, superior
% mesenteric, renal and iliac arteries as outlets. It is assumed that
% scripts WindkeselTunning.m and FitInletBC.m have already been executed,
% and therefore Windkessel model coefficients and inlet flow wave function
% are available.
%
% The results can be copied from the file and pasted into CFX's Commmand
% Editor to include all necessary expressions. This aims at accelerating
% the process of setting multiple simulations for large cohorts and
% reducing the chance of mistakes.
%
% NOTICE YOU MAY NEED TO MODIFY THIS SCRIPT FOR YOUR SIMULATION DOMAIN AND
% DESIRED SETUP!
clc;
clearvars;

%% Load data
% Load Windkessel data
WK_file = fullfile('.','windkesselTunning_out.xlsx');
    % Load R1 (Rc)
    R1 = readtable(WK_file,'Sheet','WK_Rc');
    R1.Properties.RowNames = R1.Case;
    % Load R2 (Rp)
    R2 = readtable(WK_file,'Sheet','WK_Rp');
    R2.Properties.RowNames = R2.Case;
    % Load C
    C  = readtable(WK_file,'Sheet','WK_C' );
    C.Properties.RowNames = C.Case;

% Load Inflow data
Inlet_file = fullfile('.','fitInletBC_out.xlsx');
    % Load patient results
    patientResults = readtable(Inlet_file,'Sheet','patientResults');
    % Load Fourier series base coefficients
    baseFourierCoef = readtable(Inlet_file,'Sheet','baseFourierSeries');

%% Set output directory
% Define output directory
outDir = fullfile('.','CFX_expressionsSetup');
% Check the existance of output directory and create it if necessary
if not(isfolder(outDir))    , mkdir(outDir)    ; end

%% Setup some parameters
% These are expected to remain constant for all simulations
    % General setups
    BloodDens = 1060     ;  % Blood density, in kg/m3
    DeltaT    =    0.005 ;  % Time step, in s
    dtSave    =    0.010 ;  % Saving time step during the last cycle, in s
    % Quemada viscosity model
    GC        =    1.88  ;  %
    MuF       =    0.0012;  %
    k0        =    4.33  ;  %
    kinf      =    2.07  ;  %
    % Default initizlization
    cycles    =    5     ;  % Cardiac cycles to be simulated

%% Loop patients and write down files
nPatients = size(patientResults,1);
for iPatient = 1:nPatients
    % Get case string
    iPatientStr = patientResults.Case{iPatient};
    % Open output file
    fileID = fopen(fullfile(outDir,sprintf('%s_expressionsCFX.txt',iPatientStr)),'w');
    % Set header lines
    fprintf(fileID,'LIBRARY:\n');
    fprintf(fileID,'  CEL: \n' );
    fprintf(fileID,'    &replace EXPRESSIONS: \n');
    % Set general parameters
    fprintf(fileID,'      BloodDens = %d [kg/m^3]\n',BloodDens);
    fprintf(fileID,'      DeltaT = %.2E [s]\n',DeltaT);
    % Quemada viscosity model
    fprintf(fileID,'      Quemada = MuF / (1 - 0.5*((k0+kinf*((sstrnr/GC)^0.5)) /(1+((sstrnr/GC)^0.5)))*phi)^(2)\n');
    fprintf(fileID,'      GC = %.2f [s^-1]\n',GC);
    fprintf(fileID,'      MuF = %.2E [Pa*s]\n',MuF);
    fprintf(fileID,'      k0 = %.2f\n',k0);
    fprintf(fileID,'      kinf = %.2f\n',kinf);
    fprintf(fileID,'      phi = %.4f\n',patientResults.phi(iPatient));
    % Inlet Boundary Condition
    nModes = size(baseFourierCoef,1) - 1; % Not considering independent term
    fprintf(fileID,'      inflow = ScaleFactor*(a0');% Print independent term
    for iMode = 1:nModes                % Print cos and sin components for each term
        fprintf(fileID,'+a%d*cos(v0*t)+b%d*sin(v0*t)',iMode,iMode);
    end
    fprintf(fileID,')\n');               % Close parenthesis and set new line
    fprintf(fileID,'      v0 = 2*pi/period\n');
    fprintf(fileID,'      period = %.3f [s]\n',patientResults.T(iPatient));
    fprintf(fileID,'      ScaleFactor = %.3f\n',patientResults.ScaleFactor(iPatient));
    fprintf(fileID,'      inletvel = inflow/area()@INLET\n');
    fprintf(fileID,'      a0 = %.7E [m^3 s^-1]\n',baseFourierCoef.an(1));
    for iMode = 1:nModes
        iModeInd = iMode + 1; % Mode 0 is indexed as 1 in Matlab
        fprintf(fileID,'      a%d = %.7E [m^3 s^-1]\n',iMode,baseFourierCoef.an(iModeInd));
        fprintf(fileID,'      b%d = %.7E [m^3 s^-1]\n',iMode,baseFourierCoef.bn(iModeInd));
    end
    % 3-parameter Windkessel model
    artNames = R1.Properties.VariableNames(2:end);
    for iArtery = 1:length(artNames)
        iArteryStr = artNames{iArtery};
        fprintf(fileID,'      R1%s = %.5E [kg*m^-4 s^-1]\n',upper(iArteryStr),R1{iPatientStr,iArteryStr});
        fprintf(fileID,'      R2%s = %.5E [kg*m^-4 s^-1]\n',upper(iArteryStr),R2{iPatientStr,iArteryStr});
        fprintf(fileID,'      C%s = %.5E [m^4 s^2/kg]\n',upper(iArteryStr),R2{iPatientStr,iArteryStr});
    end
    % Other prameters
    fprintf(fileID,'      dtSave = if(t<(cycles-1)*period,period,%.5E [s])\n',dtSave);
    fprintf(fileID,'      cycles = %d\n',cycles);
    fprintf(fileID,'      ncycle = int(t/period)\n');
    fprintf(fileID,'      Ppast = 9.3331e+03 [Pa]\n');
    % Pressure and flow monitors at outlets
    fprintf(fileID,'      PInlet = ave(Pressure)@INLET\n');
    fprintf(fileID,'      POutCEL = ave(Pressure)@Outlet0\n');
    fprintf(fileID,'      POutLI = ave(Pressure)@Outlet5\n');
    fprintf(fileID,'      POutLR = ave(Pressure)@Outlet3\n');
    fprintf(fileID,'      POutRI = ave(Pressure)@Outlet4\n');
    fprintf(fileID,'      POutRR = ave(Pressure)@Outlet2\n');
    fprintf(fileID,'      POutSMA = ave(Pressure)@Outlet1\n');

    fprintf(fileID,'      QfutureCEL = (Blood.massFlow()@Outlet0* -1) / BloodDens\n');
    fprintf(fileID,'      QfutureLI = (Blood.massFlow()@Outlet5* -1) / BloodDens\n');
    fprintf(fileID,'      QfutureLR = (Blood.massFlow()@Outlet3* -1) / BloodDens\n');
    fprintf(fileID,'      QfutureRI = (Blood.massFlow()@Outlet4* -1) / BloodDens\n');
    fprintf(fileID,'      QfutureRR = (Blood.massFlow()@Outlet2* -1) / BloodDens\n');
    fprintf(fileID,'      QfutureSMA = (Blood.massFlow()@Outlet1* -1) / BloodDens\n');
    fprintf(fileID,'      Qin = (Blood.massFlow()@INLET) / BloodDens\n');

    % Closure statements
    fprintf(fileID,'    END\n');
    fprintf(fileID,'  END\n');
    fprintf(fileID,'END\n');

    % Close file
    fclose(fileID);
end



