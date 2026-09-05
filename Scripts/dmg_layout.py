#!/usr/bin/env python3
"""
Writes the Finder .DS_Store for the DMG volume directly (no Finder scripting needed).

Usage:
  dmg_layout.py <mounted-volume> <app-name.app> <background-relpath> \
                <win_w> <win_h> <icon_size> <app_x> <app_y> <apps_x> <apps_y>

Requires: pip install ds_store mac_alias   (make_dmg.sh sets up a venv for this).
"""
import os
import struct
import sys

from ds_store import DSStore
from mac_alias import Alias


def main() -> int:
    if len(sys.argv) != 11:
        print(__doc__, file=sys.stderr)
        return 2

    volume, app_name, bg_rel = sys.argv[1], sys.argv[2], sys.argv[3]
    win_w, win_h, icon_size, app_x, app_y, apps_x, apps_y = (int(v) for v in sys.argv[4:11])

    bg_path = os.path.join(volume, bg_rel)
    if not os.path.exists(bg_path):
        print(f"background not found: {bg_path}", file=sys.stderr)
        return 1

    top, left = 120, 200
    ds_path = os.path.join(volume, ".DS_Store")
    if os.path.exists(ds_path):
        os.remove(ds_path)

    with DSStore.open(ds_path, "w+") as ds:
        # Window frame: top, left, bottom, right + view kind "icnv"
        ds["."]["fwi0"] = ("blob", struct.pack(">hhhh4s", top, left, top + win_h, left + win_w, b"icnv") + b"\x00" * 4)
        ds["."]["vSrn"] = ("long", 1)

        # Browser window settings (Finder ≥ 10.7)
        ds["."]["bwsp"] = {
            "ShowStatusBar": False,
            "WindowBounds": "{{%d, %d}, {%d, %d}}" % (left, top, win_w, win_h),
            "ContainerShowSidebar": False,
            "PreviewPaneVisibility": False,
            "SidebarWidth": 0,
            "ShowTabView": False,
            "ShowToolbar": False,
            "ShowPathbar": False,
            "ShowSidebar": False,
        }

        # Icon view options with the background picture
        alias = Alias.for_file(bg_path)
        ds["."]["icvp"] = {
            "viewOptionsVersion": 1,
            "backgroundType": 2,  # picture
            "backgroundColorRed": 1.0,
            "backgroundColorGreen": 1.0,
            "backgroundColorBlue": 1.0,
            "backgroundImageAlias": alias.to_bytes(),
            "showIconPreview": True,
            "showItemInfo": False,
            "textSize": 13.0,
            "iconSize": float(icon_size),
            "arrangeBy": "none",
            "gridOffsetX": 0.0,
            "gridOffsetY": 0.0,
            "gridSpacing": 100.0,
            "labelOnBottom": True,
            "scrollPositionX": 0.0,
            "scrollPositionY": 0.0,
        }

        ds[app_name]["Iloc"] = (app_x, app_y)
        ds["Applications"]["Iloc"] = (apps_x, apps_y)

    print(f"  .DS_Store written → {ds_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
