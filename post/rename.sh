#!/bin/bash

# Set the directory path
directory_path=".../exportedMetrics"

# Check if the provided path is a directory
if [ ! -d "$directory_path" ]; then
    echo "Error: '$directory_path' is not a valid directory."
    exit 1
fi

# Navigate to the specified directory
cd "$directory_path" || exit

# Loop through each file in the current directory
for file in *; do
    if [ -f "$file" ]; then
        # Check if the file name contains a space (more than one word)
        if [[ "$file" == *" "* ]]; then
            # Extract the first word and remove it from the file name
            new_name=$(echo "$file" | sed 's/^[^[:space:]]* //')

            # Rename the file
            mv "$file" "$new_name"
            echo "Renamed: $file -> $new_name"
        else
            echo "Skipped: $file (single-word file)"
        fi
    fi
done

echo "All appropriate files in '$directory_path' have been renamed by deleting the first word."