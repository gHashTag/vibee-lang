# VIBEE Homebrew Formula
# Installation: brew install gHashTag/vibee/vibee

class Vibee < Formula
  desc "VIBEE - AI-powered development framework for Gleam"
  homepage "https://github.com/gHashTag/vibee-gleam"
  version "1.0.0"
  
  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/gleam-lang/gleam/releases/download/v1.0.0/gleam-v1.0.0-aarch64-apple-darwin.tar.gz"
      sha256 "REPLACE_WITH_ACTUAL_SHA256"
    else
      url "https://github.com/gleam-lang/gleam/releases/download/v1.0.0/gleam-v1.0.0-x86_64-apple-darwin.tar.gz"
      sha256 "REPLACE_WITH_ACTUAL_SHA256"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/gleam-lang/gleam/releases/download/v1.0.0/gleam-v1.0.0-aarch64-unknown-linux-musl.tar.gz"
      sha256 "REPLACE_WITH_ACTUAL_SHA256"
    else
      url "https://github.com/gleam-lang/gleam/releases/download/v1.0.0/gleam-v1.0.0-x86_64-unknown-linux-musl.tar.gz"
      sha256 "REPLACE_WITH_ACTUAL_SHA256"
    end
  end

  depends_on "erlang" => :recommended

  def install
    bin.install "gleam"
    bin.install_symlink "gleam" => "vibee"
    
    # Install shell completions
    # TODO: Generate completions when available
    
    # Install man pages
    # TODO: Add man pages when available
  end

  test do
    system "#{bin}/vibee", "--version"
    system "#{bin}/vibee", "--help"
  end
end
