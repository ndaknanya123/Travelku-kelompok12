# TravelKu — Sistem Reservasi Tiket

Aplikasi web pemesanan tiket perjalanan yang mengintegrasikan berbagai jenis layanan transportasi dan akomodasi dalam satu platform. Dibangun dengan arsitektur tiga-tier menggunakan Vagrant untuk otomasi infrastruktur.

---

## Latar Belakang

Dengan meningkatnya kebutuhan travel baik dalam maupun luar negeri, mobilitas masyarakat terus berkembang pesat. Namun proses pemesanan tiket dan akomodasi masih sering terfragmentasi dan rentan terhadap konflik jadwal seperti double booking. TravelKu hadir sebagai solusi terpadu yang mempertemukan kebutuhan pelanggan akan kemudahan reservasi dengan kebutuhan admin akan kendali penuh terhadap operasional layanan.

---

## Stack

| Komponen | Teknologi |
|---|---|
| Frontend | HTML, CSS, JavaScript murni — di-serve oleh Nginx |
| Backend | Python 3 + Flask — REST API |
| Database | MySQL 8 |
| Infrastruktur | Vagrant + VirtualBox + Ansible |

---

## Arsitektur

Tiga VM berjalan di jaringan private VirtualBox:

```
Browser (http://192.168.56.22)
    │
    ▼
VM Frontend  192.168.56.22  — Nginx, menampilkan index.html
    │
    ▼  fetch /api/*
VM Backend   192.168.56.20  — Flask :5000, semua logika backend
    │
    ▼  SQL query
VM Database  192.168.56.21  — MySQL, penyimpanan data
```

---

## Prasyarat

- VirtualBox 6.1+
- Vagrant 2.3+
- RAM kosong minimal 4GB (3 VM masing-masing 1GB)

---

## Instalasi

```bash
git clone https://github.com/ndaknanya123/Travelku-kelompok12
cd travelku
vagrant up
```

Proses pertama kali membutuhkan sekitar 10–15 menit. Setelah selesai buka browser ke `http://192.168.56.22`.

Akun admin bawaan: `admin@travelku.id` / `admin123`

---

## Struktur Folder

```
travelku/
├── Vagrantfile
├── playbook.yml
├── database/
│   └── schema.sql
├── backend/
│   └── app.py
└── frontend/
    └── index.html
```

---

## Fitur

**Pelanggan**
- Register dan login, bisa buat akun sebanyak apapun
- Lihat dan filter destinasi lokal (Bali, Raja Ampat, Toraja, dll.) dan internasional (Israel, Jepang, Turki, dll.)
- Pilih layanan: pesawat, kapal, bus, kereta, rental mobil, hotel, paket wisata
- Kalender interaktif per layanan — warna hijau tersedia, merah penuh, merah-bergaris diblokir
- Booking dengan interlocking slot — satu tanggal tidak bisa dipesan dua kali untuk layanan yang sama
- Lihat riwayat reservasi dan batalkan secara mandiri

**Admin**
- Dashboard statistik: total pelanggan, booking, revenue per status
- Kelola semua reservasi dan ubah statusnya (pending, dikonfirmasi, selesai, dibatalkan)
- Generate jadwal untuk range tanggal tertentu, dengan opsi override harga
- Blokir atau buka kembali tanggal tertentu beserta alasannya
- Tambah layanan baru langsung dari panel

---

## API Endpoints

**Publik**

```
GET  /api/health                      cek status backend dan koneksi database
POST /api/auth/register               daftar akun baru
POST /api/auth/login                  login, return token
GET  /api/destinasi                   list destinasi
GET  /api/layanan?tipe=pesawat        list layanan dengan filter opsional
GET  /api/jadwal/:layanan_id          jadwal 90 hari ke depan
```

**Butuh akun**

```
POST /api/reservasi                   buat reservasi
GET  /api/reservasi/saya              riwayat reservasi user
POST /api/reservasi/:id/batalkan      batalkan reservasi
```

**Admin**

```
GET  /api/admin/dashboard             statistik dan revenue
GET  /api/admin/reservasi             semua reservasi
PUT  /api/admin/reservasi/:id/status  update status
POST /api/admin/jadwal/generate       generate jadwal range tanggal
POST /api/admin/jadwal/blokir         blokir atau buka tanggal
POST /api/admin/layanan               tambah layanan baru
```

---

## Perintah Berguna

```bash
# Masuk ke VM tertentu
vagrant ssh backend
vagrant ssh frontend
vagrant ssh database

# Cek log backend real-time
vagrant ssh backend -c "sudo journalctl -u travelku -f --no-pager"

# Restart backend setelah edit app.py
vagrant ssh backend -c "sudo cp /vagrant/backend/app.py /home/vagrant/app.py && sudo systemctl restart travelku"

# Update frontend setelah edit index.html
vagrant ssh frontend -c "sudo cp /vagrant/frontend/index.html /var/www/html/index.html"

# Cek tabel database
vagrant ssh database -c "sudo mysql -u root -e 'USE db_travel_reservasi; SHOW TABLES;'"

# Matikan semua VM
vagrant halt

# Reset total
vagrant destroy -f && vagrant up
```

