%% BUILD HPC WORKTREE
% v1 - A.Vignolo - Dec 2023 - First implementation.
% v2 - A.Vignolo - Dec 2023 - Initiaization was removed for single run
%                             cases
%
% This script generates the working directories and run scripts for HPC
% computation in ANSYS CFX at the cluster system of Imperial College
% London.
%
% Two scripts are generated, one running initialization cycles and another
% running the final cycle with the converged Windkessel model. Make sure
% all .def files have the correct names. Upload as a .zip, .gz or .tar
% package.
clc;
clearvars;

%% Setup some parameters
% Cases to build
    % Base file name
    baseStr = 'case';
    % Cases to build
    caseNumbers = 1:60;

% Computation resources
    % Number of CPUs
    ncpus = 24;
    % Number of MPI process
    mpiprocs = 24;
    % Requested memory and units string
    mem = 256;
    memUnitStr = 'gb';
    % Time limit
    walltime = duration(72,0,0);

% Output base directory
outDir = fullfile(pwd,'HPC_simDirectories');

%% Write files and working directories
% Check the existance of output directory and create it if necessary
if not(isfolder(outDir)), mkdir(outDir); end

% Loop cases
for iCase = caseNumbers
    % Build case name
    iCaseName = sprintf('%s%d',baseStr,iCase);
    % Build case path
    iCaseDir = fullfile(outDir,iCaseName);
    % Check if case path exists, if not, create it
    if not(isfolder(iCaseDir)), mkdir(iCaseDir); end
    % Start output file
    fileID  = fopen(fullfile(iCaseDir,'HPC_submit.sh'),"w");

    % Set file header and requested resources for this job
    fprintf(fileID,'#!/bin/bash\n');
    fprintf(fileID,'#PBS -N %s_HPC\n',iCaseName);
    fprintf(fileID,'#PBS -o %s_HPC.out\n',iCaseName);
    fprintf(fileID,'#PBS -e %s_HPC.e\n',iCaseName);
    fprintf(fileID,'#PBS -l select=1:ncpus=%d:mpiprocs=%d:mem=%d%s\n',ncpus,mpiprocs,mem,memUnitStr);
    fprintf(fileID,'#PBS -l walltime=%s\n\n',walltime);

    % Purge modules and load ANSYS
    fprintf(fileID,'module purge\n');
    fprintf(fileID,'module load ansys/21.2-fluids\n\n');

    % Set up some environment variables, including ANYS licence and servers
    fprintf(fileID,'export LD_PRELOAD=/path/to/your/licence\n');
    fprintf(fileID,'ANSYSLMD_LICENSE_FILE=/path/to/your/licence\n');
    fprintf(fileID,'ANSYSLI_SERVERS=yourLicenceServer; export ANSYSLI_SERVERS\n\n');

    % cd to working directory
    fprintf(fileID,'cd $PBS_O_WORKDIR\n\n');

    % Write the adequate start instruction (depending on initialization)
    fprintf(fileID,'cfx5solve -batch -def %s_HPC.def -name %s_HPC -monitor %s_HPC.res -par-local -part %d',...
        iCaseName,iCaseName,iCaseName,mpiprocs);
    % fprintf(fileID_final,'cfx5solve -batch -def %s_HPC.def -cont-from-file %s_HPC_001.res -name %s_HPC -monitor %s_HPC.res -par-local -part %d',...
    %     iCaseName,iCaseName,iCaseName,iCaseName,mpiprocs);
    % Close files
    fclose(fileID);
end

