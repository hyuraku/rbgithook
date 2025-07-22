# frozen_string_literal: true

require_relative "rbgithook/version"
require "fileutils"

module Rbgithook
  DIRNAME = ".rbgithook"

  def self.install
    FileUtils.mkdir_p(DIRNAME)
    system("git", "config", "core.hooksPath", DIRNAME)
  end

  def self.set(args)
    file_name, hook_command = args
    validate_arguments(file_name, hook_command)
    check_dir_existence
    write_hook_to_file(file_name, hook_command)
  end

  def self.add(args)
    file_name, hook_command = args
    validate_arguments(file_name, hook_command)
    check_dir_existence
    write_hook_to_file(file_name, hook_command, append: true)
  end

  def self.uninstall
    system("git", "config", "--unset", "core.hooksPath")
  end

  def self.help
    puts <<~USAGE
      rbgithook [command] {file} {command}

      install - Install hook
      set {file} {command} - Set a hook
      add {file} {command} - Add a hook
      uninstall - Uninstall hook
      help   - Show this usage
    USAGE
  end

  def self.validate_arguments(file_name, hook_command)
    validate_file_name(file_name)
    validate_hook_command(hook_command)
  end

  def self.validate_file_name(file_name)
    raise ArgumentError, "File name cannot be empty" if file_name.nil? || file_name.empty?

    if file_name.include?("..") || file_name.include?("/")
      raise ArgumentError, "File name cannot contain path separators or traversal patterns"
    end

    return if file_name.match?(/\A[a-zA-Z0-9_-]+\z/)

    raise ArgumentError, "File name can only contain alphanumeric characters, hyphens, and underscores"
  end

  def self.validate_hook_command(hook_command)
    raise ArgumentError, "Hook command cannot be empty" if hook_command.nil? || hook_command.empty?

    dangerous_chars = [";", "&", "|", "`", "$", "(", ")", ">", "<", "&&", "||"]
    if dangerous_chars.any? { |char| hook_command.include?(char) }
      raise ArgumentError, "Hook command contains potentially dangerous characters: #{dangerous_chars.join(", ")}"
    end

    return unless hook_command.include?("\n") || hook_command.include?("\r")

    raise ArgumentError, "Hook command cannot contain newline characters"
  end

  def self.check_dir_existence
    return if Dir.exist?(DIRNAME)

    warn "Directory #{DIRNAME} not found, please run `rbgithook install` first"
    exit 1
  end

  def self.write_hook_to_file(file_name, hook_command, append: false)
    file_path = File.join(DIRNAME, file_name)

    # Additional safety check: ensure the resolved path is still within DIRNAME
    unless File.expand_path(file_path).start_with?(File.expand_path(DIRNAME))
      raise ArgumentError, "Invalid file path: #{file_name}"
    end

    mode = append ? "a" : "w"
    File.open(file_path, mode) do |file|
      file.write("#!/usr/bin/env sh\n\n") unless append
      # Escape the command to prevent shell injection
      escaped_command = sanitize_hook_command(hook_command)
      file.write("#{escaped_command}\n")
    end
    FileUtils.chmod(0o755, file_path)
  end

  def self.sanitize_hook_command(command)
    # Remove any potential shell metacharacters that passed basic validation
    # This is a defense-in-depth measure
    command.gsub(/[`$]/, "")
  end
end
