/// Misure reali di oggetti e documenti noti, in millimetri (larghezza x altezza
/// con l'oggetto in posizione normale di lettura: orizzontale per le carte,
/// verticale per le foto e i fogli).
///
/// Serve a portare una foto o una scansione a grandezza naturale: se si sa che
/// l'immagine ritaglia una carta d'identità, la larghezza in millimetri decide
/// a quanti punti per pollice (dpi) va messa nel PDF.
library;

/// Famiglia di una misura standard, per raggruppare l'elenco nell'app.
enum StandardSizeGroup {
  cards('Carte e documenti'),
  idPhotos('Foto tessera e documenti'),
  photoPrints('Foto stampate'),
  paperIso('Fogli ISO (A, B, C)'),
  paperNorthAmerica('Fogli USA e Canada'),
  paperOther('Altri fogli'),
  banknotes('Banconote euro'),
  coins('Monete euro'),
  simAndMemory('SIM e schede di memoria'),
  other('Altro');

  const StandardSizeGroup(this.label);
  final String label;
}

/// Una misura nota.
class StandardSize {
  const StandardSize(
    this.id,
    this.name,
    this.group,
    this.widthMm,
    this.heightMm, {
    this.note,
  });

  /// Identificativo stabile (non cambia se cambia il nome).
  final String id;
  final String name;
  final StandardSizeGroup group;
  final double widthMm;
  final double heightMm;

  /// Dettaglio utile (norma, a cosa si applica).
  final String? note;

  double get widthPt => mmToPoints(widthMm);
  double get heightPt => mmToPoints(heightMm);

  /// Punti per pollice con cui un'immagine larga [pixelWidth] pixel risulta
  /// larga esattamente [widthMm] millimetri.
  double dpiForPixelWidth(int pixelWidth) => pixelWidth * 25.4 / widthMm;

  /// Come sopra, partendo dall'altezza.
  double dpiForPixelHeight(int pixelHeight) => pixelHeight * 25.4 / heightMm;

  /// La stessa misura ruotata (orizzontale <-> verticale).
  StandardSize get rotated =>
      StandardSize(id, name, group, heightMm, widthMm, note: note);

