#!/bin/bash

# Set the range of cases
for case_number in {2..15}; do
    # Build the case name
    case_name="case${case_number}"

    # Make sure the job's script has the correct encoding
    dos2unix "./samples/${case_name}/HPC_submit.sh"

    # Get current directory
    curr_dir=$(pwd)

    # cd to execution directory
    cd "./samples/${case_name}"

    # Submit job (requires submission script for each case, which will be specific to the HPC system used)
    qsub "HPC_submit.sh"

    # Return to original directory
    cd "${curr_dir}"

    echo "File ./samples/${case_name}/HPC_submit.sh has been submitted to queue"
done
