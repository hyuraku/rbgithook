# frozen_string_literal: true
require "rbgithook"

RSpec.describe Rbgithook do
  describe ".install" do
    it "should create .rbgithook directory and set core.hooksPath" do
      expect(FileUtils).to receive(:mkdir_p).with(".rbgithook")
      expect(Rbgithook).to receive(:system).with("git", "config", "core.hooksPath", ".rbgithook")
      Rbgithook.install
    end
  end

  describe ".set" do
    it "should write hook to file" do
      expect(Rbgithook).to receive(:check_dir_existence)
      expect(Rbgithook).to receive(:write_hook_to_file).with("pre-commit", "rubocop")
      Rbgithook.set(["pre-commit", "rubocop"])
    end
  end

  describe ".add" do
    it "should append hook to file" do
      expect(Rbgithook).to receive(:check_dir_existence)
      expect(Rbgithook).to receive(:write_hook_to_file).with("pre-push", "rspec", append: true)
      Rbgithook.add(["pre-push", "rspec"])
    end
  end

  describe ".uninstall" do
    it "should unset core.hooksPath" do
      expect(Rbgithook).to receive(:system).with("git", "config", "--unset", "core.hooksPath")
      Rbgithook.uninstall
    end
  end

  describe ".check_dir_existence" do
    it "should print warning and exit if directory does not exist" do
      expect(Dir).to receive(:exist?).with(".rbgithook").and_return(false)
      expect(Rbgithook).to receive(:warn).with("Directory .rbgithook not found, please run `rbgithook set {file} {command}`")
      expect(Rbgithook).to receive(:exit).with(1)
      Rbgithook.check_dir_existence
    end

    it "should not print warning or exit if directory exists" do
      expect(Dir).to receive(:exist?).with(".rbgithook").and_return(true)
      expect(Rbgithook).not_to receive(:warn)
      expect(Rbgithook).not_to receive(:exit)
      Rbgithook.check_dir_existence
    end
  end

  describe ".write_hook_to_file" do
    let(:file_path) { ".rbgithook/pre-commit" }

    it "should write hook to file in write mode" do
      expect(File).to receive(:open).with(file_path, "w").and_yield(double("file").as_null_object)
      Rbgithook.write_hook_to_file("pre-commit", "rubocop")
    end

    it "should write hook to file in append mode" do
      expect(File).to receive(:open).with(file_path, "a").and_yield(double("file").as_null_object)
      Rbgithook.write_hook_to_file("pre-commit", "rubocop", append: true)
    end
  end
end
