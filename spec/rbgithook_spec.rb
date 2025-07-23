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
      expect(Rbgithook).to receive(:warn).with("Directory .rbgithook not found, please run `rbgithook install` first")
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

    describe ".validate_arguments" do
      it "should raise error for empty file name" do
        expect { Rbgithook.validate_arguments("", "rubocop") }.to raise_error(ArgumentError, "File name cannot be empty")
        expect { Rbgithook.validate_arguments(nil, "rubocop") }.to raise_error(ArgumentError, "File name cannot be empty")
      end

      it "should raise error for path traversal attempts" do
        expect { Rbgithook.validate_arguments("../evil", "rubocop") }.to raise_error(ArgumentError, "File name cannot contain path separators or traversal patterns")
        expect { Rbgithook.validate_arguments("path/traversal", "rubocop") }.to raise_error(ArgumentError, "File name cannot contain path separators or traversal patterns")
      end

      it "should raise error for invalid file name characters" do
        expect { Rbgithook.validate_arguments("file@name", "rubocop") }.to raise_error(ArgumentError, "File name can only contain alphanumeric characters, hyphens, and underscores")
        expect { Rbgithook.validate_arguments("file name", "rubocop") }.to raise_error(ArgumentError, "File name can only contain alphanumeric characters, hyphens, and underscores")
      end

      it "should raise error for empty hook command" do
        expect { Rbgithook.validate_arguments("pre-commit", "") }.to raise_error(ArgumentError, "Hook command cannot be empty")
        expect { Rbgithook.validate_arguments("pre-commit", nil) }.to raise_error(ArgumentError, "Hook command cannot be empty")
      end

      it "should raise error for dangerous characters in hook command" do
        expect { Rbgithook.validate_arguments("pre-commit", "rm -rf /; echo safe") }.to raise_error(ArgumentError, /Hook command contains potentially dangerous characters/)
        expect { Rbgithook.validate_arguments("pre-commit", "echo `whoami`") }.to raise_error(ArgumentError, /Hook command contains potentially dangerous characters/)
        expect { Rbgithook.validate_arguments("pre-commit", "command && rm -rf /") }.to raise_error(ArgumentError, /Hook command contains potentially dangerous characters/)
      end

      it "should raise error for multiline commands" do
        expect { Rbgithook.validate_arguments("pre-commit", "rubocop\nrm -rf /") }.to raise_error(ArgumentError, "Hook command cannot contain newline characters")
        expect { Rbgithook.validate_arguments("pre-commit", "rubocop\r\nrm -rf /") }.to raise_error(ArgumentError, "Hook command cannot contain newline characters")
      end

      it "should allow valid arguments" do
        expect { Rbgithook.validate_arguments("pre-commit", "rubocop -a") }.not_to raise_error
        expect { Rbgithook.validate_arguments("pre_push", "bundle exec rspec") }.not_to raise_error
        expect { Rbgithook.validate_arguments("commit-msg", "echo testing") }.not_to raise_error
      end
    end

    describe ".validate_file_name" do
      it "should raise error for empty file name" do
        expect { Rbgithook.validate_file_name("") }.to raise_error(ArgumentError, "File name cannot be empty")
        expect { Rbgithook.validate_file_name(nil) }.to raise_error(ArgumentError, "File name cannot be empty")
      end

      it "should allow valid file names" do
        expect { Rbgithook.validate_file_name("pre-commit") }.not_to raise_error
        expect { Rbgithook.validate_file_name("pre_push") }.not_to raise_error
        expect { Rbgithook.validate_file_name("commit-msg") }.not_to raise_error
      end
    end

    describe ".validate_hook_command" do
      it "should raise error for empty hook command" do
        expect { Rbgithook.validate_hook_command("") }.to raise_error(ArgumentError, "Hook command cannot be empty")
        expect { Rbgithook.validate_hook_command(nil) }.to raise_error(ArgumentError, "Hook command cannot be empty")
      end

      it "should allow valid hook commands" do
        expect { Rbgithook.validate_hook_command("rubocop -a") }.not_to raise_error
        expect { Rbgithook.validate_hook_command("bundle exec rspec") }.not_to raise_error
      end
    end

    describe ".sanitize_hook_command" do
    it "should remove dangerous shell metacharacters" do
      expect(Rbgithook.sanitize_hook_command("echo `whoami`")).to eq("echo whoami")
      expect(Rbgithook.sanitize_hook_command("echo $USER")).to eq("echo USER")
      expect(Rbgithook.sanitize_hook_command("normal command")).to eq("normal command")
    end
  end

  describe ".write_hook_to_file" do
    let(:file_path) { File.join(".rbgithook", "pre-commit") }

    it "should write hook to file in write mode" do
      expect(File).to receive(:open).with(file_path, "w").and_yield(double("file").as_null_object)
      Rbgithook.write_hook_to_file("pre-commit", "rubocop")
    end

    it "should write hook to file in append mode" do
      expect(File).to receive(:open).with(file_path, "a").and_yield(double("file").as_null_object)
      Rbgithook.write_hook_to_file("pre-commit", "rubocop", append: true)
    end

    it "should prevent path traversal in file writing" do
      expect { Rbgithook.write_hook_to_file("../../../etc/passwd", "malicious") }.to raise_error(ArgumentError, /Invalid file path/)
    end
  end
end
