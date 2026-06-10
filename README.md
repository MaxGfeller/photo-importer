# CardImporter

A small macOS SwiftUI importer for SD cards and camera folders.

![CardImporter showing selected photos during import](docs/screenshot.png)

## What It Does

- Lists mounted volumes and lets you choose a source folder manually.
- Lets you choose any destination folder or external drive.
- Scans photos, raw files, and videos into a selectable preview grid.
- Generates thumbnails with Quick Look.
- Copies selected media directly into the chosen destination folder.
- Verifies each copied file with SHA-256 before recording it as imported.
- Stores a SQLite import ledger in the destination at `.card-importer/imports.sqlite`.
- Can index existing destination media so previous manual copies are recognized later.

## Run

```bash
./script/build_and_run.sh
```

Optional modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```
