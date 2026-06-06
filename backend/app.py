#!/usr/bin/env python3
"""
TravelKu Backend API — Final Version
Fixes: Decimal JSON serialization, route 404, PUT+POST method
"""
from flask import Flask, request, jsonify
from flask_cors import CORS
import MySQLdb, MySQLdb.cursors
import hashlib, hmac, os, random, string, json
from datetime import datetime, timedelta, date
from decimal import Decimal

app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})

SECRET_KEY = os.environ.get("SECRET_KEY", "travelku_prod_secret_2026")

# ── JSON safe encoder ────────────────────────────────────────
class SafeEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):          return float(o)
        if isinstance(o, (date, datetime)): return o.isoformat()
        return super().default(o)

app.json_encoder = SafeEncoder

# ── DB ───────────────────────────────────────────────────────
def get_db():
    return MySQLdb.connect(
        host   = os.environ.get("DB_HOST", "192.168.56.21"),
        user   = os.environ.get("DB_USER", "travel_user"),
        passwd = os.environ.get("DB_PASS", "travel_pass123"),
        db     = os.environ.get("DB_NAME", "db_travel_reservasi"),
        charset = "utf8mb4",
        cursorclass = MySQLdb.cursors.DictCursor
    )

def clean(row):
    """Convert Decimal/date values to JSON-safe types."""
    if not row: return row
    out = {}
    for k, v in row.items():
        if isinstance(v, Decimal):          out[k] = float(v)
        elif isinstance(v, (date, datetime)): out[k] = v.isoformat()
        else:                                out[k] = v
    return out

def clean_all(rows):
    return [clean(r) for r in rows]

# ── Auth ─────────────────────────────────────────────────────
def hash_pw(pw):
    return hashlib.sha256((pw + SECRET_KEY).encode()).hexdigest()

def make_token(uid, role):
    return hashlib.sha256(f"{uid}:{role}:{SECRET_KEY}".encode()).hexdigest()

def get_user():
    token = request.headers.get("X-Auth-Token", "")
    uid   = request.headers.get("X-User-Id",    "")
    if not token or not uid: return None
    try:
        uid = int(uid)
        db = get_db(); cur = db.cursor()
        cur.execute("SELECT id,nama,email,role FROM users WHERE id=%s", (uid,))
        user = cur.fetchone(); db.close()
        if not user: return None
        if hmac.compare_digest(token, make_token(uid, user["role"])):
            return user
    except Exception:
        pass
    return None

def gen_kode():
    chars = string.ascii_uppercase + string.digits
    return "TKU-" + "".join(random.choices(chars, k=8))

# ── Error handlers ───────────────────────────────────────────
@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Endpoint tidak ditemukan"}), 404

@app.errorhandler(405)
def method_not_allowed(e):
    return jsonify({"error": "Method tidak diizinkan"}), 405

@app.errorhandler(500)
def server_error(e):
    return jsonify({"error": "Internal server error", "detail": str(e)}), 500

# ══════════════════════════════════════════════════════════════
# AUTH
# ══════════════════════════════════════════════════════════════
@app.route("/api/auth/register", methods=["POST"])
def register():
    d     = request.json or {}
    nama  = d.get("nama",     "").strip()
    email = d.get("email",    "").strip().lower()
    pw    = d.get("password", "")
    if not all([nama, email, pw]):
        return jsonify({"error": "Semua field wajib diisi"}), 400
    if len(pw) < 6:
        return jsonify({"error": "Password minimal 6 karakter"}), 400
    db = get_db(); cur = db.cursor()
    cur.execute("SELECT id FROM users WHERE email=%s", (email,))
    if cur.fetchone():
        db.close()
        return jsonify({"error": "Email sudah terdaftar"}), 409
    cur.execute(
        "INSERT INTO users (nama,email,password_hash,role) VALUES (%s,%s,%s,'pelanggan')",
        (nama, email, hash_pw(pw))
    )
    db.commit(); uid = cur.lastrowid; db.close()
    return jsonify({
        "user_id": uid, "nama": nama,
        "role": "pelanggan", "token": make_token(uid, "pelanggan")
    }), 201

@app.route("/api/auth/login", methods=["POST"])
def login():
    d     = request.json or {}
    email = d.get("email",    "").strip().lower()
    pw    = d.get("password", "")
    db = get_db(); cur = db.cursor()
    cur.execute(
        "SELECT id,nama,email,role,password_hash FROM users WHERE email=%s", (email,)
    )
    u = cur.fetchone(); db.close()
    if not u or u["password_hash"] != hash_pw(pw):
        return jsonify({"error": "Email atau password salah"}), 401
    return jsonify({
        "user_id": u["id"], "nama": u["nama"],
        "email":   u["email"], "role": u["role"],
        "token":   make_token(u["id"], u["role"])
    })

