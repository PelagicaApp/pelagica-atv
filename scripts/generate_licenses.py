#!/usr/bin/env python3
"""Generates Pelagica/Resources/licenses.json from the resolved Swift packages.

Run after changing dependencies. Resolve packages in Xcode first so the
checkouts exist in DerivedData.
"""

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOLVED = os.path.join(ROOT, "Pelagica.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
OUTPUT = os.path.join(ROOT, "Pelagica/Resources/licenses.json")

LICENSE_NAMES = [
    ("GNU LESSER GENERAL PUBLIC LICENSE", "LGPL-2.1"),
    ("GNU GENERAL PUBLIC LICENSE", "GPL-3.0"),
    ("Mozilla Public License Version 2.0", "MPL-2.0"),
    ("Apache License", "Apache-2.0"),
    ("MIT License", "MIT"),
]


def find_checkouts():
    pattern = os.path.expanduser("~/Library/Developer/Xcode/DerivedData/Pelagica-*/SourcePackages/checkouts")
    matches = sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True)
    if not matches:
        sys.exit("No package checkouts found. Resolve packages in Xcode first.")
    return matches[0]


def read_first(directory, prefixes):
    for name in sorted(os.listdir(directory)):
        if name.lower().startswith(prefixes):
            with open(os.path.join(directory, name), encoding="utf-8") as f:
                return f.read().strip()
    return None


def license_name(text):
    for marker, name in LICENSE_NAMES:
        if marker.lower() in text[:500].lower():
            return name
    return "Unknown"


def display_name(location):
    name = location.rstrip("/").split("/")[-1]
    return re.sub(r"\.git$", "", name)


def main():
    checkouts = find_checkouts()
    with open(RESOLVED, encoding="utf-8") as f:
        pins = json.load(f)["pins"]

    entries = []
    for pin in sorted(pins, key=lambda p: p["identity"].lower()):
        directory = os.path.join(checkouts, pin["identity"])
        if not os.path.isdir(directory):
            sys.exit(f"Missing checkout for {pin['identity']} in {checkouts}")

        text = read_first(directory, ("license", "copying"))
        if text is None:
            sys.exit(f"No license file found for {pin['identity']}")

        notice = read_first(directory, ("notice",))
        if notice:
            text += "\n\n" + notice

        entries.append({
            "name": display_name(pin["location"]),
            "version": pin["state"].get("version"),
            "url": re.sub(r"\.git$", "", pin["location"]),
            "license": license_name(text),
            "text": text,
        })

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2, ensure_ascii=False)
        f.write("\n")

    for entry in entries:
        print(f"{entry['name']} {entry['version']}: {entry['license']}")


if __name__ == "__main__":
    main()
