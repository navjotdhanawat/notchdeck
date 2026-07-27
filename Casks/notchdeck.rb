cask "notchdeck" do
  version "0.1.0"
  sha256 :no_check

  url "https://notchdeck.app/api/download"
  name "NotchDeck"
  desc "MacBook notch AI agent command deck"
  homepage "https://notchdeck.app/"

  livecheck do
    url "https://notchdeck.app/appcast.xml"
    strategy :sparkle
  end

  depends_on macos: :sonoma

  app "NotchDeck.app"

  zap trash: [
    "~/Library/Application Support/NotchDeck",
    "~/Library/Caches/com.navjotdhanawat.NotchDeck",
    "~/Library/Preferences/com.navjotdhanawat.NotchDeck.plist",
    "~/Library/Saved Application State/com.navjotdhanawat.NotchDeck.savedState",
  ]
end
