# frozen_string_literal: true

require_relative "rbgithook/version"

module Rbgithook
  def self.install
    dir = ".rbgithook"
    FileUtils.mkdir(dir) unless Dir.exist?(dir)

    system("git", "config", "core.hooksPath", dir)
  end

  def self.set(args)
    file_name = args[0]
    hook_command = args[1]
    Dir.chdir(".rbgithook")
    file = File.open(file_name.to_s, "w")
    file.write("#!/usr/bin/env sh\n#{hook_command}")
    FileUtils.chmod(0o755, file_name)
  end

  def self.add(args)
    file_name = args[0]
    hook_command = args[1]
    Dir.chdir(".rbgithook")
    if File.exist?(file_name)
      file = File.open(file_name.to_s, "a")
      file.write("\n#{hook_command}")
      FileUtils.chmod(0o755, file_name)
    else
      warn "File not found, please run `rbgithook set #{file_name} #{hook_command}`"
    end
  end

  def self.uninstall
    system("git", "config", "--unset", "core.hooksPath")
  end

  def self.help
    puts <<~USAGE
      bgithook [command] {file} {command}

      install - Install hook
      set {file} {command} - Set a hook
      add {file} {command} - Add a hook
      uninstall - Uninstall hook
      help   - Show this usage
    USAGE
  end
end
