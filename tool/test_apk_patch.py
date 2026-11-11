import json
import os
import random
import shutil
import tempfile
import unittest

import apk_patch as ap


def fake_apk(seed, size=3_000_000):
    return random.Random(seed).randbytes(size)


def edit(data, seed):
    r = random.Random(seed)
    b = bytearray(data)
    pos = r.randrange(0, len(b) // 2)
    b[pos:pos + 50_000] = r.randbytes(50_000)          # zona cambiata
    pos = r.randrange(len(b) // 2, len(b) - 10)
    b[pos:pos] = r.randbytes(300)                       # inserimento (sposta il resto)
    del b[len(b) // 3:len(b) // 3 + 200]                # cancellazione
    return bytes(b)


class PatchTest(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.d)

    def p(self, name):
        return os.path.join(self.d, name)

    def write(self, name, data):
        with open(self.p(name), "wb") as f:
            f.write(data)
        return self.p(name)

    def test_roundtrip_and_size(self):
        old = fake_apk(1)
        new = edit(old, 2)
        o = self.write("o", old)
        n = self.write("n", new)
        size = ap.make_patch(o, n, self.p("p"))
        self.assertLess(size, 80_000)
        ap.apply_patch(o, self.p("p"), self.p("r"))
        self.assertEqual(open(self.p("r"), "rb").read(), new)

    def test_identical_and_tiny_files(self):
        for data_old, data_new in [(b"", b""), (b"abc", b"abd"), (fake_apk(3, 500), fake_apk(4, 700)),
                                   (fake_apk(5, 5000), fake_apk(5, 5000))]:
            o = self.write("o", data_old)
            n = self.write("n", data_new)
            ap.make_patch(o, n, self.p("p"))
            ap.apply_patch(o, self.p("p"), self.p("r"))
            self.assertEqual(open(self.p("r"), "rb").read(), data_new)

    def test_wrong_base_is_rejected(self):
        old = fake_apk(1)
        o = self.write("o", old)
        n = self.write("n", edit(old, 2))
        ap.make_patch(o, n, self.p("p"))
        other = self.write("x", fake_apk(9))
        with self.assertRaises(ap.PatchError):
            ap.apply_patch(other, self.p("p"), self.p("r"))

    def test_corrupt_patch_is_rejected(self):
        old = fake_apk(1)
        o = self.write("o", old)
        n = self.write("n", edit(old, 2))
        ap.make_patch(o, n, self.p("p"))
        raw = open(self.p("p"), "rb").read()
        self.write("bad", raw[:len(raw) // 2])
        with self.assertRaises(Exception):
            ap.apply_patch(o, self.p("bad"), self.p("r"))


class PlanTest(unittest.TestCase):
    """Simula la release con una cartella: ogni build chiama plan() e poi 'carica'."""

    def setUp(self):
        self.d = tempfile.mkdtemp()
        self.rel = os.path.join(self.d, "release")
        os.makedirs(self.rel)
        self.apks = {}

    def tearDown(self):
        shutil.rmtree(self.d)

    def download(self, name, dest):
        src = os.path.join(self.rel, name)
        if not os.path.exists(src):
            return None
        out = os.path.join(dest, name)
        shutil.copy(src, out)
        return out

    def publish(self, build, data, slim, force_full=False):
        apk = os.path.join(self.d, "new.apk")
        with open(apk, "wb") as f:
            f.write(data)
        out = os.path.join(self.d, "plan%d" % build)
        dec = ap.plan(apk, build, out, self.download, slim, force_full, log=lambda *_: None)
        if dec["full"]:
            shutil.copy(apk, os.path.join(self.rel, ap.BASE_ASSET))
        for name in os.listdir(out):
            if name.startswith("patch-") or name == ap.MANIFEST:
                shutil.copy(os.path.join(out, name), os.path.join(self.rel, name))
        for name in dec["delete"]:
            os.remove(os.path.join(self.rel, name))
        self.apks[build] = data
        with open(os.path.join(self.rel, ap.MANIFEST)) as f:
            return dec, json.load(f)

    def test_slim_chain_reconstructs(self):
        data = fake_apk(1)
        dec, m = self.publish(1, data, slim=True)
        self.assertTrue(dec["full"])
        for build in range(2, 6):
            data = edit(data, build)
            dec, m = self.publish(build, data, slim=True)
            self.assertFalse(dec["full"], dec)
        self.assertEqual(m["base"]["build"], 1)
        self.assertEqual(len(m["patches"]), 4)
        # la release ha ancora l'APK della base (build 1), non quello nuovo
        self.assertEqual(ap.sha256_file(os.path.join(self.rel, ap.BASE_ASSET)),
                         m["base"]["sha256"])
        rebuilt = ap._reconstruct(m, self.download, self.d)
        self.assertEqual(open(rebuilt, "rb").read(), data)

    def test_non_slim_always_full_but_adds_patches(self):
        data = fake_apk(1)
        self.publish(1, data, slim=False)
        data = edit(data, 2)
        dec, m = self.publish(2, data, slim=False)
        self.assertTrue(dec["full"])
        self.assertEqual(m["base"]["build"], 2)
        self.assertEqual([(e["from"], e["to"]) for e in m["patches"]], [(1, 2)])

    def test_force_full_resets_chain(self):
        data = fake_apk(1)
        self.publish(1, data, slim=True)
        data = edit(data, 2)
        self.publish(2, data, slim=True)
        data = edit(data, 3)
        dec, m = self.publish(3, data, slim=True, force_full=True)
        self.assertTrue(dec["full"])
        self.assertEqual(m["base"]["build"], 3)
        self.assertEqual(m["patches"], [])
        self.assertFalse([n for n in os.listdir(self.rel) if n.startswith("patch-")])

    def test_huge_change_is_full(self):
        self.publish(1, fake_apk(1), slim=True)
        dec, m = self.publish(2, fake_apk(2), slim=True)
        self.assertTrue(dec["full"])
        self.assertEqual(m["base"]["build"], 2)

    def test_long_chain_becomes_full(self):
        data = fake_apk(1, 200_000)
        self.publish(1, data, slim=True)
        fulls = []
        for build in range(2, ap.MAX_EDGES + 3):
            data = data[:1000] + bytes([build % 256]) * 10 + data[1010:]
            dec, m = self.publish(build, data, slim=True)
            fulls.append(dec["full"])
        self.assertTrue(any(fulls))
        self.assertLessEqual(len(m["patches"]), ap.MAX_EDGES)


if __name__ == "__main__":
    unittest.main()
