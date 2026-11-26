import os
import tempfile
import unittest

import storico_build as s


class StoricoBuild(unittest.TestCase):
    def test_la_build_nuova_va_in_cima(self):
        vecchio = [{"build": 310, "version": "a#310", "changes": ["x"]}]
        nuovo = s.aggiorna(vecchio, 311, "a#311", ["y"])
        self.assertEqual([b["build"] for b in nuovo], [311, 310])

    def test_una_build_gia_presente_si_sostituisce(self):
        vecchio = [{"build": 311, "version": "a#311", "changes": ["x"]}]
        nuovo = s.aggiorna(vecchio, 311, "a#311", ["y"])
        self.assertEqual(len(nuovo), 1)
        self.assertEqual(nuovo[0]["changes"], ["y"])

    def test_si_tengono_solo_le_ultime(self):
        vecchio = [{"build": n, "version": "v", "changes": []} for n in range(1, 40)]
        nuovo = s.aggiorna(vecchio, 40, "v", [], massimo=5)
        self.assertEqual([b["build"] for b in nuovo], [40, 39, 38, 37, 36])

    def test_file_mancante_o_rotto_da_lista_vuota(self):
        self.assertEqual(s.carica("/non/esiste.json"), [])
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            f.write("{non json")
        try:
            self.assertEqual(s.carica(f.name), [])
        finally:
            os.unlink(f.name)

    def test_le_modifiche_perdono_il_trattino(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.write("- uno\n\ndue\n  - tre\n")
        try:
            self.assertEqual(s.leggi_modifiche(f.name), ["uno", "due", "tre"])
        finally:
            os.unlink(f.name)


if __name__ == "__main__":
    unittest.main()