# ══════════════════════════════════════════════════════════════
# DESTINASI
# ══════════════════════════════════════════════════════════════
@app.route("/api/destinasi", methods=["GET"])
def list_destinasi():
    kategori = request.args.get("kategori")
    wilayah  = request.args.get("wilayah")
    db = get_db(); cur = db.cursor()
    sql    = "SELECT * FROM destinasi WHERE aktif=1"
    params = []
    if kategori: sql += " AND kategori=%s"; params.append(kategori)
    if wilayah:  sql += " AND wilayah=%s";  params.append(wilayah)
    sql += " ORDER BY kategori, wilayah, nama"
    cur.execute(sql, params)
    rows = clean_all(cur.fetchall()); db.close()
    return jsonify(rows)

# ══════════════════════════════════════════════════════════════
# LAYANAN
# ══════════════════════════════════════════════════════════════
@app.route("/api/layanan", methods=["GET"])
def list_layanan():
    tipe    = request.args.get("tipe")
    ke_dest = request.args.get("ke_destinasi_id")
    db = get_db(); cur = db.cursor()
    sql = """
        SELECT l.*,
               d1.nama AS dari_nama, d1.kota AS dari_kota,
               d2.nama AS ke_nama,   d2.kota AS ke_kota,
               d2.negara AS ke_negara,
               d2.kategori AS dest_kategori, d2.wilayah AS dest_wilayah
        FROM layanan l
        JOIN destinasi d1 ON l.dari_destinasi_id = d1.id
        JOIN destinasi d2 ON l.ke_destinasi_id   = d2.id
        WHERE l.aktif = 1
    """
    params = []
    if tipe:    sql += " AND l.tipe=%s";             params.append(tipe)
    if ke_dest: sql += " AND l.ke_destinasi_id=%s";  params.append(ke_dest)
    sql += " ORDER BY l.tipe, l.harga_dasar"
    cur.execute(sql, params)
    rows = cur.fetchall(); db.close()
    result = []
    for r in rows:
        r = clean(r)
        try:    r["fasilitas"] = json.loads(r.get("fasilitas") or "[]")
        except: r["fasilitas"] = []
        result.append(r)
    return jsonify(result)

@app.route("/api/layanan/<int:lid>", methods=["GET"])
def get_layanan(lid):
    db = get_db(); cur = db.cursor()
    cur.execute("""
        SELECT l.*,
               d1.nama AS dari_nama, d1.kota AS dari_kota,
               d2.nama AS ke_nama,   d2.kota AS ke_kota,
               d2.negara AS ke_negara, d2.deskripsi AS dest_deskripsi
        FROM layanan l
        JOIN destinasi d1 ON l.dari_destinasi_id = d1.id
        JOIN destinasi d2 ON l.ke_destinasi_id   = d2.id
        WHERE l.id = %s
    """, (lid,))
    row = cur.fetchone(); db.close()
    if not row: return jsonify({"error": "Tidak ditemukan"}), 404
    row = clean(row)
    try:    row["fasilitas"] = json.loads(row.get("fasilitas") or "[]")
    except: row["fasilitas"] = []
    return jsonify(row)

# ══════════════════════════════════════════════════════════════
# JADWAL
# ══════════════════════════════════════════════════════════════
@app.route("/api/jadwal/<int:layanan_id>", methods=["GET"])
def get_jadwal(layanan_id):
    batas = (date.today() + timedelta(days=90)).isoformat()
    db = get_db(); cur = db.cursor()
    cur.execute("""
        SELECT j.*,
               COALESCE(j.harga_override, l.harga_dasar) AS harga_efektif
        FROM jadwal j
        JOIN layanan l ON j.layanan_id = l.id
        WHERE j.layanan_id = %s
          AND j.tanggal >= CURDATE()
          AND j.tanggal <= %s
        ORDER BY j.tanggal
    """, (layanan_id, batas))
    rows = clean_all(cur.fetchall()); db.close()
    return jsonify(rows)

