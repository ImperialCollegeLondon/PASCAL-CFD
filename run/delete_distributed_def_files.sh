#!/bin/bash

# Set the range of cases
for case_number in {2..15}; do
    # Build the case name
    case_name="case${case_number}"

    # Define the target file for deletion
    target_file="./samples/${case_name}/${case_name}_HPC.def"

    # Remove target file
    rm "$target_file"

    echo "File ${target_file} removed"
done