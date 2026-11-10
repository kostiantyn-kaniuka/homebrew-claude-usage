class ClaudeUsage < Formula
  desc "macOS desktop widget showing your Claude plan usage limits"
  homepage "REPO_URL"
  url "REPO_URL.git", tag: "v1.0.0"
  version "1.0.0"

  depends_on macos: :sonoma

  def install
    ENV["VERSION"] = version.to_s
    system "./build.sh", buildpath/"dist"
    prefix.install "dist/ClaudeUsage.app"
    bin.install "claude-usage"
  end

  def caveats
    <<~EOS
      Finish setup with:
        claude-usage install

      Then right-click the desktop → Edit Widgets… → search "Claude Usage".
      Requires Claude Code installed and logged in (Pro/Max plan).
    EOS
  end

  test do
    assert_path_exists prefix/"ClaudeUsage.app/Contents/PlugIns/ClaudeUsageWidget.appex"
  end
end
