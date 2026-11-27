#!/usr/bin/env python3
"""Sign an unsigned device build, including Xcode's debug/preview libraries."""
import argparse
import pathlib
import plistlib
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("app", type=pathlib.Path)
parser.add_argument("--profile", required=True, type=pathlib.Path)
parser.add_argument("--identity", required=True)
args = parser.parse_args()
app = args.app.resolve()
profile = plistlib.loads(subprocess.run(
    ["openssl", "cms", "-verify", "-inform", "DER", "-in", str(args.profile), "-noverify"],
    capture_output=True, check=True).stdout)
bundle = plistlib.loads((app / "Info.plist").read_bytes())["CFBundleIdentifier"]
team = profile["TeamIdentifier"][0]
identifier = f"{team}.{bundle}"
allowed = profile["Entitlements"]["application-identifier"]
if allowed != identifier and not (allowed.endswith(".*") and identifier.startswith(allowed[:-1])):
    parser.error("Provisioning profile does not match the app identifier")
entitlements = dict(profile["Entitlements"])
entitlements["application-identifier"] = identifier
entitlements["keychain-access-groups"] = [identifier if x == f"{team}.*" else x
                                           for x in entitlements.get("keychain-access-groups", [])]
entitlements_path = app.parent / "device-entitlements.plist"
entitlements_path.write_bytes(plistlib.dumps(entitlements))
shutil.copyfile(args.profile, app / "embedded.mobileprovision")
libraries = sorted(app.rglob("*.dylib"))
for library in libraries:
    subprocess.run(["codesign", "--force", "--sign", args.identity,
                    "--generate-entitlement-der", str(library)], check=True)
subprocess.run(["codesign", "--force", "--sign", args.identity, "--entitlements",
                str(entitlements_path), "--generate-entitlement-der", str(app)], check=True)
# Bundle verification alone does not detect every unsigned top-level debug dylib.
for target in [*libraries, app]:
    subprocess.run(["codesign", "--verify", "--strict", "--verbose=2", str(target)], check=True)
