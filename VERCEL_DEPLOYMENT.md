# Panduan Deploy Flutter Web ke Vercel

## Persiapan

### 1. Install Vercel CLI (Opsional)
```bash
npm install -g vercel
```

### 2. Build Flutter Web
```bash
flutter build web --release --web-renderer canvaskit
```

## Cara Deploy ke Vercel

### Metode 1: Via GitHub (Recommended)

1. **Push project ke GitHub**
   ```bash
   git add .
   git commit -m "Prepare for Vercel deployment"
   git push origin main
   ```

2. **Connect ke Vercel**
   - Buka https://vercel.com/dashboard
   - Klik "Add New..." → "Project"
   - Import repository GitHub Anda
   - Pilih project `absensi_pegawai`

3. **Configure Build Settings**
   Vercel akan otomatis detect dari `vercel.json`:
   - Build Command: `flutter build web --release --web-renderer canvaskit`
   - Output Directory: `build/web`
   - Install Command: Vercel akan install Flutter otomatis

4. **Deploy**
   - Klik "Deploy"
   - Tunggu proses build selesai (5-10 menit pertama kali)

### Metode 2: Via Vercel CLI

1. **Login ke Vercel**
   ```bash
   vercel login
   ```

2. **Deploy**
   ```bash
   # Di folder project
   cd c:\absensi_pegawai
   
   # Build terlebih dahulu
   flutter build web --release
   
   # Deploy
   vercel --prod
   ```

3. **Follow prompts**
   - Set up and deploy: Y
   - Which scope: Pilih account Anda
   - Link to existing project: Y (pilih e-absensi-cv-tanjung-agung)
   - Override settings: N

## Update Existing Vercel Project

Jika project `e-absensi-cv-tanjung-agung` sudah ada:

1. **Via Vercel Dashboard**
   - Buka project di dashboard
   - Settings → General → Build & Development Settings
   - Update:
     - Build Command: `flutter build web --release --web-renderer canvaskit`
     - Output Directory: `build/web`
   - Redeploy dari tab "Deployments"

2. **Via Git Push**
   Setelah connect ke GitHub, setiap push akan auto-deploy:
   ```bash
   git add .
   git commit -m "Update app"
   git push
   ```

## Environment Variables (Opsional)

Untuk keamanan lebih baik, tambahkan environment variables di Vercel:

1. Buka project di Vercel Dashboard
2. Settings → Environment Variables
3. Tambahkan:
   - `SUPABASE_URL`: `https://ywcorlgzufyxcaaznxwu.supabase.co`
   - `SUPABASE_ANON_KEY`: (copy dari main.dart)

## Troubleshooting

### Build Failed
- Pastikan Flutter SDK tersedia
- Vercel akan auto-install Flutter, tapi butuh waktu
- Check build logs di Vercel dashboard

### Routing Issues
- File `vercel.json` sudah configured untuk SPA routing
- Semua routes akan redirect ke `index.html`

### CORS Issues
- Pastikan Supabase settings mengizinkan domain Vercel Anda
- Buka Supabase Dashboard → Settings → API → URL Configuration

## Custom Domain (Opsional)

1. Buka project di Vercel
2. Settings → Domains
3. Add domain Anda
4. Follow DNS configuration instructions

## Files yang Sudah Disiapkan

✅ `vercel.json` - Konfigurasi build dan routing
✅ `.vercelignore` - File yang diabaikan saat deploy
✅ `.gitignore` - Sudah ada dari Flutter

## Domain Default

Setelah deploy, aplikasi akan tersedia di:
- Production: `https://e-absensi-cv-tanjung-agung.vercel.app`
- Preview: Setiap branch akan dapat preview URL

## Notes

- Build pertama akan memakan waktu 5-10 menit
- Build selanjutnya akan lebih cepat (cache)
- Vercel free tier: Unlimited deployments
- Flutter web sudah optimized untuk production
