# frozen_string_literal: true

require_relative "rbgithook/version"

module Rbgithook
  def self.install
    dir = ".rbgithook"
    FileUtils.mkdir(dir) unless Dir.exist?(dir)

    system("git", "config", "core.hooksPath", dir)
  end

  def self.add(args)
    file_name = args[0]
    hook_command = args[1]
    Dir.chdir(".rbgithook")
    file = File.open(file_name.to_s, "w")
    file.write(hook_command)
    FileUtils.chmod(0o755, file_name)
  end

  def self.uninstall
    system("git", "config", "--unset", "core.hooksPath")
  end
end