# ══════════════════════════════════════════════════════════════
# RESERVASI
# ══════════════════════════════════════════════════════════════
@app.route("/api/reservasi", methods=["POST"])
def buat_reservasi():
    user = get_user()
    if not user:
        return jsonify({"error": "Login diperlukan"}), 401

    d          = request.json or {}
    jadwal_id  = d.get("jadwal_id")
    jumlah     = int(d.get("jumlah_tiket", 1))
    nama_p     = d.get("nama_pemesan",  user["nama"])
    email_p    = d.get("email_pemesan", user["email"])
    telepon    = d.get("telepon",  "")
    catatan    = d.get("catatan",  "")

    if not jadwal_id or jumlah < 1:
        return jsonify({"error": "jadwal_id dan jumlah_tiket diperlukan"}), 400

    db = get_db(); cur = db.cursor()

    # Lock baris jadwal supaya tidak race condition
    cur.execute("""
        SELECT j.*,
               COALESCE(j.harga_override, l.harga_dasar) AS harga_efektif
        FROM jadwal j
        JOIN layanan l ON j.layanan_id = l.id
        WHERE j.id = %s FOR UPDATE
    """, (jadwal_id,))
    jadwal = cur.fetchone()

    if not jadwal:
        db.close()
        return jsonify({"error": "Jadwal tidak ditemukan"}), 404

    if jadwal["status"] != "tersedia":
        db.close()
        return jsonify({"error": f"Jadwal tidak tersedia (status: {jadwal['status']})"}), 409

    if jadwal["kapasitas_sisa"] < jumlah:
        db.close()
        return jsonify({"error": f"Sisa kapasitas hanya {jadwal['kapasitas_sisa']}"}), 409

    # Cek double booking hari yang sama + layanan yang sama
    cur.execute("""
        SELECT r.id FROM reservasi r
        JOIN jadwal j ON r.jadwal_id = j.id
        WHERE r.user_id = %s
          AND j.layanan_id = %s
          AND j.tanggal = %s
          AND r.status NOT IN ('dibatalkan')
    """, (user["id"], jadwal["layanan_id"], jadwal["tanggal"]))

    if cur.fetchone():
        db.close()
        return jsonify({"error": "Kamu sudah memiliki reservasi di tanggal ini untuk layanan yang sama"}), 409

    total = float(jadwal["harga_efektif"]) * jumlah
    kode  = gen_kode()

    cur.execute("""
        INSERT INTO reservasi
          (kode_booking, user_id, jadwal_id, jumlah_tiket,
           total_harga, nama_pemesan, email_pemesan, telepon, catatan)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """, (kode, user["id"], jadwal_id, jumlah, total,
          nama_p, email_p, telepon, catatan))

    rid       = cur.lastrowid
    sisa_baru = jadwal["kapasitas_sisa"] - jumlah
    new_status = "penuh" if sisa_baru <= 0 else "tersedia"

    cur.execute(
        "UPDATE jadwal SET kapasitas_sisa=%s, status=%s WHERE id=%s",
        (sisa_baru, new_status, jadwal_id)
    )
    db.commit(); db.close()

    return jsonify({
        "reservasi_id": rid,
        "kode_booking": kode,
        "total_harga":  total,
        "status":       "pending",
        "message":      "Reservasi berhasil dibuat!"
    }), 201


@app.route("/api/reservasi/saya", methods=["GET"])
def reservasi_saya():
    user = get_user()
    if not user:
        return jsonify({"error": "Unauthorized"}), 401
    db = get_db(); cur = db.cursor()
    cur.execute("""
        SELECT r.*,
               j.tanggal, j.status AS jadwal_status,
               l.tipe, l.nama AS layanan_nama, l.maskapai,
               d2.nama AS dest_nama, d2.kota AS dest_kota,
               d2.negara AS dest_negara
        FROM reservasi r
        JOIN jadwal j     ON r.jadwal_id     = j.id
        JOIN layanan l    ON j.layanan_id    = l.id
        JOIN destinasi d2 ON l.ke_destinasi_id = d2.id
        WHERE r.user_id = %s
        ORDER BY r.created_at DESC
    """, (user["id"],))
    rows = clean_all(cur.fetchall()); db.close()
    return jsonify(rows)


@app.route("/api/reservasi/<int:rid>/batalkan", methods=["POST"])
def batalkan(rid):
    user = get_user()
    if not user:
        return jsonify({"error": "Unauthorized"}), 401
    db = get_db(); cur = db.cursor()
    cur.execute("SELECT * FROM reservasi WHERE id=%s", (rid,))
    res = cur.fetchone()
    if not res:
        db.close(); return jsonify({"error": "Tidak ditemukan"}), 404
    if res["user_id"] != user["id"] and user["role"] != "admin":
        db.close(); return jsonify({"error": "Forbidden"}), 403
    if res["status"] == "dibatalkan":
        db.close(); return jsonify({"error": "Sudah dibatalkan"}), 400

    cur.execute("UPDATE reservasi SET status='dibatalkan' WHERE id=%s", (rid,))
    cur.execute("""
        UPDATE jadwal
        SET kapasitas_sisa = kapasitas_sisa + %s,
            status = CASE WHEN status='penuh' THEN 'tersedia' ELSE status END
        WHERE id = %s
    """, (res["jumlah_tiket"], res["jadwal_id"]))
    db.commit(); db.close()
    return jsonify({"message": "Reservasi berhasil dibatalkan"})

