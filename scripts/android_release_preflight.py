"""Fail early on release inputs; never print signing secrets."""
import json
import os
import pathlib
import re
import subprocess


def recover_alias(path, registered):
    """Recover only one private key with the application's registered leaf cert."""
    listing = subprocess.run([
        "keytool", "-J-Duser.language=en", "-J-Duser.country=US", "-list", "-v",
        "-keystore", str(path), "-storepass:env", "ANDROID_UPLOAD_STORE_PASSWORD"
    ], capture_output=True)
    if listing.returncode:
        raise SystemExit("Cannot inspect existing upload keystore; verify store password and file")
    matches = []
    for entry in re.split(r"(?m)^Alias name: ", listing.stdout.decode(errors="replace"))[1:]:
        alias = entry.splitlines()[0].strip()
        fingerprint = re.search(r"SHA1:\s*([0-9A-F:]+)", entry)
        if ("Entry type: PrivateKeyEntry" in entry and fingerprint
                and fingerprint.group(1).replace(":", "").lower() in registered):
            matches.append(alias)
    if len(matches) != 1:
        raise SystemExit("ANDROID_UPLOAD_KEY_ALIAS is invalid and the keystore does not contain exactly one matching registered private key")
    alias = matches[0]
    if not alias or any(char in alias for char in "\r\n\x00"):
        raise SystemExit("Upload key alias cannot be passed safely to the build")
    print("Resolved the existing upload key by its registered certificate; signing identity is unchanged.")
    return alias


def export_certificate(path, alias):
    return subprocess.run(["keytool", "-exportcert", "-rfc", "-keystore", str(path),
                           "-storepass:env", "ANDROID_UPLOAD_STORE_PASSWORD", "-alias",
                           alias], capture_output=True)


def main():
    required = ["ANDROID_UPLOAD_STORE_FILE", "ANDROID_UPLOAD_STORE_PASSWORD",
                "ANDROID_UPLOAD_KEY_ALIAS", "ANDROID_UPLOAD_KEY_PASSWORD"]
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit("Missing signing inputs: " + ", ".join(missing))
    path = pathlib.Path(os.environ[required[0]])
    if not path.is_file() or not path.stat().st_size:
        raise SystemExit("Upload keystore is missing or empty")
    config = json.loads(pathlib.Path("android/app/google-services.json").read_text())
    clients = [c for c in config["client"] if c["client_info"].get("android_client_info", {}).get("package_name") == "com.douglastkaiser.stones"]
    if config["project_info"]["project_id"] != "stones-9a6a0" or len(clients) != 1:
        raise SystemExit("Firebase config does not match the Stones Android application")
    registered = {c.get("android_info", {}).get("certificate_hash", "").lower()
                  for c in clients[0].get("oauth_client", []) if c["client_type"] == 1}
    alias = os.environ["ANDROID_UPLOAD_KEY_ALIAS"]
    # keytool's env syntax keeps passwords out of command arguments and logs.
    cert = export_certificate(path, alias)
    detail = ((cert.stdout or b"") + (cert.stderr or b"")).decode(errors="replace").lower()
    if cert.returncode and "does not exist" in detail and "alias" in detail:
        alias = recover_alias(path, registered)
        cert = export_certificate(path, alias)
    if cert.returncode:
        # Classify the diagnostic without publishing alias, password or raw tool output.
        detail = ((cert.stdout or b"") + (cert.stderr or b"")).decode(errors="replace").lower()
        if "does not exist" in detail and "alias" in detail:
            reason = "ANDROID_UPLOAD_KEY_ALIAS does not identify a key in this keystore"
        elif "password" in detail and ("incorrect" in detail or "tampered" in detail):
            reason = "ANDROID_UPLOAD_STORE_PASSWORD does not open this keystore"
        elif "invalid keystore format" in detail or "unrecognized keystore format" in detail:
            reason = "ANDROID_UPLOAD_KEYSTORE_B64 did not decode to a supported keystore"
        else:
            reason = "Verify the upload keystore, store password and alias together"
        raise SystemExit("Cannot read the signing certificate: " + reason)
    info = subprocess.run(["keytool", "-printcert"], input=cert.stdout, capture_output=True, check=True)
    # These fingerprints are public identifiers, useful for OAuth/App Check setup.
    for line in info.stdout.decode().splitlines():
        if "SHA1:" in line or "SHA256:" in line:
            print(line.strip())
    sha1 = re.search(r"SHA1:\s*([0-9A-F:]+)", info.stdout.decode())
    if not sha1 or sha1.group(1).replace(":", "").lower() not in registered:
        raise SystemExit("APK signing certificate is not registered in google-services.json. Register its SHA-1 in Firebase and download the updated file. Play Store signing needs its separate certificate too.")
    if not any(c["client_type"] == 3 for c in clients[0].get("oauth_client", [])):
        raise SystemExit("Firebase config lacks the web OAuth client required for native Google sign-in")
    app_id = os.environ.get("STONES_PLAY_GAMES_APP_ID", "")
    if app_id and (not app_id.isdigit() or int(app_id) <= 0):
        raise SystemExit("STONES_PLAY_GAMES_APP_ID must be the numeric Play Games application ID")
    if not alias or any(char in alias for char in "\r\n\x00"):
        raise SystemExit("Upload key alias cannot be passed safely to the build")
    if os.environ.get("GITHUB_ENV"):
        # Keep recovered metadata masked and runner-local; never publish the key.
        escaped = alias.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print("::add-mask::" + escaped)
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as env_file:
            env_file.write("STONES_RESOLVED_UPLOAD_KEY_ALIAS=" + alias + "\n")
    print("Android release inputs validated; Google/Play Console publishing settings still require device verification.")


if __name__ == "__main__":
    main()
