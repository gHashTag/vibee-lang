class Vibee < Formula
  desc "Specification-first programming language for Trinity OS"
  homepage "https://github.com/gHashTag/vibee-lang"
  version "1.0.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/gHashTag/vibee-lang/releases/download/v1.0.0/vibee-macos-arm64"
      sha256 "ef3e52c5ad79d57fa0e10cdfb838557e00980952fd310e28daac42c0e5837a97"
    else
      url "https://github.com/gHashTag/vibee-lang/releases/download/v1.0.0/vibee-macos-x86_64"
      sha256 "a7c9910a11128a1504770277e27799da55be14a9fa4b85adf7878e17f326e3fe"
    end
  end

  def install
    bin.install "vibee-macos-arm64" => "vibee" if Hardware::CPU.arm?
    bin.install "vibee-macos-x86_64" => "vibee" if Hardware::CPU.intel?
  end

  test do
    system "#{bin}/vibee", "--version"
  end
end