# ══════════════════════════════════════════════════════════════
# ADMIN
# ══════════════════════════════════════════════════════════════
@app.route("/api/admin/dashboard", methods=["GET"])
def admin_dashboard():
    user = get_user()
    if not user or user["role"] != "admin":
        return jsonify({"error": "Forbidden"}), 403
    db = get_db(); cur = db.cursor()

    cur.execute("""
        SELECT status,
               COUNT(*) AS jumlah,
               CAST(COALESCE(SUM(total_harga),0) AS CHAR) AS revenue
        FROM reservasi GROUP BY status
    """)
    stats = cur.fetchall()

    cur.execute("SELECT COUNT(*) AS total FROM users WHERE role='pelanggan'")
    total_users = cur.fetchone()["total"]

    cur.execute("""
        SELECT r.kode_booking, r.status,
               CAST(r.total_harga AS CHAR) AS total_harga,
               r.created_at,
               u.nama AS user_nama,
               l.nama AS layanan_nama
        FROM reservasi r
        JOIN users u  ON r.user_id    = u.id
        JOIN jadwal j ON r.jadwal_id  = j.id
        JOIN layanan l ON j.layanan_id = l.id
        ORDER BY r.created_at DESC LIMIT 10
    """)
    terbaru = clean_all(cur.fetchall())

    cur.execute("""
        SELECT d.nama, d.negara, COUNT(r.id) AS booking_count
        FROM reservasi r
        JOIN jadwal j     ON r.jadwal_id       = j.id
        JOIN layanan l    ON j.layanan_id      = l.id
        JOIN destinasi d  ON l.ke_destinasi_id = d.id
        WHERE r.status != 'dibatalkan'
        GROUP BY d.id ORDER BY booking_count DESC LIMIT 5
    """)
    top_dest = cur.fetchall()
    db.close()

    result_stats = []
    for s in stats:
        result_stats.append({
            "status":  s["status"],
            "jumlah":  s["jumlah"],
            "revenue": float(s["revenue"])
        })

    return jsonify({
        "reservasi_stats":    result_stats,
        "total_users":        total_users,
        "reservasi_terbaru":  terbaru,
        "destinasi_populer":  top_dest
    })


@app.route("/api/admin/reservasi", methods=["GET"])
def admin_all_reservasi():
    user = get_user()
    if not user or user["role"] != "admin":
        return jsonify({"error": "Forbidden"}), 403
    status = request.args.get("status")
    db = get_db(); cur = db.cursor()
    sql = """
        SELECT r.*,
               u.nama  AS user_nama, u.email AS user_email,
               j.tanggal,
               l.tipe, l.nama AS layanan_nama,
               d2.nama AS dest_nama, d2.negara AS dest_negara
        FROM reservasi r
        JOIN users u      ON r.user_id        = u.id
        JOIN jadwal j     ON r.jadwal_id      = j.id
        JOIN layanan l    ON j.layanan_id     = l.id
        JOIN destinasi d2 ON l.ke_destinasi_id = d2.id
    """
    params = []
    if status:
        sql += " WHERE r.status = %s"; params.append(status)
    sql += " ORDER BY r.created_at DESC"
    cur.execute(sql, params)
    rows = clean_all(cur.fetchall()); db.close()
    return jsonify(rows)


# FIX: accept both PUT and POST untuk kompatibilitas browser
@app.route("/api/admin/reservasi/<int:rid>/status", methods=["PUT", "POST"])
def admin_update_status(rid):
    user = get_user()
    if not user or user["role"] != "admin":
        return jsonify({"error": "Forbidden"}), 403
    d      = request.json or {}
    status = d.get("status")
    valid  = ["pending", "dikonfirmasi", "dibatalkan", "selesai"]
    if status not in valid:
        return jsonify({"error": f"Status harus salah satu dari: {valid}"}), 400
    db = get_db(); cur = db.cursor()
    cur.execute("UPDATE reservasi SET status=%s WHERE id=%s", (status, rid))
    affected = cur.rowcount
    db.commit(); db.close()
    return jsonify({"updated": affected, "status": status})


