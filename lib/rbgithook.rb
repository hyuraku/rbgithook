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
    check_dir_existence
    write_hook_to_file(file_name, hook_command)
  end

  def self.add(args)
    file_name, hook_command = args
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

  def self.check_dir_existence
    return if Dir.exist?(DIRNAME)

    warn "Directory #{DIRNAME} not found, please run `rbgithook set {file} {command}`"
    exit 1
  end

  def self.write_hook_to_file(file_name, hook_command, append: false)
    file_path = "#{DIRNAME}/#{file_name}"
    mode = append ? "a" : "w"
    File.open(file_path, mode) do |file|
      file.write("#!/usr/bin/env sh\n\n") unless append
      file.write("#{hook_command}\n")
    end
    FileUtils.chmod(0o755, file_path)
  end
end
