# Steam Token Grabber

A lightweight local utility written in Zig that automates the process of extracting and decrypting saved Steam session tokens on Windows.

## Features
- Extracts saved session data from local Steam configurations (`loginusers.vdf` and `local.vdf`).
- Decrypts tokens natively via Windows DPAPI (`CryptUnprotectData`).

---

## How It Works

The program automates the manual recovery of Steam tokens in three steps:

1. **Reading local data:** It parses `C:\Program Files (x86)\Steam\config\loginusers.vdf` to get the account information and the active `SteamID64`.
2. **Generating entropy:** The application derives the required decryption salt (entropy) using the last 6 digits of the extracted Steam ID (formatted as `user_<SID_LAST_6>`).
3. **Decryption:** It reads the encrypted hex-string token from `AppData\Local\Steam\local.vdf`, converts it to binary, and decrypts it using native Windows Crypto API functions.