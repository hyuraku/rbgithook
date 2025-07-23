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

  def self.list
    executable_files = Dir.glob(File.join(DIRNAME, "*")).select do |file|
      File.file?(file) && File.executable?(file)
    end

    hooks = executable_files.map { |file| File.basename(file) }

    hooks.each do |hook|
      puts hook
    end
  end

  def self.help
    puts <<~USAGE
      rbgithook [command] {file} {command}

      install - Install hook
      set {file} {command} - Set a hook
      add {file} {command} - Add a hook
      list - List hooks
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

    check_path_traversal_patterns(file_name)
    check_hidden_file_patterns(file_name)
    check_control_characters(file_name)
    check_allowed_characters(file_name)
  end

  def self.check_path_traversal_patterns(file_name)
    dangerous_patterns = [
      "..",           # Standard directory traversal
      "/",            # Path separator
      "\\",           # Windows path separator
      "\0",           # Null byte injection
      "%2e%2e",       # URL encoded ..
      "%2f",          # URL encoded /
      "%5c"           # URL encoded \
    ]

    dangerous_patterns.each do |pattern|
      if file_name.downcase.include?(pattern)
        raise ArgumentError, "File name contains dangerous path traversal pattern: #{pattern}"
      end
    end
  end

  def self.check_hidden_file_patterns(file_name)
    return unless file_name.start_with?(".") && file_name != "." && file_name != ".."

    raise ArgumentError, "File name cannot start with dot (hidden files not allowed)"
  end

  def self.check_control_characters(file_name)
    raise ArgumentError, "File name cannot contain control characters" if file_name.match?(/[\x00-\x1f\x7f]/)
  end

  def self.check_allowed_characters(file_name)
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
    # Ensure .rbgithook directory exists and is secure
    ensure_secure_directory

    file_path = File.join(DIRNAME, file_name)

    # Multiple layers of path validation
    validate_secure_file_path(file_path, file_name)

    mode = append ? "a" : "w"
    File.open(file_path, mode) do |file|
      file.write("#!/usr/bin/env sh\n\n") unless append
      # Escape the command to prevent shell injection
      escaped_command = sanitize_hook_command(hook_command)
      file.write("#{escaped_command}\n")
    end
    FileUtils.chmod(0o755, file_path)
  end

  def self.ensure_secure_directory
    return if Dir.exist?(DIRNAME)

    # Create directory with secure permissions
    FileUtils.mkdir_p(DIRNAME)
    FileUtils.chmod(0o755, DIRNAME)
  end

  def self.validate_secure_file_path(file_path, original_name)
    # Ensure the path stays within our designated directory
    expanded_file_path = File.expand_path(file_path)
    expanded_dirname = File.expand_path(DIRNAME)

    unless expanded_file_path.start_with?(expanded_dirname + File::SEPARATOR) || expanded_file_path == expanded_dirname
      raise ArgumentError, "Security violation: file path '#{original_name}' resolves outside designated directory"
    end

    # Additional check: ensure no symlink traversal
    if File.symlink?(File.dirname(file_path)) || (File.exist?(file_path) && File.symlink?(file_path))
      raise ArgumentError, "Security violation: symbolic links not allowed in hook paths"
    end

    # Verify the final component matches our validated name
    return if File.basename(file_path) == original_name

    raise ArgumentError, "Security violation: path manipulation detected"
  end

  def self.sanitize_hook_command(command)
    # Remove any potential shell metacharacters that passed basic validation
    # This is a defense-in-depth measure
    command.gsub(/[`$]/, "")
  end
end
