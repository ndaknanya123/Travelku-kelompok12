-- ============================================================
-- SCHEMA: db_travel_reservasi  (TravelKu Final)
-- ============================================================

CREATE DATABASE IF NOT EXISTS db_travel_reservasi
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_travel_reservasi;

-- ------------------------------------------------------------
-- USERS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  nama          VARCHAR(120)  NOT NULL,
  email         VARCHAR(120)  NOT NULL UNIQUE,
  password_hash VARCHAR(255)  NOT NULL,
  role          ENUM('pelanggan','admin') NOT NULL DEFAULT 'pelanggan',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- DESTINASI
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS destinasi (
  id        INT AUTO_INCREMENT PRIMARY KEY,
  nama      VARCHAR(120) NOT NULL,
  negara    VARCHAR(80)  NOT NULL,
  kota      VARCHAR(80)  NOT NULL,
  kategori  ENUM('lokal','internasional') NOT NULL,
  wilayah   VARCHAR(80)  DEFAULT NULL,
  deskripsi TEXT,
  aktif     TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- LAYANAN
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS layanan (
  id                 INT AUTO_INCREMENT PRIMARY KEY,
  tipe               ENUM('pesawat','kapal','bus','mobil','hotel','paket_wisata') NOT NULL,
  nama               VARCHAR(160) NOT NULL,
  maskapai           VARCHAR(80)  DEFAULT NULL,
  kelas              ENUM('ekonomi','bisnis','first') DEFAULT 'ekonomi',
  dari_destinasi_id  INT NOT NULL,
  ke_destinasi_id    INT NOT NULL,
  harga_dasar        DECIMAL(15,2) NOT NULL,
  kapasitas          INT NOT NULL DEFAULT 1,
  deskripsi          TEXT,
  fasilitas          TEXT,
  aktif              TINYINT(1) NOT NULL DEFAULT 1,
  FOREIGN KEY (dari_destinasi_id) REFERENCES destinasi(id),
  FOREIGN KEY (ke_destinasi_id)   REFERENCES destinasi(id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- JADWAL
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jadwal (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  layanan_id      INT NOT NULL,
  tanggal         DATE NOT NULL,
  harga_override  DECIMAL(15,2) DEFAULT NULL,
  kapasitas_sisa  INT NOT NULL,
  status          ENUM('tersedia','penuh','diblokir') NOT NULL DEFAULT 'tersedia',
  blokir_oleh     INT DEFAULT NULL,
  blokir_alasan   VARCHAR(255) DEFAULT NULL,
  UNIQUE KEY uq_layanan_tanggal (layanan_id, tanggal),
  FOREIGN KEY (layanan_id)  REFERENCES layanan(id),
  FOREIGN KEY (blokir_oleh) REFERENCES users(id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- RESERVASI
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reservasi (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  kode_booking  VARCHAR(20)   NOT NULL UNIQUE,
  user_id       INT NOT NULL,
  jadwal_id     INT NOT NULL,
  jumlah_tiket  INT NOT NULL DEFAULT 1,
  total_harga   DECIMAL(15,2) NOT NULL,
  status        ENUM('pending','dikonfirmasi','dibatalkan','selesai') NOT NULL DEFAULT 'pending',
  nama_pemesan  VARCHAR(120) NOT NULL,
  email_pemesan VARCHAR(120) NOT NULL,
  telepon       VARCHAR(20)  DEFAULT NULL,
  catatan       TEXT         DEFAULT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id)   REFERENCES users(id),
  FOREIGN KEY (jadwal_id) REFERENCES jadwal(id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- PEMBAYARAN
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pembayaran (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  reservasi_id INT NOT NULL,
  metode       ENUM('transfer','kartu_kredit','ewallet','tunai') NOT NULL,
  jumlah       DECIMAL(15,2) NOT NULL,
  status       ENUM('menunggu','lunas','gagal','refund') NOT NULL DEFAULT 'menunggu',
  bukti_url    VARCHAR(255) DEFAULT NULL,
  dibayar_pada DATETIME DEFAULT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reservasi_id) REFERENCES reservasi(id)
) ENGINE=InnoDB;

-- ============================================================
-- SEED DATA
-- ============================================================

-- Admin: password = admin123
-- hash = SHA256("admin123" + "travelku_prod_secret_2026")
INSERT INTO users (nama, email, password_hash, role) VALUES
('Super Admin','admin@travelku.id',
 '2ce00a898a38900cfb964e45c9ce5918bd860c56e96b605f50cb48f108aa603e',
 'admin');

-- ---- DESTINASI LOKAL ----
INSERT INTO destinasi (nama,negara,kota,kategori,wilayah,deskripsi) VALUES
('Kuta Beach',       'Indonesia','Denpasar',       'lokal','Bali',       'Pantai ikonik di jantung Bali dengan sunset spektakuler dan kehidupan malam yang ramai.'),
('Ubud',             'Indonesia','Gianyar',        'lokal','Bali',       'Pusat budaya Bali — sawah terasering, pura kuno, dan seni tradisional.'),
('Nusa Penida',      'Indonesia','Klungkung',      'lokal','Bali',       'Pulau magis dengan tebing dramatis, Kelingking Beach, dan snorkeling kelas dunia.'),
('Seminyak',         'Indonesia','Badung',         'lokal','Bali',       'Kawasan resort premium Bali dengan pantai bersih, villa mewah, dan restoran fine-dining.'),
('Uluwatu',          'Indonesia','Badung',         'lokal','Bali',       'Pura tebing legendaris di ujung selatan Bali dengan ombak surfing terbaik.'),
('Jakarta',          'Indonesia','Jakarta',        'lokal','Jawa',       'Ibukota Indonesia — Kota Tua, kuliner legendaris, dan museum bersejarah.'),
('Yogyakarta',       'Indonesia','Yogyakarta',     'lokal','Jawa',       'Kota budaya Jawa: Borobudur, Prambanan, Keraton, dan kuliner gudeg.'),
('Bromo-Tengger',    'Indonesia','Probolinggo',    'lokal','Jawa',       'Lautan pasir dan kawah aktif Gunung Bromo yang memukau saat fajar.'),
('Raja Ampat',       'Indonesia','Sorong',         'lokal','Papua',      'Surga bawah laut terbaik di dunia — 1.500 spesies ikan dan terumbu karang.'),
('Labuan Bajo',      'Indonesia','Manggarai Barat','lokal','NTT',        'Gerbang Taman Nasional Komodo dan sunset terbaik di Indonesia Timur.'),
('Komodo Island',    'Indonesia','Manggarai Barat','lokal','NTT',        'Habitat asli komodo dan pantai pink legendaris.'),
('Makassar',         'Indonesia','Makassar',       'lokal','Sulawesi',   'Fort Rotterdam, Pantai Losari, dan coto makassar.'),
('Tana Toraja',      'Indonesia','Tana Toraja',    'lokal','Sulawesi',   'Budaya pemakaman unik, rumah tongkonan, dan lanskap pegunungan hijau.'),
('Banjarmasin',      'Indonesia','Banjarmasin',    'lokal','Kalimantan', 'Kota seribu sungai — pasar terapung dan wisata Martapura.'),
('Derawan Islands',  'Indonesia','Berau',          'lokal','Kalimantan', 'Kepulauan tropis dengan penyu hijau dan diving spektakuler.'),
('Lampung',          'Indonesia','Lampung',        'lokal','Sumatera',   'Anak Krakatau aktif, Taman Nasional Way Kambas, dan gajah Sumatera.'),
('Danau Toba',       'Indonesia','Samosir',        'lokal','Sumatera',   'Danau vulkanik terbesar di dunia dengan budaya Batak dan Pulau Samosir.'),
-- ---- DESTINASI INTERNASIONAL ----
-- Israel (detail)
('Jerusalem Old City',  'Israel','Jerusalem','internasional','Timur Tengah','Kota suci tiga agama — Masjid Al-Aqsa, Gereja Makam Kudus, dan Tembok Ratapan.'),
('Tel Aviv',            'Israel','Tel Aviv', 'internasional','Timur Tengah','Kota pantai modern Israel dengan nightlife, kuliner, dan arsitektur Bauhaus UNESCO.'),
('Dead Sea',            'Israel','Laut Mati','internasional','Timur Tengah','Titik terendah di bumi — mengapung di air asin alami dan mandi lumpur mineral.'),
('Masada Fortress',     'Israel','Negev',    'internasional','Timur Tengah','Benteng Herodian dramatis di tebing gurun dengan pemandangan Laut Mati.'),
('Nazareth',            'Israel','Galilee',  'internasional','Timur Tengah','Kota kelahiran Yesus — Basilica of the Annunciation dan pasar Arab tradisional.'),
('Haifa',               'Israel','Haifa',    'internasional','Timur Tengah','Taman Bahai bertingkat yang indah menghadap Laut Mediterania.'),
-- Jepang
('Tokyo',   'Jepang','Tokyo', 'internasional','Asia Timur','Metropolis futuristik: Shibuya, Akihabara, Senso-ji, dan kuliner world-class.'),
('Kyoto',   'Jepang','Kyoto', 'internasional','Asia Timur','Ibu kota budaya Jepang — 1.600 kuil Budha, geisha, dan sakura.'),
('Osaka',   'Jepang','Osaka', 'internasional','Asia Timur','Surga kuliner Jepang: takoyaki, ramen, Dotonbori, dan Osaka Castle.'),
-- Korea
('Seoul',       'Korea Selatan','Seoul','internasional','Asia Timur','K-pop, Gyeongbokgung Palace, Myeongdong, dan street food.'),
('Jeju Island', 'Korea Selatan','Jeju', 'internasional','Asia Timur','Pulau vulkanik Korea — Hallasan dan pantai eksotis.'),
-- Turki
('Istanbul',   'Turki','Istanbul','internasional','Eropa-Asia','Hagia Sophia, Grand Bazaar, Bosphorus cruise, dan kebab legendaris.'),
('Cappadocia', 'Turki','Nevsehir','internasional','Eropa-Asia','Balon udara panas ikonik dan formasi batu fairy chimney.'),
('Antalya',    'Turki','Antalya', 'internasional','Eropa-Asia','Riviera Turki: pantai Mediterania dan reruntuhan Romawi.'),
-- Malaysia
('Kuala Lumpur','Malaysia','KL',    'internasional','Asia Tenggara','Petronas Twin Towers, Batu Caves, dan kuliner multikultural.'),
('Langkawi',    'Malaysia','Kedah', 'internasional','Asia Tenggara','Kepulauan bebas pajak: pantai tropis dan cable car spektakuler.'),
-- Lainnya
('Dubai',    'UAE',      'Dubai', 'internasional','Timur Tengah','Burj Khalifa, Desert Safari, dan luxury experience.'),
('Paris',    'Prancis',  'Paris', 'internasional','Eropa',       'Menara Eiffel, Louvre, Seine River cruise, dan haute cuisine.'),
('Maldives', 'Maldives', 'Male',  'internasional','Asia Selatan','Bungalow di atas air, laguna turquoise, dan diving spektakuler.');

-- ---- LAYANAN ----
INSERT INTO layanan (tipe,nama,maskapai,kelas,dari_destinasi_id,ke_destinasi_id,harga_dasar,kapasitas,deskripsi,fasilitas) VALUES
-- Pesawat lokal
('pesawat','Jakarta → Bali (Garuda Ekonomi)',   'Garuda Indonesia','ekonomi',6,1, 1250000,180,'Penerbangan langsung 1j45m',             '["Bagasi 20kg","Makanan","Hiburan"]'),
('pesawat','Jakarta → Bali (Lion Air)',          'Lion Air',        'ekonomi',6,1,  650000,189,'Penerbangan hemat Jakarta-Bali',         '["Bagasi 10kg"]'),
('pesawat','Jakarta → Bali (Garuda Bisnis)',     'Garuda Indonesia','bisnis', 6,1, 3200000, 36,'Bisnis class full service',              '["Bagasi 30kg","Makanan Premium","Lounge"]'),
('pesawat','Jakarta → Raja Ampat (Batik Air)',   'Batik Air',       'bisnis', 6,9, 4200000, 72,'Via Sorong',                             '["Bagasi 30kg","Makanan Premium","Lounge"]'),
('pesawat','Jakarta → Labuan Bajo (Garuda)',     'Garuda Indonesia','ekonomi',6,10,1800000,160,'Via Kupang atau langsung',               '["Bagasi 20kg","Makanan"]'),
('pesawat','Jakarta → Yogyakarta (Garuda)',      'Garuda Indonesia','ekonomi',6,7,  750000,180,'1 jam langsung',                        '["Bagasi 20kg","Makanan"]'),
('pesawat','Jakarta → Makassar (Lion Air)',      'Lion Air',        'ekonomi',6,12, 850000,189,'2 jam langsung',                        '["Bagasi 10kg"]'),
-- Pesawat internasional
('pesawat','Bali → Jerusalem (El Al Bisnis)',    'El Al Airlines',  'bisnis', 1,18,18500000, 36,'Via Tel Aviv, bisnis class',            '["Bagasi 30kg","Makanan Halal","WiFi","Lounge"]'),
('pesawat','Jakarta → Jerusalem (El Al Ekonomi)','El Al Airlines', 'ekonomi',6,18,12500000,150,'Via Tel Aviv',                          '["Bagasi 23kg","Makanan Halal","Hiburan"]'),
('pesawat','Jakarta → Tokyo (ANA)',              'ANA',             'ekonomi',6,24, 8900000,280,'Via Narita, 7 jam',                    '["Bagasi 23kg","Makanan","Hiburan","WiFi"]'),
('pesawat','Jakarta → Seoul (Korean Air)',       'Korean Air',      'ekonomi',6,26, 7200000,300,'Via Incheon, 6.5 jam',                 '["Bagasi 23kg","Makanan","Hiburan"]'),
('pesawat','Jakarta → Istanbul (Turkish Airlines)','Turkish Airlines','bisnis',6,29,22000000,50,'Via Istanbul, bisnis class',           '["Bagasi 30kg","Makanan Premium","Lounge","WiFi"]'),
('pesawat','Jakarta → Kuala Lumpur (AirAsia)',   'AirAsia',         'ekonomi',6,33, 550000, 180,'1.5 jam direct',                      '["Bagasi 15kg"]'),
('pesawat','Jakarta → Dubai (Emirates)',         'Emirates',        'bisnis', 6,35,19500000, 42,'Via Dubai, bisnis class',              '["Bagasi 30kg","Makanan Premium","Lounge","WiFi","Limusin"]'),
('pesawat','Jakarta → Paris (Air France)',       'Air France',      'ekonomi',6,36,14000000,280,'Via Paris CDG, 14 jam',               '["Bagasi 23kg","Makanan","Hiburan","WiFi"]'),
-- Kapal
('kapal','Bali → Gili (Gili Cat Fast Boat)',     'Gili Cat',   'ekonomi',1,3,  350000,100,'Fast boat Padangbai–Gili 2 jam',          '["Life jacket","Snack","Pemandu"]'),
('kapal','Labuan Bajo → Komodo (Speed Boat)',    'Pelni',      'ekonomi',10,11,280000, 40,'Speed boat wisata Komodo',               '["Life jacket","Pemandu Wisata"]'),
('kapal','Makassar → Toraja (Kapal Sungai)',     'Lokal',      'ekonomi',12,13,150000, 60,'Wisata sungai ke Toraja',               '["Life jacket"]'),
-- Bus / Kereta
('bus','Jakarta → Yogyakarta (Executive Bus)',   'PO Rosalia Indah','ekonomi',6,7,185000, 44,'Bus malam executive 8 jam',           '["AC","Reclining Seat","Snack","Toilet"]'),
('bus','Jakarta → Yogyakarta (VIP Bus)',         'PO Sumber Alam',  'bisnis', 6,7,380000, 20,'Bus VIP double deck 16 jam',         '["Full Bed","Makanan","AC","Toilet","WiFi"]'),
('bus','Jakarta → Yogyakarta (KA Argo Dwipangga)','KAI',           'bisnis', 6,7,550000, 60,'Kereta eksekutif 7 jam',             '["Makanan","AC","Stop Kontak","Koper"]'),
('bus','Jakarta → Bandung (KA Argo Parahyangan)','KAI',            'ekonomi',6,7,150000,200,'Kereta 3 jam',                       '["AC","Stop Kontak"]'),
-- Mobil
('mobil','Rental Mobil Bali + Sopir (Avanza)',   'Lokal Partner','ekonomi',1,1, 450000,1,'Avanza/Xenia 12 jam termasuk sopir',   '["AC","BBM","Sopir","Asuransi"]'),
('mobil','Rental Jeep Bromo Sunrise Tour',       'Lokal Partner','ekonomi',8,8, 650000,1,'Jeep 4WD Bromo sunrise tour',          '["Sopir","BBM","Asuransi"]'),
('mobil','Rental Mobil Jerusalem + Guide',       'Lokal Partner','ekonomi',18,18,1200000,1,'Mobil + pemandu wisata Holy Land',   '["AC","Guide","BBM","Asuransi"]'),
-- Hotel
('hotel','The Mulia Bali (5★)',      'The Mulia',   'first',  1,1, 8500000,50,'Beachfront resort mewah Nusa Dua',       '["Pool","SPA","Sarapan","Butler","Beach Access"]'),
('hotel','AYANA Resort Bali (5★)',   'AYANA',       'first',  1,1, 6800000,80,'Rock Bar Bali dan infinity pool ikonik', '["Pool","SPA","Sarapan","Beach Club","5 Restoran"]'),
('hotel','Komaneka Ubud (4★)',       'Komaneka',    'bisnis', 2,2, 2800000,30,'Boutique resort sawah terasering Ubud',  '["Pool","Sarapan","Spa","Yoga","Shuttle"]'),
('hotel','Alaya Resort Ubud (3★)',   'Alaya',       'ekonomi',2,2,  950000,60,'Resort nyaman di tengah Ubud',           '["Pool","Sarapan","WiFi"]'),
('hotel','Dan Jerusalem Hotel (5★)', 'Dan Hotels',  'bisnis', 18,18,3200000,120,'Hotel ikonik menghadap Old City',      '["Pool","Restoran","Bar","Concierge"]'),
('hotel','Isrotel Tel Aviv (4★)',    'Isrotel',     'ekonomi',19,19,2100000,200,'Beachfront Tel Aviv',                  '["Pool","Sarapan","WiFi","Gym"]'),
('hotel','The Ritz-Carlton Tokyo (5★)','Ritz-Carlton','first',24,24,9500000,80,'Luxury hotel di Roppongi',             '["Pool","SPA","Sarapan","Butler","Lounge"]'),
('hotel','Lotte Hotel Seoul (5★)',   'Lotte',       'bisnis', 26,26,3800000,200,'Hotel premium di pusat Seoul',         '["Pool","Sarapan","WiFi","Gym","Spa"]'),
('hotel','Ciragan Palace Istanbul (5★)','Kempinski','first',  29,29,7500000, 60,'Istana Ottoman di tepi Bosphorus',    '["Pool","SPA","Sarapan","Butler","Private Beach"]'),
-- Paket wisata
('paket_wisata','Paket Bali 4D3N All In',          'TravelKu','ekonomi',6,1,  5500000,20,'Hotel + Transport + Tour Uluwatu-Ubud-Kuta',        '["Hotel 3★","Transport","Guide","2x Tour"]'),
('paket_wisata','Paket Bali Honeymoon 5D4N',       'TravelKu','bisnis', 6,1,  9800000,10,'Villa private + spa + candle dinner',               '["Villa Private","SPA","Candle Dinner","Transport","Guide"]'),
('paket_wisata','Paket Israel Holy Land 8D7N',     'TravelKu','ekonomi',6,18,32000000,15,'Tour ziarah Jerusalem-Nazareth-Dead Sea-Masada',    '["Hotel 4★","Flights","Guide","Halal Meals","Visa Assist"]'),
('paket_wisata','Paket Israel Premium 10D9N',      'TravelKu','bisnis', 6,18,48000000, 8,'Full Israel tour + Dead Sea + Tel Aviv beach',     '["Hotel 5★","Business Flight","Guide","Halal Meals","Visa Assist","Transfer"]'),
('paket_wisata','Paket Jepang Sakura 6D5N',        'TravelKu','ekonomi',6,24,18500000,20,'Tokyo-Kyoto-Osaka musim semi',                     '["Hotel 3★","JR Pass","Guide","Sarapan"]'),
('paket_wisata','Paket Korea K-Culture 5D4N',      'TravelKu','ekonomi',6,26,15000000,20,'Seoul-Jeju + K-pop experience',                    '["Hotel 3★","T-Money","Guide","Sarapan"]'),
('paket_wisata','Paket Turki Istanbul-Cappadocia 7D6N','TravelKu','ekonomi',6,29,21000000,15,'Istanbul + balon udara Cappadocia',             '["Hotel 4★","Transport","Guide","Sarapan","Balon Udara"]'),
('paket_wisata','Paket Raja Ampat Diving 5D4N',    'TravelKu','bisnis', 6,9, 22000000,10,'Live aboard + diving 4 spot terbaik',              '["Kapal Live-on","Makanan","Equipment Diving","Guide"]'),
('paket_wisata','Paket Labuan Bajo Komodo 4D3N',   'TravelKu','ekonomi',6,10, 8500000,15,'Sailing + Komodo dragon + Pink Beach',             '["Kapal Phinisi","Makanan","Snorkeling","Guide"]');
