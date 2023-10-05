#!/usr/bin/env ruby
require "CSV"

# why?
require_relative "../app/models/apple/config"
require_relative "../app/models/apple/key"

ActiveRecord::Base.logger.level = Logger::INFO

def find_csv_files
  # Get the directory of the current script
  script_dir = File.dirname(__FILE__)

  # Find all CSV files in the same directory as the script
  Dir.glob(File.join(script_dir, "*.csv"))
end

def parse_csv(path)
  # Read the CSV file
  csv = CSV.read(path, headers: true)

  # Convert the CSV data into a hash
  csv.map(&:to_h)
end

def file_without_extension(path)
  # Get the filename with extension
  filename = File.basename(path)

  # Remove the extension from the filename
  File.basename(filename, File.extname(filename))
end

def format_keys(group)
  group.map do |row|
    row.transform_keys do |key|
      key
        .strip
        .downcase
        .tr(" ", "_")
    end
  end
end

def convert_to_struct(group)
  group.map do |row|
    OpenStruct.new(row)
  end
end

def join_group_to_podcast(group)
  group.each do |row|
    row.podcast = Podcast.find_by(title: row.title)
  end
end

# create a main
def remaining_by_collection
  find_csv_files.map do |path|
    key = file_without_extension(path)
    key = key.split(" - ").last

    # Parse the CSV file
    data = parse_csv(path)
    [key, data]
  end.to_h
end

def prepare_for_delegated_delivery(group)
  group.map do |row|
    if row.delegated_delivery_added.present?
      puts "Skipping #{row.title} because it already has delegated delivery"
      next
    end
    if row.podcast.default_feed.apple_configs.present?
      puts "Skipping #{row.title} because it already has an apple_config"
      next
    end

    # setup but dont attach key yet
    puts "Setting up delegated delivery for #{row.title}"
    Apple::Config.setup_delegated_delivery(row.podcast)
  end
end

# take in the argv from the call to rails runner
grouped = remaining_by_collection

grouped.transform_values do |group|
  group = format_keys(group)
  group = convert_to_struct(group)
  binding.pry unless group.all? { |row| Podcast.find_by(title: row.title) }

  join_group_to_podcast(group)
  prepare_for_delegated_delivery(group)
end
