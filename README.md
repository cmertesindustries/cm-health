# CM Health

Custom build of [OpenStrap Edge](https://github.com/OpenStrap/edge) (MIT) for the WHOOP 4.0 band — by CMertes Industries.

This repo does not carry the full source. CI clones the upstream source at the commit pinned in `UPSTREAM_REF`, copies `overlay/` on top, applies `patches/*.patch`, then builds and signs the CM Health APK.

Local reproduction:

```bash
git clone https://github.com/OpenStrap/edge.git src
git -C src checkout "$(cat UPSTREAM_REF)"
./apply.sh src
cd src && flutter build apk --release
```
