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
    # Validate file name
    if file_name.nil? || file_name.empty?
      raise ArgumentError, "File name cannot be empty"
    end

    # Prevent path traversal attacks
    if file_name.include?("..") || file_name.include?("/")
      raise ArgumentError, "File name cannot contain path separators or traversal patterns"
    end

    # Only allow alphanumeric characters, hyphens, and underscores
    unless file_name.match?(/\A[a-zA-Z0-9_-]+\z/)
      raise ArgumentError, "File name can only contain alphanumeric characters, hyphens, and underscores"
    end

    # Validate hook command
    if hook_command.nil? || hook_command.empty?
      raise ArgumentError, "Hook command cannot be empty"
    end

    # Basic command injection prevention
    dangerous_chars = [";", "&", "|", "`", "$", "(", ")", ">", "<", "&&", "||"]
    if dangerous_chars.any? { |char| hook_command.include?(char) }
      raise ArgumentError, "Hook command contains potentially dangerous characters: #{dangerous_chars.join(', ')}"
    end

    # Prevent multi-line commands that could contain hidden malicious code
    if hook_command.include?("\n") || hook_command.include?("\r")
      raise ArgumentError, "Hook command cannot contain newline characters"
    end
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
    command.gsub(/[`$]/, '')
  end
end
