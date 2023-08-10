# Passbolt Helper

<!--
Script to make Passbolt CLI more user friendly.
Copyright (C) 2023  Twilight Sparkle

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

Script to make [Passbolt CLI](https://github.com/passbolt/passbolt_cli) more user friendly.

Due to this script parsing potentially unstable output, this is only verified to work with `master` branch of
`passbolt_cli` as of July 26, 2023 with commit `289017e`.

Other versions may work, and if it does not, it should not break anything. But it may show you badly formatted or
incorrect data.

If there is a more elegant way of getting and parsing the data from `passbolt_cli` that I have missed, let me know :)

## Setup

- Install [passbolt_cli](https://github.com/passbolt/passbolt_cli)
- Import the required keys into gpg

  ```bash
  # Import the public key for your Passbolt server
  passbolt server-key --domain=https://passbolt.example.com | gpg --import

  # Import your Passbolt account private key
  gpg --import /path/to/passbolt_private.asc

  # Get the key IDs for your keys
  # (The ID is the 40-character long random string)
  gpg --list-keys

  # Set the trust of the server key to ultimate
  gpg --edit-key <server_key_id>
  gpg> trust
  Please decide how far you trust this user to correctly verify other users keys
  Your decision? 5
  Do you really want to set this key to ultimate trust? (y/N) y
  gpg> quit

  # Repeat the previous step to set the trust of your key to ultimate
  ```

- Create `passbolt_cli` config directory

  ```bash
  mkdir -p ~/.config/passbolt
  ```

- Create `passbolt_cli` config file `~/.config/passbolt/config.json`

  ```json
  {
    "domain": {
      "baseUrl": "https://passbolt.example.com",
      "publicKey": {
        "fingerprint": "ServerGpgKeyID"
      }
    },
    "user": {
      "firstname": "YourFirstName",
      "lastname": "YourLastName",
      "email": "YourEmail@address",
      "privateKey": {
        "fingerprint": "YourGpgKeyID"
      }
    },
    "mfa": {
      "providers": ["totp"]
    },
    "agentOptions": {
      "rejectUnauthorized": true
    }
  }
  ```

  If you are using a YubiKey for 2FA, see <https://github.com/passbolt/passbolt_cli#mfa-preferences>.

- Test `passbolt_cli` to make sure it's working

  ```bash
  passbolt find
  ```

  Should return a list of all your passbolt entries.

- `git clone` or
  <a href="https://raw.githubusercontent.com/Twi1ightSparkle/passbolt-helper/main/passbolt.sh" download>download</a>
  the script.
- Add an alias to your `.bashrc`/`.zshrc`/etc file

  ```bash
  alias pb='/path/to/passbolt-helper/passbolt.sh'
  ```

- Set up your Passbolt. The way `passbolt_cli` works is really dumb. First, it does not have any way of searching, it
  can only return all your entries. Seconds, and relevant here, `passbolt_cli` only returns your Passbolt entries in a
  space separated list. So the only way to parse it programmatically is to count characters. To make this possible, you
  must add a new password to your Passbolt account where the entry name, the username, and the URL is any string that is
  **exactly 200 characters** long. Here is one for convenient copy-pasting
  `ZZZZdummyEntryIgnoreThisVeryLongStringqTWSG1TqYTyhmceL51ncBPv873TQCmCVl3SraSr84Xw2a3GFXOiQqgeFw66rtRD35bZ771anUoUtBPWVyldpWHeZwt5M4od4LsS4P85kzIraUDRj3pfQPMjvYVgzkjaRPGZeHoTzVmS1J7lr0TzJcu4CZXXYgC7SNE`

- Optionally change program defaults by setting one or more of of these in your `.bashrc`/`.zshrc`/etc file

  ```bash
  export PASSBOLT_CLI_HELPER_COPY="true"
  export PASSBOLT_CLI_HELPER_SHOW_DESC="true"
  export PASSBOLT_CLI_HELPER_SHOW_PW="true"
  ```

## Errors

If you get an error from `passbolt_cli` complaining about pinentry, install pinentry for your OS. On my Mac, I had to
install `pinentry-mac`, then add `pinentry-program /usr/local/bin/pinentry-mac` to `~/.gnupg/gpg-agent.conf`.

## Example

```bash
$ pb --help
Simple helper script to make Passbolt CLI a bit more usable.

Due to the really dumb way passbolt-cli returns the list of your
credentials, you must create an entry in your Passbolt with any string of
exactly 200 characters in the name, username, and URL field 🤦‍♀️

Usage: ./passbolt.sh [options] [search] [index]

Options:
    -c, --copy          Copy username and password to the system clipboard.
    -d, --description   Print the description to the console.
    -h, --help          This help text.
    -p, --password      Print the password to the console.
        --verbose       Show verbose debug information. Printed to STDERR.

search: Search for something in Passbolt. Optional, script will ask you
        if not set.
index:  If your search returns more than one result, and index is not
        set, you will be presented a list to choose an entry from.
        Set index to pre-select the result from the list.

Settings. Export environment variable with the value \"true\"
(including quotes) to enable the option. When one of these is set, they negate
the related option if set.
    - PASSBOLT_CLI_HELPER_COPY:         Automatically copy the username and
                                        password to system clipboard.
    - PASSBOLT_CLI_HELPER_SHOW_DESC:    Print the description by default.
    - PASSBOLT_CLI_HELPER_SHOW_PW:      Print the password by default.

$ pb notfound
No entries found for notfound

$ pb 'demo entry'

Details for entry   Demo Entry
Username:           twilight
Password:           <hidden>
URL:                https://example.com
Last modified:      2023-07-25T14:43:17+00:00
Passbolt link:      https://passbolt.example.com/app/passwords/view/e6e04cba-9ba2-4965-8425-cce7b7003a0f
Description:        <hidden>

$ pb --password demo
1: Demo Entry, twilight (https://example.com)
2: Demo Entry 2, user2
3: Demo Entry 3, user3
Choose entry number: 1

Details for entry   Demo Entry
Username:           twilight
Password:           ThisIsASecret
URL:                https://example.com
Last modified:      2023-07-25T14:43:17+00:00
Passbolt link:      https://passbolt.example.com/app/passwords/view/e6e04cba-9ba2-4965-8425-cce7b7003a0f
Description:        <hidden>

$ pb --password --description --copy demo 1

Details for entry   Demo Entry
Username:           twilight
Password:           ThisIsASecret
URL:                https://example.com
Last modified:      2023-07-25T14:43:17+00:00
Passbolt link:      https://passbolt.example.com/app/passwords/view/e6e04cba-9ba2-4965-8425-cce7b7003a0f
Description:
And, this is a description

The username has been copied to your clipboard. Press enter to copy the password
```
