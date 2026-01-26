class Vibee < Formula
  desc "Specification-first programming language for Trinity OS"
  homepage "https://github.com/gHashTag/vibee-lang"
  url "https://github.com/gHashTag/vibee-lang/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"

  depends_on "zig" => :build

  def install
    Dir.chdir("src/vibeec") do
      system "zig", "build", "-Doptimize=ReleaseSafe"
      bin.install "zig-out/bin/vibeec" => "vibee"
    end
  end

  test do
    system "#{bin}/vibee", "--version"
  end
end
