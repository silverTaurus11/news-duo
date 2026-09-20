# Briefly — Strategi

Aplikasi berita untuk iPhone Duo (juga berjalan di iPhone biasa & iPad). Fitur: **list**, **detail**, **save/like**.

## 1. Temuan HIG iPhone Duo

Sumber: Apple HIG "Designing for iPhone Duo" dan halaman developer iPhone Duo.

| Prinsip HIG | Konsekuensi untuk app ini |
|---|---|
| Outer display = *compact width*, inner display = *regular width*. Jangan desain per pose; cukup adaptif via size class. | Tidak ada layout khusus per pose. Satu hierarki view yang beradaptasi. |
| Split view: dua pane di inner display, satu pane di outer display; otomatis menyesuaikan area lipatan. | `NavigationSplitView`: **kiri list, kanan detail**. Di outer/iPhone otomatis jadi push navigation. |
| Tab bar & toolbar pindah ke sisi vertikal secara otomatis untuk komponen standar. | Pakai `TabView`, `.toolbar`, `ToolbarItemGroup` standar; tidak ada bar custom. |
| Konten yang bisa di-scroll tidak perlu dipindah dari area lipatan. | List & artikel memakai `List`/`ScrollView` biasa. |
| Toolbar item sebaiknya punya judul + simbol. | Tombol Save dan Share memakai `Label`. |

**Pembaruan (Xcode 27.1 beta):** API Duo ada di SwiftUI iOS 27.1 (`ArrangementView`, `reservedRegions`, `toolbarVerticalEdge`, `toolbarVerticalBehavior`, `toolbarVerticalCompressionBehavior`, `axisBehavior`), dan tipe simulator "iPhone Duo" tersedia (butuh runtime iOS 27.1). Sebelumnya (Xcode 27.0) SDK belum memuatnya. Keputusan:

- Layout tetap di atas `NavigationSplitView`: dokumen Apple menyebut split view, tab bar, dan navigation stack sebagai container sistem yang otomatis menyesuaikan layar luar/dalam dan lipatan. `ArrangementView` dan `reservedRegions` tidak dipakai karena belum ada kebutuhan layout custom.
- **Bar vertikal disesuaikan** (lihat README): item toolbar selalu punya ikon `Image` + judul, karena bar vertikal hanya menampilkan ikon dan tidak menampilkan item tanpa ikon.
- Titik masuk untuk tuning Duo tetap `ArticlesSplitView`.
- Terverifikasi di simulator iPhone Duo: layar luar (tertutup). Belum: layar dalam, pose terlipat sebagian, dan perilaku di area lipatan.

## 2. Arsitektur — Clean Architecture

Aturan dependensi: `Presentation → Domain ← Data`. Domain tidak meng-import SwiftUI/URLSession.

```
news-duo/
├── App/                    Composition root
│   ├── news_duoApp.swift
│   ├── AppContainer.swift  merakit repository → use case → view model
│   └── AppConfig.swift     mencari API key (env → Secrets.plist → demo)
├── Domain/                 Aturan bisnis, murni Swift
│   ├── Entities/           Article, ArticlesPage, ArticleQuery, Country,
│   │                       NewsCategory, ArticleSortOrder, NewsError
│   ├── Repositories/       NewsRepository, SavedArticlesRepository (protocol)
│   └── UseCases/           FetchArticles, GetSavedArticles, ToggleSavedArticle
├── Data/                   Detail teknis
│   ├── Network/            HTTPClient, NewsAPIConfiguration, NewsAPIEndpoint
│   ├── Remote/             DTO NewsAPI + mapper DTO → Article
│   └── Repositories/       DefaultNewsRepository, DemoNewsRepository,
│                           FileSavedArticlesRepository (JSON, actor)
└── Presentation/           SwiftUI + @Observable
    ├── Root/               RootView (TabView), ArticlesSplitView
    ├── NewsFeed/           NewsFeedScreen + NewsFeedViewModel (headlines + search)
    ├── Saved/              SavedScreen + SavedArticlesViewModel
    ├── Detail/             ArticleDetailView
    └── Components/         ArticleListView, ArticleRow, RemoteImageView,
                            FilterChipBar, CountryPickerView, DisplayNames
```

### Alur data
`View → ViewModel → UseCase → Repository (protocol) → implementasi Data → NewsAPI / file JSON`

