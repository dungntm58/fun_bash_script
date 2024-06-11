#!/usr/bin/env rbenv exec ruby

require 'rubygems'

# Function to check if a gem is installed
def gem_installed?(gem_name)
  Gem::Specification::find_all_by_name(gem_name).any?
rescue Gem::LoadError
  false
rescue
  Gem.refresh
  retry
end

# Function to install a gem
def install_gem(gem_name)
  system("gem install #{gem_name}")
end

# Check and install xcodeproj gem if not installed
unless gem_installed?('xcodeproj')
  puts "xcodeproj gem is not installed. Installing..."
  install_gem('xcodeproj')
  if gem_installed?('xcodeproj')
    puts "xcodeproj gem successfully installed."
  else
    puts "Error: Failed to install xcodeproj gem."
    exit 1
  end
end

require 'xcodeproj'

def add_files_to_target(xcodeproj_path, target_name, files_path)
  # Open the Xcode project
  project = Xcodeproj::Project.open(xcodeproj_path)
  
  # Find the target
  target = project.targets.find { |t| t.name == target_name }
  unless target
    puts "Error: Target '#{target_name}' not found."
    exit 1
  end
  
  # Get the group for adding new files
  main_group = project.main_group
  
  # Find or create a group for the files path
  files_group = main_group.find_subpath(files_path, true)
  files_group.set_source_tree('SOURCE_ROOT')
  
  # Get all existing files in the target
  existing_files = target.source_build_phase.files.map { |pbx_build_file| pbx_build_file.file_ref.path }
  
  # Add new files to the target
  Dir.glob("#{files_path}/**/*").each do |file|
    next if File.directory?(file)
    
    relative_path = file.sub("#{files_path}/", '')
    
    unless existing_files.include?(relative_path)
      file_ref = files_group.new_reference(relative_path)
      target.add_file_references([file_ref])
      puts "Added #{relative_path} to #{target_name} target."
    end
  end
  
  # Save the project
  project.save
  puts "Successfully updated the Xcode project."
end

if ARGV.length != 3
  puts "Usage: #{$0} <xcodeproj_path> <target_name> <files_path>"
  exit 1
end

xcodeproj_path = ARGV[0]
target_name = ARGV[1]
files_path = ARGV[2]

add_files_to_target(xcodeproj_path, target_name, files_path)
