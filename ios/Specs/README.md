# SQLite Podspec Source

`sqlite3.podspec.json` comes from CocoaPods' official Specs repository for sqlite3 3.50.4:
https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/d/c/2/sqlite3/3.50.4/sqlite3.podspec.json

The pinned podspec avoids CDN resolution traversing all historical versions. Its only content adjustment changes the upstream download host from `www.sqlite.org` to `sqlite.org` because the former was slow in the original environment. SQLite source and compilation settings are unchanged. Podfile.lock retains version and checksum locking.
