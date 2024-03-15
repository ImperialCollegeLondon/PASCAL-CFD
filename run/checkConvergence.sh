#!/bin/bash

# Specify the directory where the folders are located
base_directory=".../results"

# Specify the string you want to search for
search_string="COEFFICIENT LOOP ITERATION =   20"

# Specify the output file to save the results
output_file="convergence_check_results.txt"

rm $output_file

# Loop through folders and search for the string in .out files
for folder in "$base_directory"/*/; do
    echo "Searching in .out files of $folder..."
    for file in "$folder"*.out; do
        echo $pwd
        if [ -f "$file" ]; then
            if grep -q "$search_string" "$file"; then
                echo "Found $search_string in $file, potential convergence issues!" >> "$output_file"
            fi
        fi
    done
done

echo "Search complete."