@app.route("/api/admin/jadwal/generate", methods=["POST"])
def admin_generate_jadwal():
    user = get_user()
    if not user or user["role"] != "admin":
        return jsonify({"error": "Forbidden"}), 403
    d           = request.json or {}
    layanan_id  = d.get("layanan_id")
    tgl_mulai   = d.get("tanggal_mulai")
    tgl_selesai = d.get("tanggal_selesai", tgl_mulai)
    harga_ov    = d.get("harga_override")
    if not all([layanan_id, tgl_mulai]):
        return jsonify({"error": "layanan_id dan tanggal_mulai diperlukan"}), 400
    db = get_db(); cur = db.cursor()
    cur.execute("SELECT kapasitas FROM layanan WHERE id=%s", (layanan_id,))
    lay = cur.fetchone()
    if not lay:
        db.close(); return jsonify({"error": "Layanan tidak ditemukan"}), 404
    kap     = lay["kapasitas"]
    start   = datetime.strptime(tgl_mulai,   "%Y-%m-%d").date()
    end     = datetime.strptime(tgl_selesai, "%Y-%m-%d").date()
    created = 0
    cur_d   = start
    while cur_d <= end:
        try:
            cur.execute("""
                INSERT IGNORE INTO jadwal
                  (layanan_id, tanggal, kapasitas_sisa, harga_override, status)
                VALUES (%s, %s, %s, %s, 'tersedia')
            """, (layanan_id, cur_d.isoformat(), kap, harga_ov))
            created += cur.rowcount
        except Exception:
            pass
        cur_d += timedelta(days=1)
    db.commit(); db.close()
    return jsonify({"created": created, "message": f"{created} jadwal berhasil dibuat"})


@app.route("/api/admin/jadwal/blokir", methods=["POST"])
def admin_blokir_jadwal():
    user = get_user()
    if not user or user["role"] != "admin":
        return jsonify({"error": "Forbidden"}), 403
    d           = request.json or {}
    layanan_id  = d.get("layanan_id")
    tgl_mulai   = d.get("tanggal_mulai")
    tgl_selesai = d.get("tanggal_selesai", tgl_mulai)
    aksi        = d.get("aksi", "blokir")
    alasan      = d.get("alasan", "")
    if not all([layanan_id, tgl_mulai]):
        return jsonify({"error": "layanan_id dan tanggal_mulai diperlukan"}), 400
    status_baru = "diblokir" if aksi == "blokir" else "tersedia"
    db = get_db(); cur = db.cursor()
    cur.execute("""
        UPDATE jadwal
        SET status=%s, blokir_oleh=%s, blokir_alasan=%s
        WHERE layanan_id=%s AND tanggal BETWEEN %s AND %s
    """, (status_baru, user["id"], alasan, layanan_id, tgl_mulai, tgl_selesai))
    affected = cur.rowcount
    db.commit(); db.close()
    return jsonify({"updated": affected, "status": status_baru})


@app.route("/api/admin/layanan", methods=["POST"])
def admin_tambah_layanan():
    user = get_user()
    if not user or user["role"] != "admin":
        return jsonify({"error": "Forbidden"}), 403
    d = request.json or {}
    if not all([d.get("tipe"), d.get("nama"), d.get("harga_dasar"),
                d.get("dari_destinasi_id"), d.get("ke_destinasi_id")]):
        return jsonify({"error": "Field wajib: tipe, nama, harga_dasar, dari/ke destinasi"}), 400
    db = get_db(); cur = db.cursor()
    cur.execute("""
        INSERT INTO layanan
          (tipe, nama, maskapai, kelas, dari_destinasi_id,
           ke_destinasi_id, harga_dasar, kapasitas, deskripsi, fasilitas)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """, (d["tipe"], d["nama"], d.get("maskapai"), d.get("kelas","ekonomi"),
          d["dari_destinasi_id"], d["ke_destinasi_id"],
          d["harga_dasar"], d.get("kapasitas", 1),
          d.get("deskripsi", ""), json.dumps(d.get("fasilitas", []))))
    db.commit(); lid = cur.lastrowid; db.close()
    return jsonify({"id": lid, "message": "Layanan berhasil ditambahkan"}), 201


# ══════════════════════════════════════════════════════════════
# HEALTH
# ══════════════════════════════════════════════════════════════
@app.route("/api/health", methods=["GET"])
def health():
    try:
        db = get_db(); cur = db.cursor()
        cur.execute("SELECT 1"); db.close()
        return jsonify({"status": "ok", "db": "connected"})
    except Exception as e:
        return jsonify({"status": "error", "db": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
