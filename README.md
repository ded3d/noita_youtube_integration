
# Noita YouTube Integration mod `v0.1.2`

Thanks to [dextercd](https://github.com/dextercd) for making this mod possible.

Please note that the mod is currently on active development stage.

## Installation

1. If you already have a Google Projects API key with access to YouTube Data API v3, just paste it to `key.txt` file and jump to step 4. But if you don't, go to [Google Cloud Developer Console](https://console.cloud.google.com/cloud-resource-manager). There you need to create a new project with any preferred name.
2. Then go to [YouTube Data API v3 page](https://console.cloud.google.com/apis/library/youtube.googleapis.com) and enable it for your new project.
3. Go to [Credentials page](https://console.cloud.google.com/apis/credentials) and create a new API key (`CREATE CREDENTIALS` $\to$ `API key`), save the shown value.
4. Download the [dextercd/Noita-Dear-ImGui](https://github.com/dextercd/Noita-Dear-ImGui/releases/latest) and unpack it to `$NOITA_GAME/mods/`.
5. Download the [latest mod release](https://github.com/ded3d/noita_youtube_integration/releases/latest) and unpack it to the `mods` directory.
6. Paste the API key to `key.txt` file if you didn't.
7. The mod is now ready to work!

## Build

### Windows

1. Get the [Rust](https://forge.rust-lang.org/infra/other-installation-methods.html#standalone-installers) and [MSVC](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170#latest-microsoft-visual-c-redistributable-version).
2. Get the mod [source code](https://github.com/ded3d/noita_youtube_integration/archive/refs/heads/master.zip).
3. Run the following Powershell script:
```powershell
Get-ChildItem -Recurse -File -Include *.lua,*.toml | ForEach-Object { (Get-Content $_.FullName) | ForEach-Object { $_ -replace "`{VERSION`}", "0.1.2" } | Set-Content $_.FullName }
rustup target add i686-pc-windows-msvc
cargo build --release --target i686-pc-windows-msvc
Copy-Item -Path .\target\i686-pc-windows-msvc\release\yt_wrapper.dll -Destination .\lib\
```

### Linux

1. Get the latest `rust` and `mingw-w64`.
2. Get the mod [source code](https://github.com/ded3d/noita_youtube_integration/archive/refs/heads/master.zip).
3. Run the following script:
```sh
find . -type f \( -name "*.lua" -o -name "*.toml" \) -exec sed -i 's/{VERSION}/0.1.2/g' {} +
rustup target add i686-pc-windows-gnu
cargo build --release --target i686-pc-windows-gnu
cp ./target/i686-pc-windows-gnu/release/yt_wrapper.dll ./lib/
```
