#!/usr/bin/env python3
"""Rebrand a RustDesk source checkout as "HelperBee" (subtitle "Remote assistance · powered by RustDesk").

  python3 apply-branding.py <rustdesk-checkout>

Internal APP_NAME is "HelperBeeRemote": RustDesk derives the install dir, exe, Windows service and
config file names from it, and "HelperBee" alone would collide with the HelperBee agent folder.
The HelperBee agent detects both flavors. Every edit is pattern-based and reported; a pattern that
no longer matches (new RustDesk version) is printed as SKIP instead of failing silently.
AGPL-3.0: the branded build must be published with its source (the fork is public).
"""
import os, pathlib, re, sys

APP = "HelperBeeRemote"
TITLE = "HelperBee"                       # the name people see: window titles, texts ("RustDesk" in translations)
PRODUCT = "HelperBee Remote"              # Windows product name
DESCRIPTION = "HelperBee Remote - remote assistance, based on RustDesk"
PUBLISHER = "pBielli"
# AGPL-3.0: the upstream copyright notice stays next to ours
COPYRIGHT = "Copyright © 2026 pBielli. Based on RustDesk, Copyright © Purslane Tech Pte. Ltd. (AGPL-3.0)"
SUB = "RustDesk · remote assistance"
ACCENT = "0xFFEF443B"
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
ok = skip = 0


def edit(rel, pattern, repl, count=1, flags=0):
    global ok, skip
    f = root / rel
    if not f.exists():
        print(f"SKIP {rel}: missing"); skip += 1; return
    s = f.read_text(encoding="utf-8")
    n = re.subn(pattern, repl, s, count=count, flags=flags)
    if n[1] == 0:
        print(f"SKIP {rel}: pattern not found: {pattern[:60]}"); skip += 1; return
    f.write_text(n[0], encoding="utf-8"); ok += 1
    print(f"ok   {rel} ({n[1]})")


# 1. application name (drives paths, service, config file names)
# set in the main crate (libs/hbb_common is a submodule that the fork would not carry)
edit("src/core_main.rs", r"(pub fn core_main\(\) -> Option<CoreMainAction> \{\n)",
     rf'\g<1>    *hbb_common::config::APP_NAME.write().unwrap() = "{APP}".to_owned();\n'
     # one notification-area icon: the HelperBee agent's (double click opens this window). No own tray icon.
     r'    hbb_common::config::BUILTIN_SETTINGS.write().unwrap().insert(base::config::keys::OPTION_HIDE_TRAY.to_owned(), "Y".to_owned());\n')
# 1b. the name people see is HelperBee (APP_NAME keeps paths and service names apart from the agent)
edit("src/lang.rs", r"let app_name = crate::get_app_name\(\);", f'let app_name = "{TITLE}".to_owned();')
edit("flutter/lib/common.dart", r"(String getWindowName\(\{WindowType\? overrideType\}\) \{\n  final name = )bind\.mainGetAppNameSync\(\);",
     rf"\g<1>'{TITLE}';")
# 2. Windows binary metadata and the Apps & features publisher
edit("Cargo.toml", r'(ProductName\s*=\s*")[^"]*(")', rf"\g<1>{PRODUCT}\g<2>")
edit("Cargo.toml", r'(FileDescription\s*=\s*")[^"]*(")', rf"\g<1>{DESCRIPTION}\g<2>")
edit("Cargo.toml", r'(OriginalFilename\s*=\s*")[^"]*(")', rf"\g<1>{APP.lower()}.exe\g<2>")
edit("Cargo.toml", r'(LegalCopyright\s*=\s*")[^"]*(")', rf'\g<1>{COPYRIGHT}\g<2>\nCompanyName = "{PUBLISHER}"')
RC = "flutter/windows/runner/Runner.rc"
for key, val in [("CompanyName", PUBLISHER), ("FileDescription", DESCRIPTION), ("LegalCopyright", COPYRIGHT),
                 ("InternalName", APP.lower()), ("OriginalFilename", APP.lower() + ".exe"), ("ProductName", PRODUCT)]:
    edit(RC, rf'(VALUE "{key}", )"[^"]*"', rf'\g<1>"{val}"')
edit("src/platform/windows.rs", r'(/v Publisher /t REG_SZ /d \\")\{app_name\}(\\")', rf"\g<1>{PUBLISHER}\g<2>")
# 3. Flutter theme: HelperBee accent
edit("flutter/lib/common.dart", r"(static const Color accent = Color\()0x[0-9A-Fa-f]{8}(\))", rf"\g<1>{ACCENT}\g<2>")
edit("flutter/lib/common.dart", r"(static const Color button = Color\()0x[0-9A-Fa-f]{8}(\))", rf"\g<1>{ACCENT}\g<2>")
# 4. Desktop home = HelperBee home (helperbee_panel.dart): sections "Request assistance" (first, for anyone),
#    "Control a remote desktop" (the RustDesk home page, unchanged) and "Settings"; credits line with the RustDesk
#    and pBielli logos. Data from the local HelperBee agent API.
HERE = pathlib.Path(__file__).resolve().parent
PANEL = os.environ.get("HB_PANEL") or str(HERE / "helperbee_panel.dart")
(root / "flutter/lib/desktop/pages/helperbee_panel.dart").write_text(pathlib.Path(PANEL).read_text(encoding="utf-8"), encoding="utf-8")
ok += 1; print("ok   flutter/lib/desktop/pages/helperbee_panel.dart")
HOME = "flutter/lib/desktop/pages/desktop_home_page.dart"
edit(HOME, r"(import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';\n)", r"\g<1>import 'package:flutter_hbb/desktop/pages/helperbee_panel.dart';\n")
# no big logo above "Your desktop" (the HelperBee mark is in the section bar)
edit(HOME, r"\n[ \t]*Align\(\s*alignment: Alignment\.center,\s*child: loadLogo\(\),\s*\),", "")
edit(HOME, r"(Widget build\(BuildContext context\) \{.*?return _buildBlock\(\s*child: )Row\((.*?)\n    \)\);\n  \}",
     r"\g<1>HelperBeeHome(onNetworkSettings: () => DesktopSettingPage.switch2page(SettingsTabKey.network), remote: Row(\g<2>\n    )));\n  }", flags=re.S)
