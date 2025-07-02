#!/bin/bash

# Check if running as root 
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root! Please run again using sudo." 
   exit 1
fi

# Prompt user for file to analyze 
read -p "Enter the filename for analysis: " file
if [[ ! -f "$file" ]]; then
    echo "File does not exist! Exiting..."
    exit 1
fi

# Create analysis directory
analysis_dir="analysis_results"
mkdir -p "$analysis_dir"

# Function to install missing tools 
install_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "$1 not found. Installing..."
        apt-get update && apt-get install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Required tools 
tools=(bulk-extractor exiftool foremost strings binwalk steghide zsteg zip)
for tool in "${tools[@]}"; do
    install_tool "$tool"
    
    # Check if installation was successful
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: $tool failed to install. Exiting..."
        exit 1
    fi
done

# Run bulk_extractor 
echo "Running bulk_extractor..."
bulk_extractor -o "$analysis_dir/bulk_extractor" "$file"

# Run ExifTool for metadata analysis 
echo "Running exiftool..."
exiftool "$file" > "$analysis_dir/exiftool.txt"

# Run foremost for file carving 
echo "Running foremost..."
foremost -i "$file" -o "$analysis_dir/foremost"

# Run strings to extract readable text 
echo "Running strings..."
strings "$file" > "$analysis_dir/strings_output.txt"

# Run binwalk for embedded files and hidden data 
echo "Running binwalk..."
binwalk -e "$file" -C "$analysis_dir/binwalk"

# Run steghide to check for hidden data in images/audio 
echo "Running steghide..."
steghide info "$file" > "$analysis_dir/steghide.txt"

# Run zsteg for advanced steganography detection 
echo "Running zsteg..."
zsteg "$file" > "$analysis_dir/zsteg.txt"

# Compress results into a zip file 
echo "Compressing results..."
zip -r "$analysis_dir.zip" "$analysis_dir"

# Finish / סיום
echo "Analysis complete. Results saved in $analysis_dir.zip"