### Keputusan utama
- **Identitas artikel** = URL artikel (NewsAPI tidak punya id). Duplikat dibuang saat paging.
- **Paging**: `page`/`pageSize=10`, lazy load (infinite scroll); `hasMore = page × pageSize < totalResults` (lihat bagian 5: halaman NewsAPI bisa pendek/kosong).
- **Save/like**: satu `SavedArticlesViewModel` bersama (environment) jadi sumber kebenaran tunggal untuk ikon ❤︎ di list, detail, dan tab Saved. Artikel disimpan utuh (JSON di Application Support) supaya bisa dibuka offline.
- **API key**: header `X-Api-Key` (tidak masuk URL/log). Sumber, berurutan: env `NEWS_API_KEY` → `news-duo/Secrets.plist` (di `.gitignore`; contoh di `Secrets.example.plist`) → placeholder. Tanpa key → `DemoNewsRepository` + subtitle "Demo data" agar UI tetap bisa dicoba dan hasil clone bisa dibangun. Key yang dikompilasi ke app bisa diekstrak dari binary: untuk produksi arahkan request lewat backend.
- **Error**: `NewsError` di Domain (key salah, rate limit, offline, batas hasil, dll.), diterjemahkan di Data layer, ditampilkan sebagai `ContentUnavailableView` + tombol coba lagi.
- **Konkurensi**: default isolation proyek = MainActor. Domain & Data ditandai `nonisolated` + `Sendable`; ViewModel tetap MainActor.

## 3. Strategi pengujian
- **Unit (Swift Testing)**: mapper DTO, repository (HTTP di-stub), penyimpanan file, use case, ViewModel (paging, dedupe, error) dengan fake repository.
- **Visual**: simulator iPad (dua pane), iPhone (satu pane), dan iPhone Duo layar luar.
- **Belum diverifikasi**: layar dalam dan pose terlipat sebagian di simulator Duo.

## 4. Asumsi
- "Save like" = satu aksi favorit (❤︎) + daftar Saved.
- Teks UI berbahasa Inggris (konten NewsAPI berbahasa Inggris); mudah dipindah ke String Catalog.
- Negara headline default `us` (headline `id` di NewsAPI sangat sedikit); ubah di `AppContainer` (`defaultCountry`).

## 5. Filter, search, dan temuan NewsAPI

Satu layar berita, satu `ArticleQuery`:

| Kondisi | Endpoint | Kontrol UI |
|---|---|---|
| Kolom search kosong | `/top-headlines` | tombol bendera (picker negara) + chip kategori (All + 7) |
| Search di-submit | `/everything` | chip `sortBy`: Relevancy / Popularity / Newest |

- **Search hanya dijalankan saat submit** (bukan tiap ketikan) karena paket developer dibatasi 100 request/hari. Menghapus teks kembali ke top headlines. Teks di-trim, maks 500 karakter; `+` dikirim sebagai `%2B` agar operator NewsAPI (`+kata`, `-kata`, `"frasa"`) tetap bekerja.
- **Bendera**: emoji dari kode negara ISO (regional indicator), tanpa dependency. Library seperti SwiftFlags/bendodson hanya membungkus trik yang sama. Jika kelak butuh bendera gambar yang seragam lintas platform, gunakan FlagKit (aset PNG/SVG).
- **Respons usang**: setiap load halaman pertama menaikkan `generation`; respons query lama dibuang (ada test dengan repository berlatensi berbeda).

Temuan dari request nyata (developer plan, diperiksa 2026-09-20):

1. `top-headlines` hanya mengembalikan data untuk `us`. `gb, de, au, in, ca, fr, br, id, jp` dan kode palsu `xx` semuanya `200 OK` dengan 0 hasil, tanpa error. Daftar 54 negara di `Country.supported` diambil dari daftar NewsAPI dan tidak bisa diverifikasi lewat error; UI menampilkan empty state yang jelas.
2. `everything` di plan ini memfilter setelah paging: `publishedAt` penuh (20/20), `relevancy` halaman pendek (mis. 8 dan 5 dari 20), `popularity` bisa kosong (query "apple") tetapi berisi untuk query lain ("iphone duo"). Karena itu `hasMore` memakai `totalResults`, bukan jumlah yang dikembalikan.
3. `everything` tanpa `q` → HTTP 400 `parametersMissing`.
4. `everything` tanpa `language` mengembalikan artikel semua bahasa (terutama terlihat pada Newest).

## 6. Belum dikerjakan
- Filter `language` untuk search.
- Menyimpan negara/kategori terakhir yang dipilih antar-peluncuran.
