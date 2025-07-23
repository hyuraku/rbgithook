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
        expect { Rbgithook.validate_arguments("../evil", "rubocop") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
        expect { Rbgithook.validate_arguments("path/traversal", "rubocop") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
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

      it "should raise error for path traversal patterns" do
        expect { Rbgithook.validate_file_name("../evil") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
        expect { Rbgithook.validate_file_name("path/traversal") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
        expect { Rbgithook.validate_file_name("path\\traversal") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
      end

      it "should raise error for URL encoded path traversal" do
        expect { Rbgithook.validate_file_name("file%2e%2e") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
        expect { Rbgithook.validate_file_name("file%2ftraversal") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
        expect { Rbgithook.validate_file_name("file%5ctraversal") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
      end

      it "should raise error for null byte injection" do
        expect { Rbgithook.validate_file_name("file\0name") }.to raise_error(ArgumentError, /dangerous path traversal pattern/)
      end

      it "should raise error for hidden files" do
        expect { Rbgithook.validate_file_name(".hidden") }.to raise_error(ArgumentError, "File name cannot start with dot (hidden files not allowed)")
        expect { Rbgithook.validate_file_name(".bashrc") }.to raise_error(ArgumentError, "File name cannot start with dot (hidden files not allowed)")
      end

      it "should raise error for control characters" do
        expect { Rbgithook.validate_file_name("file\x01name") }.to raise_error(ArgumentError, "File name cannot contain control characters")
        expect { Rbgithook.validate_file_name("file\x7fname") }.to raise_error(ArgumentError, "File name cannot contain control characters")
      end

      it "should raise error for invalid characters" do
        expect { Rbgithook.validate_file_name("file@name") }.to raise_error(ArgumentError, "File name can only contain alphanumeric characters, hyphens, and underscores")
        expect { Rbgithook.validate_file_name("file name") }.to raise_error(ArgumentError, "File name can only contain alphanumeric characters, hyphens, and underscores")
        expect { Rbgithook.validate_file_name("file$name") }.to raise_error(ArgumentError, "File name can only contain alphanumeric characters, hyphens, and underscores")
      end

      it "should allow valid file names" do
        expect { Rbgithook.validate_file_name("pre-commit") }.not_to raise_error
        expect { Rbgithook.validate_file_name("pre_push") }.not_to raise_error
        expect { Rbgithook.validate_file_name("commit-msg") }.not_to raise_error
        expect { Rbgithook.validate_file_name("hook123") }.not_to raise_error
        expect { Rbgithook.validate_file_name("HOOK_NAME") }.not_to raise_error
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

    before do
      allow(Rbgithook).to receive(:ensure_secure_directory)
      allow(Rbgithook).to receive(:validate_secure_file_path)
    end

    it "should write hook to file in write mode" do
      expect(File).to receive(:open).with(file_path, "w").and_yield(double("file").as_null_object)
      Rbgithook.write_hook_to_file("pre-commit", "rubocop")
    end

    it "should write hook to file in append mode" do
      expect(File).to receive(:open).with(file_path, "a").and_yield(double("file").as_null_object)
      Rbgithook.write_hook_to_file("pre-commit", "rubocop", append: true)
    end

    it "should call security validation methods" do
      allow(File).to receive(:open).and_yield(double("file").as_null_object)
      
      expect(Rbgithook).to receive(:ensure_secure_directory)
      expect(Rbgithook).to receive(:validate_secure_file_path).with(file_path, "pre-commit")
      
      Rbgithook.write_hook_to_file("pre-commit", "rubocop")
    end
  end

  describe ".validate_secure_file_path" do
    let(:safe_path) { File.join(".rbgithook", "pre-commit") }
    let(:dangerous_path) { File.join(".rbgithook", "../../../etc/passwd") }

    it "should allow safe paths within directory" do
      expect { Rbgithook.validate_secure_file_path(safe_path, "pre-commit") }.not_to raise_error
    end

    it "should reject paths that resolve outside directory" do
      expect { Rbgithook.validate_secure_file_path(dangerous_path, "../../../etc/passwd") }.to raise_error(ArgumentError, /Security violation.*resolves outside designated directory/)
    end

    it "should reject symbolic links" do
      allow(File).to receive(:symlink?).with(File.dirname(safe_path)).and_return(true)
      expect { Rbgithook.validate_secure_file_path(safe_path, "pre-commit") }.to raise_error(ArgumentError, /Security violation.*symbolic links not allowed/)
    end
  end

  describe ".ensure_secure_directory" do
    it "should create directory if it does not exist" do
      allow(Dir).to receive(:exist?).with(".rbgithook").and_return(false)
      expect(FileUtils).to receive(:mkdir_p).with(".rbgithook")
      expect(FileUtils).to receive(:chmod).with(0o755, ".rbgithook")
      
      Rbgithook.ensure_secure_directory
    end

    it "should not create directory if it already exists" do
      allow(Dir).to receive(:exist?).with(".rbgithook").and_return(true)
      expect(FileUtils).not_to receive(:mkdir_p)
      
      Rbgithook.ensure_secure_directory
    end
  end
end
