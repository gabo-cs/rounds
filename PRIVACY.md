# Privacy Policy for Rounds

**Last updated: 27 August 2026**

Rounds is a personal recurring-bill tracker for Android and iOS. It was built to
work entirely on your own device, and this policy describes what that means in
practice. It applies to every version of the app, on every platform.

## The short version

**Rounds does not collect, transmit, or share any personal data.** There are no
accounts, no servers, no analytics, no advertising, and no tracking of any kind.
The app has no network access and cannot send your information anywhere.

## What Rounds stores, and where

Everything you enter is written to a database file inside the app's private
storage on your device, and to your device's local app-preferences storage.
Neither is readable by other apps, and neither is copied off the device.

Rounds stores:

- **Bills you create** — name, optional amount, day of the month it is due,
  optional category, optional notes, and whether the bill is archived.
- **Payment records** — for each bill and month, whether it is paid, the date
  you marked it paid, and optionally the payment method, the amount paid, and a
  reference note you type.
- **App preferences** — your theme choice, your language choice, whether
  reminders are switched on, and whether you have completed the intro.

Rounds does not read your contacts, location, photos, call logs, messages,
accounts, or any other app's data. It does not have permission to do so.

## Permissions, and why they exist

- **Notifications** — to show bill reminders. If you decline, the app still
  works; you simply get no reminders.
- **Alarms & reminders (Android only)** — so reminders arrive at the intended
  time of day rather than whenever the system next decides to run. If you
  decline, reminders still arrive, just less precisely.
- **Run at startup (Android only)** — so reminders you have already scheduled
  survive a device restart. Rounds does not run in the background otherwise, and
  does no periodic work.

Reminders are prepared by the app and handed to your device's own notification
system, which displays them locally. No reminder passes through any server.

## When information leaves your device

Only when you choose to send it:

- **Backup export.** Tapping Export in Settings writes your bills and payment
  records to a JSON file and opens your device's share sheet. Where that file
  goes — email, a messaging app, cloud storage, your own files — is entirely
  your choice, and from that point it is governed by whichever app or service
  you picked, not by Rounds.
- **Backup import.** Choosing a backup file to restore reads that file from
  your device. Nothing is uploaded.
- **The project link.** The FAQ contains a link to the app's public source-code
  repository. Opening it hands off to your browser, which is subject to its own
  privacy policy, not this one.

Note that if your device is set to back itself up to iCloud, Google One, or a
similar service, that system backup may include Rounds' data along with every
other app's. That is your device's backup, run by your operating system under
its own privacy policy — Rounds neither triggers it nor has access to it.

## Deleting your data

Deleting a bill in the app removes it and its payment history. Uninstalling
Rounds removes the entire database and all preferences from your device.
Because nothing is stored anywhere else, there is nothing for us to delete on
your behalf, and no way for us to recover it — keep your own export if you want
a copy.

## Children

Rounds is a general-purpose utility, is not directed at children, and collects
no data from anyone, including children.

## Changes to this policy

If this policy changes, the updated version will be published at this same
address with a new "last updated" date. Because Rounds collects nothing, changes
are expected to be rare.

## Contact

Questions about this policy: <CONTACT EMAIL — fill in before publishing>

Source code: https://github.com/gabo-cs/rounds
