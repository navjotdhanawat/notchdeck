cask "notchdeck" do
  version "0.3.1"
  sha256 "284b46c4468c8cb1be667c7ce62d5fee50fd5817f915fc0c89c3d79c7b972a9d"

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
