"""Fail early on release inputs; never print signing secrets."""
import json
import os
import pathlib
import re
import subprocess


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
    # keytool's env syntax keeps passwords out of command arguments and logs.
    cert = subprocess.run(["keytool", "-exportcert", "-rfc", "-keystore", str(path),
                           "-storepass:env", "ANDROID_UPLOAD_STORE_PASSWORD", "-alias",
                           os.environ["ANDROID_UPLOAD_KEY_ALIAS"]], capture_output=True)
    if cert.returncode:
        raise SystemExit("Cannot read the signing certificate: verify store password and alias")
    info = subprocess.run(["keytool", "-printcert"], input=cert.stdout, capture_output=True, check=True)
    # These fingerprints are public identifiers, useful for OAuth/App Check setup.
    for line in info.stdout.decode().splitlines():
        if "SHA1:" in line or "SHA256:" in line:
            print(line.strip())
    sha1 = re.search(r"SHA1:\s*([0-9A-F:]+)", info.stdout.decode())
    registered = {c.get("android_info", {}).get("certificate_hash", "").lower()
                  for c in clients[0].get("oauth_client", []) if c["client_type"] == 1}
    if not sha1 or sha1.group(1).replace(":", "").lower() not in registered:
        raise SystemExit("APK signing certificate is not registered in google-services.json. Register its SHA-1 in Firebase and download the updated file. Play Store signing needs its separate certificate too.")
    if not any(c["client_type"] == 3 for c in clients[0].get("oauth_client", [])):
        raise SystemExit("Firebase config lacks the web OAuth client required for native Google sign-in")
    app_id = os.environ.get("STONES_PLAY_GAMES_APP_ID", "")
    if app_id and (not app_id.isdigit() or int(app_id) <= 0):
        raise SystemExit("STONES_PLAY_GAMES_APP_ID must be the numeric Play Games application ID")
    print("Android release inputs validated; Google/Play Console publishing settings still require device verification.")


if __name__ == "__main__":
    main()