# credits: the RustDesk logo (upstream icon.svg, kept before step 6 replaces it) and the pBielli logo
A = root / "flutter/assets"
if A.exists():
    icon = A / "icon.svg"
    if icon.exists() and "#EF443B" not in icon.read_text(encoding="utf-8"):
        (A / "rustdesk.svg").write_text(icon.read_text(encoding="utf-8"), encoding="utf-8"); ok += 1; print("ok   flutter/assets/rustdesk.svg")
    elif not (A / "rustdesk.svg").exists():
        print("SKIP flutter/assets/rustdesk.svg: upstream icon.svg not found"); skip += 1
    PB = pathlib.Path(os.environ.get("HB_PBIELLI") or str(HERE / "pbielli.png"))
    if PB.exists():
        (A / "pbielli.png").write_bytes(PB.read_bytes()); ok += 1; print("ok   flutter/assets/pbielli.png")
    else:
        print(f"SKIP flutter/assets/pbielli.png: {PB} missing"); skip += 1

# 5. icons (rounded red square + monitor, same as the HelperBee web GUI)
try:
    from PIL import Image, ImageDraw
except ImportError:
    print("SKIP icons: pip install pillow"); skip += 1
else:
    # the HelperBee mark exported by scripts/brand-export.mjs (rsvg-convert -w 512 brand/mark.svg -o brand/mark-512.png)
    def draw_mark(n=512):  # Hive hexagon + hexagonal lifebuoy, same geometry as brand/mark.svg (no SVG renderer needed)
        import math
        k = n * 4 / 64; im = Image.new("RGBA", (n * 4, n * 4), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        hexp = lambda r: [(k * (32 + r * math.cos(math.radians(-90 + 60 * i))), k * (32 + r * math.sin(math.radians(-90 + 60 * i)))) for i in range(6)]
        d.polygon(hexp(30), fill="#EF443B"); d.polygon(hexp(23), fill="#F8FAFC")
        O, I = hexp(15.5), hexp(8)
        for i in range(6):
            j = (i + 1) % 6
            d.polygon([O[i], O[j], I[j], I[i]], fill="#B8322B" if i % 2 == 0 else "#FFFFFF")
        d.line(O + [O[0]], fill="#B8322B", width=int(k * 1.2)); d.line(I + [I[0]], fill="#B8322B", width=int(k * 1.2))
        return im.resize((n, n), Image.LANCZOS)
    mp = os.environ.get("HB_MARK")
    MARK = Image.open(mp).convert("RGBA") if mp and os.path.exists(mp) else draw_mark()
    def logo(n):
        return MARK.resize((n, n), Image.LANCZOS)
    big = logo(512)
    for rel, n in [("res/icon.png", 512), ("res/128x128.png", 128), ("res/128x128@2x.png", 256), ("res/32x32.png", 32),
                   ("res/64x64.png", 64), ("flutter/assets/helperbee.png", 256), ("flutter/assets/icon.png", 256),
                   ("flutter/assets/logo.png", 256)]:
        # the fork's .gitignore has "*png": the workflow adds these with git add -f, or the build uses RustDesk's
        p = root / rel
        if p.parent.exists():
            logo(n).save(p); ok += 1; print(f"ok   {rel}")
    for rel in ["res/icon.ico", "res/tray-icon.ico", "flutter/windows/runner/resources/app_icon.ico"]:
        p = root / rel
        if p.parent.exists():
            big.save(p, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]); ok += 1; print(f"ok   {rel}")

# 6. the vector icon the window falls back to (and shows when icon.png is missing): the HelperBee mark
SVG = os.environ.get("HB_MARK_SVG") or str(pathlib.Path(__file__).resolve().parent / "mark.svg")
if os.path.exists(SVG) and (root / "flutter/assets").exists():
    (root / "flutter/assets/icon.svg").write_text(pathlib.Path(SVG).read_text(encoding="utf-8"), encoding="utf-8")
    ok += 1; print("ok   flutter/assets/icon.svg")
else:
    print(f"SKIP flutter/assets/icon.svg: {SVG} missing"); skip += 1

print(f"\n{ok} edits applied, {skip} skipped")
sys.exit(1 if ok == 0 else 0)