  @override
  String toString() => '$name (${_fmt(widthMm)} x ${_fmt(heightMm)} mm)';
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Da millimetri a punti PDF (1 pt = 1/72 di pollice).
double mmToPoints(double mm) => mm * 72 / 25.4;

/// Da punti PDF a millimetri.
double pointsToMm(double pt) => pt * 25.4 / 72;

const _cards = StandardSizeGroup.cards;
const _idPhotos = StandardSizeGroup.idPhotos;
const _prints = StandardSizeGroup.photoPrints;
const _iso = StandardSizeGroup.paperIso;
const _us = StandardSizeGroup.paperNorthAmerica;
const _paperOther = StandardSizeGroup.paperOther;
const _bank = StandardSizeGroup.banknotes;
const _coin = StandardSizeGroup.coins;
const _sim = StandardSizeGroup.simAndMemory;
const _other = StandardSizeGroup.other;

/// Tutte le misure note. L'ordine e' quello dell'elenco nell'app.
const List<StandardSize> kStandardSizes = [
  // --- carte e documenti (ISO/IEC 7810) -------------------------------------
  StandardSize('card_id1', 'Carta di credito / bancomat', _cards, 85.60, 53.98,
      note: 'ISO/IEC 7810 ID-1'),
  StandardSize('card_cie', "Carta d'identita' elettronica (CIE)", _cards, 85.60,
      53.98,
      note: 'formato ID-1, come una carta di credito'),
  StandardSize('card_license', 'Patente di guida (carta)', _cards, 85.60, 53.98,
      note: 'formato ID-1'),
  StandardSize('card_health', 'Tessera sanitaria / codice fiscale', _cards,
      85.60, 53.98,
      note: 'formato ID-1'),
  StandardSize('card_permit', 'Permesso di soggiorno (carta)', _cards, 85.60,
      53.98,
      note: 'formato ID-1'),
  StandardSize('card_id2', 'Documento formato ID-2', _cards, 105, 74,
      note: 'ISO/IEC 7810 ID-2, come un A7'),
  StandardSize('passport_id3', 'Passaporto (pagina dati, chiuso)', _cards, 125,
      88,
      note: 'ISO/IEC 7810 ID-3'),
  StandardSize('card_id000', 'Carta formato ID-000 (SIM grande)', _cards, 25,
      15,
      note: 'ISO/IEC 7810 ID-000'),
  StandardSize('card_business_eu', 'Biglietto da visita (Europa)', _cards, 85,
      55),
  StandardSize('card_business_it', 'Biglietto da visita (Italia, comune)',
      _cards, 90, 50),
  StandardSize('card_business_us', 'Biglietto da visita (USA)', _cards, 88.9,
      50.8,
      note: '3,5 x 2 pollici'),

  // --- foto tessera e documenti --------------------------------------------
  StandardSize('photo_id_it', 'Foto tessera (Italia, Europa)', _idPhotos, 35,
      45,
      note: 'carta di identita, passaporto, patente'),
  StandardSize('photo_id_us', 'Foto passaporto (USA)', _idPhotos, 50.8, 50.8,
      note: '2 x 2 pollici'),
  StandardSize('photo_id_uk', 'Foto passaporto (Regno Unito)', _idPhotos, 35,
      45),
  StandardSize('photo_id_cn', 'Foto passaporto (Cina)', _idPhotos, 33, 48),
  StandardSize('photo_id_jp', 'Foto passaporto (Giappone)', _idPhotos, 35, 45),
  StandardSize('photo_id_in', 'Foto passaporto (India)', _idPhotos, 51, 51,
      note: '2 x 2 pollici'),
  StandardSize('photo_id_ca', 'Foto passaporto (Canada)', _idPhotos, 50, 70),
  StandardSize('photo_id_small', 'Foto tessera piccola (abbonamenti)',
      _idPhotos, 25, 30),
  StandardSize('photo_id_visa_schengen', 'Foto visto Schengen', _idPhotos, 35,
      45),

  // --- foto stampate (centimetri comuni, larghezza x altezza verticali) ----
  StandardSize('print_9x13', 'Foto 9 x 13 cm', _prints, 89, 127,
      note: '3,5 x 5 pollici'),
  StandardSize('print_10x15', 'Foto 10 x 15 cm', _prints, 102, 152,
      note: '4 x 6 pollici'),
  StandardSize('print_13x18', 'Foto 13 x 18 cm', _prints, 127, 178,
      note: '5 x 7 pollici'),
  StandardSize('print_15x20', 'Foto 15 x 20 cm', _prints, 152, 203,
      note: '6 x 8 pollici'),
  StandardSize('print_20x25', 'Foto 20 x 25 cm', _prints, 203, 254,
      note: '8 x 10 pollici'),
  StandardSize('print_20x30', 'Foto 20 x 30 cm', _prints, 203, 305,
      note: '8 x 12 pollici'),
  StandardSize('print_30x40', 'Foto 30 x 40 cm', _prints, 305, 406,
      note: '12 x 16 pollici'),
  StandardSize('print_polaroid', 'Polaroid classica (foto)', _prints, 79, 79),
  StandardSize('print_instax_mini', 'Instax Mini (foto)', _prints, 46, 62),
  StandardSize('print_instax_wide', 'Instax Wide (foto)', _prints, 99, 62),

  // --- fogli ISO 216 ---------------------------------------------------------
  StandardSize('a0', 'A0', _iso, 841, 1189),
  StandardSize('a1', 'A1', _iso, 594, 841),
  StandardSize('a2', 'A2', _iso, 420, 594),
  StandardSize('a3', 'A3', _iso, 297, 420),
  StandardSize('a4', 'A4', _iso, 210, 297),
  StandardSize('a5', 'A5', _iso, 148, 210),
  StandardSize('a6', 'A6 (cartolina)', _iso, 105, 148),
  StandardSize('a7', 'A7', _iso, 74, 105),
  StandardSize('a8', 'A8', _iso, 52, 74),
  StandardSize('b3', 'B3', _iso, 353, 500),
  StandardSize('b4', 'B4', _iso, 250, 353),
  StandardSize('b5', 'B5', _iso, 176, 250),
  StandardSize('b6', 'B6', _iso, 125, 176),
  StandardSize('c4', 'Busta C4', _iso, 229, 324),
  StandardSize('c5', 'Busta C5', _iso, 162, 229),
  StandardSize('c6', 'Busta C6', _iso, 114, 162),
  StandardSize('dl', 'Busta DL (lettera)', _iso, 110, 220),

  // --- fogli USA e Canada -----------------------------------------------------
  StandardSize('letter', 'Letter', _us, 215.9, 279.4, note: '8,5 x 11 pollici'),
  StandardSize('legal', 'Legal', _us, 215.9, 355.6, note: '8,5 x 14 pollici'),
  StandardSize('tabloid', 'Tabloid / Ledger', _us, 279.4, 431.8,
      note: '11 x 17 pollici'),
  StandardSize('executive', 'Executive', _us, 184.15, 266.7,
      note: '7,25 x 10,5 pollici'),
  StandardSize('statement', 'Statement / Half Letter', _us, 139.7, 215.9,
      note: '5,5 x 8,5 pollici'),

  // --- altri fogli ---------------------------------------------------------------
  StandardSize('folio_it', 'Protocollo (uso bollo)', _paperOther, 210, 330),
  StandardSize('receipt_80', 'Scontrino termico 80 mm (larghezza)',
      _paperOther, 80, 200,
      note: 'altezza indicativa, il rotolo e continuo'),
  StandardSize('receipt_58', 'Scontrino termico 58 mm (larghezza)',
      _paperOther, 58, 200,
      note: 'altezza indicativa, il rotolo e continuo'),

  // --- banconote euro (serie Europa) ------------------------------------------
  StandardSize('eur_5', 'Banconota 5 euro', _bank, 120, 62),
  StandardSize('eur_10', 'Banconota 10 euro', _bank, 127, 67),
  StandardSize('eur_20', 'Banconota 20 euro', _bank, 133, 72),
  StandardSize('eur_50', 'Banconota 50 euro', _bank, 140, 77),
  StandardSize('eur_100', 'Banconota 100 euro', _bank, 147, 82),
  StandardSize('eur_200', 'Banconota 200 euro', _bank, 153, 82),

  // --- monete euro (diametro) ----------------------------------------------------
  StandardSize('coin_1c', 'Moneta 1 centesimo', _coin, 16.25, 16.25),
  StandardSize('coin_2c', 'Moneta 2 centesimi', _coin, 18.75, 18.75),
  StandardSize('coin_5c', 'Moneta 5 centesimi', _coin, 21.25, 21.25),
  StandardSize('coin_10c', 'Moneta 10 centesimi', _coin, 19.75, 19.75),
  StandardSize('coin_20c', 'Moneta 20 centesimi', _coin, 22.25, 22.25),
  StandardSize('coin_50c', 'Moneta 50 centesimi', _coin, 24.25, 24.25),
  StandardSize('coin_1e', 'Moneta 1 euro', _coin, 23.25, 23.25),
  StandardSize('coin_2e', 'Moneta 2 euro', _coin, 25.75, 25.75),

  // --- SIM e schede di memoria ---------------------------------------------------
  StandardSize('sim_mini', 'SIM mini (2FF)', _sim, 25, 15),
  StandardSize('sim_micro', 'SIM micro (3FF)', _sim, 15, 12),
  StandardSize('sim_nano', 'SIM nano (4FF)', _sim, 12.3, 8.8),
  StandardSize('sd', 'Scheda SD', _sim, 32, 24),
  StandardSize('microsd', 'Scheda microSD', _sim, 15, 11),

  // --- altro ----------------------------------------------------------------------
  StandardSize('stamp_postcard', 'Cartolina postale', _other, 148, 105),
  StandardSize('cd', 'CD / DVD (diametro)', _other, 120, 120),
  StandardSize('bookmark', 'Segnalibro comune', _other, 50, 150),
];

/// La misura con questo [id], o null.
StandardSize? standardSizeById(String id) {
  for (final size in kStandardSizes) {
    if (size.id == id) return size;
  }
  return null;
}

/// Le misure di un gruppo, nell'ordine dell'elenco.
List<StandardSize> standardSizesIn(StandardSizeGroup group) =>
    [for (final size in kStandardSizes) if (size.group == group) size];
