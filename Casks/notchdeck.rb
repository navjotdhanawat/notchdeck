cask "notchdeck" do
  version "0.3.0"
  sha256 "60a91256afff997c6ba59cf2944a7cab3e9ea74706bf9028a95a94106558ccbf"

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
