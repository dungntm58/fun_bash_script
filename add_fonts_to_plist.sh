#!/bin/bash

# Function to check if lcdf-typetools is installed and install if not
check_and_install_lcdf_typetools() {
  if ! command -v otfinfo &> /dev/null; then
    echo "lcdf-typetools is not installed. Installing..."
    brew install lcdf-typetools
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to install lcdf-typetools."
      exit 1
    fi
  fi
}


# Function to extract the real font name from a font file
get_font_name() {
  local font_file="$1"
  local font_name=$(otfinfo -i "$font_file" | grep 'Full name:' | sed 's/Full name: //')
  echo "$font_name"
}

# Function to add fonts to Info.plist
add_fonts_to_plist() {
  local plist_path="$1"
  local font_folder="$2"

  # Check if the plist file exists
  if [[ ! -f "$plist_path" ]]; then
    echo "Error: The file $plist_path does not exist."
    exit 1
  fi

  # Check if the font folder exists
  if [[ ! -d "$font_folder" ]]; then
    echo "Error: The folder $font_folder does not exist."
    exit 1
  fi

  # Find all font files in the specified folder
  local fonts=($(find "$font_folder" -type f \( -iname "*.ttf" -o -iname "*.otf" \)))

  if [[ ${#fonts[@]} -eq 0 ]]; then
    echo "No font files found in $font_folder."
    exit 1
  fi

  # Check if UIAppFonts key exists, if not, create it
  if ! /usr/libexec/PlistBuddy -c "Print :UIAppFonts" "$plist_path" &>/dev/null; then
    /usr/libexec/PlistBuddy -c "Add :UIAppFonts array" "$plist_path"
  fi

  # Add fonts to the UIAppFonts array
  for font in "${fonts[@]}"; do
    font_name=$(basename "$font")
    true_font_name=$(get_font_name "$font")
    if [[ -z "$true_font_name" ]]; then
        echo "Could not determine the true font name for $font_name. Skipping."
        continue
    fi
    if /usr/libexec/PlistBuddy -c "Print :UIAppFonts" "$plist_path" | grep -q "$font_name"; then
        echo "Font $true_font_name (file: $font_name) is already in the plist."
    else
        /usr/libexec/PlistBuddy -c "Add :UIAppFonts: string $font_name" "$plist_path"
        echo "Added font $true_font_name (file: $font_name) to the plist."
    fi
  done

  echo "Successfully added fonts to $plist_path"
}

# Main script
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <plist_path> <font_folder>"
  exit 1
fi

plist_path="$1"
font_folder="$2"

# Check if lcdf-typetools is installed, install if not
check_and_install_lcdf_typetools

add_fonts_to_plist "$plist_path" "$font_folder"