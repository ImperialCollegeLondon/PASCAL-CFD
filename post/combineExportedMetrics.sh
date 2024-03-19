#!/bin/bash

# Specify the path where CSV files are located
path=".../exportedMetrics"

# Specify the output file
output_file="shearMetrics.csv"

# Flag to track whether it's the first file
first_file=true

# Use a for loop to concatenate and modify CSV files in the specified path
for file in "$path"/*.csv; do
    if [ -e "$file" ]; then
        # Extract file name without extension
        filename_without_extension=$(basename -- "$file")
        filename_without_extension="${filename_without_extension%.*}"

        # Extract numeric part of the file name
        file_number=$(echo "$filename_without_extension" | grep -o -E '[0-9]+')

        if [ "$first_file" = true ]; then
            # For the first file, copy the header with the added column
            head -n +1 "$file" | awk -v col="FileName" -v num="FileNumber" 'BEGIN {OFS = ","} {print num, col, $0}' >> "$output_file" > "$output_file"
            first_file=false
        fi

        # For all files, skip the header and add the column values
        tail -n +2 "$file" | awk -v col="$filename_without_extension" -v num="$file_number" 'BEGIN {OFS = ","} {print num, col, $0}' >> "$output_file"

        echo "Processed $file"
    fi
done

# Sort the output file based on the numeric part of the file names
sort -t',' -k1n -o "$output_file" "$output_file"

echo "CSV files in $path have been concatenated, modified, sorted, and saved to $output_file"