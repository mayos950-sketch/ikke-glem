import plistlib
import struct
import sys
import wave
from pathlib import Path

app = Path(sys.argv[1])
with (app / "Info.plist").open("rb") as file:
    info = plistlib.load(file)
assert info["CFBundleIdentifier"] == "com.marioproter.IkkeGlem"
assert info["CFBundleShortVersionString"] == "1.0"
assert info["CFBundleVersion"] == "5"
assert info["ITSAppUsesNonExemptEncryption"] is False
assert "CFBundleIcons" in info, "Release app icon is missing"
with (app / "PrivacyInfo.xcprivacy").open("rb") as file:
    privacy = plistlib.load(file)
assert privacy["NSPrivacyTracking"] is False
assert privacy["NSPrivacyAccessedAPITypes"][0]["NSPrivacyAccessedAPITypeReasons"] == ["CA92.1"]
with wave.open(str(app / "ikke-glem-fanfare.wav")) as sound:
    assert sound.getnframes() / sound.getframerate() < 30
    assert sound.getsampwidth() == 2
icon = Path("ios/IkkeGlem/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()
assert icon[:8] == b"\x89PNG\r\n\x1a\n"
width, height, depth, color = struct.unpack(">IIBB", icon[16:26])
assert (width, height) == (1024, 1024), "App Store icon must be 1024 square"
assert color in (0, 2, 3), "App Store icon must not have an alpha channel"
offset = 8
while offset < len(icon):
    length = struct.unpack(">I", icon[offset:offset + 4])[0]
    assert icon[offset + 4:offset + 8] != b"tRNS", "App Store icon must not have transparency"
    offset += 12 + length
print("Release archive: identity, icon, privacy manifest and notification sound checked")
