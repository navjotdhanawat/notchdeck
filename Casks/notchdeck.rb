cask "notchdeck" do
  version "0.2.0"
  sha256 "95c3b96c998e612e58224381fc0c4253e75afd5000ddab508b2895e91909e801"

  url "https://github.com/navjotdhanawat/notchdeck/releases/download/v#{version}/NotchDeck.dmg"
  name "NotchDeck"
  desc "MacBook notch AI agent command deck"
  homepage "https://notchdeck.app/"

  livecheck do
    url "https://notchdeck.app/appcast.xml"
    strategy :sparkle
  end

  depends_on macos: :sonoma

  app "NotchDeck.app"

  postflight do
    system_command "xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/NotchDeck.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/NotchDeck",
    "~/Library/Caches/com.navjotdhanawat.NotchDeck",
    "~/Library/Preferences/com.navjotdhanawat.NotchDeck.plist",
    "~/Library/Saved Application State/com.navjotdhanawat.NotchDeck.savedState",
  ]
end
