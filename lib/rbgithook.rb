# frozen_string_literal: true

require_relative "rbgithook/version"

module Rbgithook
  DIRNAME = ".rbgithook"

  def self.install
    FileUtils.mkdir(DIRNAME) unless Dir.exist?(DIRNAME)

    system("git", "config", "core.hooksPath", DIRNAME)
  end

  def self.set(args)
    file_name = get_file_name(args[0])
    hook_command = get_hook_command(args[1])
    Dir.chdir(DIRNAME)
    File.open(file_name.to_s, "w") do |file|
      file.write("#!/usr/bin/env sh\n#{hook_command}")
    end
    FileUtils.chmod(0o755, file_name)
  end

  def self.add(args)
    file_name = get_file_name(args[0])
    hook_command = get_hook_command(args[1])
    unless Dir.exist?(DIRNAME)
      warning_message("Directory", file_name, hook_command)
      exit 1
    end
    Dir.chdir(DIRNAME)
    if File.exist?(file_name)
      File.open(file_name.to_s, "a") do |file|
        file.write("\n#{hook_command}")
      end
    else
      warning_message("File", file_name, hook_command)
    end
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

  def self.warning_message(target, file_name, hook_command)
    warn "#{target} not found, please run `rbgithook set #{file_name} '#{hook_command}'`"
  end

  def self.get_file_name(file_name)
    if file_name.nil?
      warn "Please specify a file to hook"
      exit 1
    end
    file_name
  end

  def self.get_hook_command(hook_command)
    if hook_command.nil?
      warn "Please specify a command to run"
      exit 1
    end
    hook_command
  end
end
