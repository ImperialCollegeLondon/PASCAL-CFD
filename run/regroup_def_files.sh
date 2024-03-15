#!/bin/bash

# Set the range of cases
for case_number in {2..15}; do
    # Build the case name
    case_name="case${case_number}"

    # Define the source file and destination directory
    source_file="./samples/${case_name}/${case_name}_HPC.def"
    destination_directory="./def_files_for_distribution"

    # Create the case directory if it doesn't exist
    mkdir -p "$destination_directory"

    # Move the file to the case directory
    mv "$source_file" "$destination_directory"

    echo "File ${case_name}.def moved to $destination_directory"
done