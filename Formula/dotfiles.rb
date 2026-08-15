# Drop this into a tap (e.g. rick/homebrew-tap) once the interface settles:
#
#   brew tap rick/tap git@github.com:rick/homebrew-tap.git
#   brew install rick/tap/dotfiles
#
# Fill in url/sha256 from a tagged release:
#
#   git tag v0.1.0 && git push --tags
#   curl -sL https://github.com/rick/dotfiles-tool/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
class Dotfiles < Formula
  desc "Link config repos into $HOME with GNU Stow and 1Password"
  homepage "https://github.com/rick/dotfiles-tool"
  url "https://github.com/rick/dotfiles-tool/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_ME"
  license "MIT"

  depends_on "stow"
  depends_on cask: "1password-cli"

  def install
    bin.install "bin/dotfiles"
  end

  test do
    assert_match "dotfiles", shell_output("#{bin}/dotfiles version")
  end
end
