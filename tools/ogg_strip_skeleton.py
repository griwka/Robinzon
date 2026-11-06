"""Убрать из Ogg-файла служебную дорожку Skeleton (fishead/fisbone): оставить только звук."""
import struct, sys
for path in sys.argv[1:]:
    b = open(path, "rb").read()
    out = bytearray(); skel = set(); i = 0
    while i < len(b):
        assert b[i:i + 4] == b"OggS", path
        nseg = b[i + 26]
        segs = b[i + 27:i + 27 + nseg]
        size = 27 + nseg + sum(segs)
        serial = struct.unpack("<I", b[i + 14:i + 18])[0]
        body = b[i + 27 + nseg:i + size]
        if body[:8] in (b"fishead\0", b"fisbone\0") or serial in skel:
            skel.add(serial)
        else:
            out += b[i:i + size]
        i += size
    if skel:
        open(path, "wb").write(out)
        print("stripped", path.rsplit("\\", 1)[-1].rsplit("/", 1)[-1])
