# Briefly

Aplikasi berita SwiftUI untuk **iPhone Duo** (juga berjalan di iPhone biasa dan iPad), memakai [NewsAPI](https://newsapi.org).

- **List + detail**: di layar dalam Duo, list di kiri dan detail di kanan. Di layar luar, satu layar dengan navigasi push.
- **Save / like**: tombol ❤︎ di list (swipe), di detail, dan tab **Saved** (tersimpan lokal, bisa dibaca offline).
- **Top headlines**: pilih negara (bendera saja) dan kategori.
- **Search**: cari semua artikel (`/everything`) dengan urutan Relevancy / Popularity / Newest.
- **Lazy load**: 10 artikel per halaman, dengan indikator loading, pesan error + coba lagi, dan penanda akhir data.

Dokumen lain: [docs/STRATEGY.md](docs/STRATEGY.md) (keputusan arsitektur dan temuan HIG/NewsAPI).

## Menjalankan

Kebutuhan: Xcode 27 (target iOS 27.0).

1. Buka `news-duo.xcodeproj`, pilih scheme `news-duo`, jalankan di simulator.
2. Isi API key NewsAPI, salah satu cara (dicari berurutan, lihat [AppConfig.swift](news-duo/App/AppConfig.swift)):
   - env var `NEWS_API_KEY` di *Edit Scheme ▸ Run ▸ Arguments*, atau
   - salin [Secrets.example.plist](Secrets.example.plist) ke `news-duo/Secrets.plist` lalu isi key-nya. File itu ada di `.gitignore`, jadi tidak ikut ter-commit.
3. Tanpa key, app berjalan dengan data demo (subtitle "Demo data").

> Key yang dikompilasi ke app bisa diekstrak dari binary. Untuk app yang dirilis, arahkan request lewat backend Anda sendiri.

Menjalankan test:

```bash
xcodebuild test -project news-duo.xcodeproj -scheme news-duo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:news-duoTests
```

---

## Mode Duo vs single screen: class dan fungsi yang membedakan

### Prinsipnya

**Tidak ada kode yang mengecek "ini Duo atau bukan".** Tidak ada `if isDuo`, tidak ada model perangkat, tidak ada dua layout. Ada satu hierarki view, dan perbedaannya diputuskan oleh **sistem** lewat horizontal size class, sesuai HIG iPhone Duo (layar luar = *compact width*, layar dalam = *regular width*, jangan desain per pose).

| Layar | Lebar | Yang tampil |
|---|---|---|
| Duo layar **dalam**, iPad | regular | **Dua pane**: list kiri, detail kanan |
| Duo layar **luar**, iPhone biasa | compact | **Satu pane**: list, tap baris membuka detail (push) |

Semua perbedaan itu berasal dari satu komponen, `NavigationSplitView`, yang hanya dipakai di satu tempat.

### Class dan fungsi

**1. `ArticlesSplitView`, `body`** ([ArticlesSplitView.swift:17](news-duo/Presentation/Root/ArticlesSplitView.swift:17)): satu-satunya tempat yang menentukan layout dua pane atau satu pane.

| Baris | Yang dilakukan |
|---|---|
| [`:17`](news-duo/Presentation/Root/ArticlesSplitView.swift:17) `NavigationSplitView(columnVisibility:)` | Kolom pertama (`sidebar`) = list, kolom kedua (`detail`) = artikel. Regular width: keduanya tampil. Compact width: sistem menciutkan jadi satu stack dengan list sebagai root. |
| [`:14`](news-duo/Presentation/Root/ArticlesSplitView.swift:14) `columnVisibility = .all` | Di layar lebar, list selalu terlihat (tidak disembunyikan saat portrait). Tidak berpengaruh di compact. |
| [`:32`](news-duo/Presentation/Root/ArticlesSplitView.swift:32) `.navigationSplitViewStyle(.balanced)` | Detail mengecil mengikuti list, tidak menimpa list. |
| [`:19`](news-duo/Presentation/Root/ArticlesSplitView.swift:19) `.navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)` | Lebar kolom list di layar lebar. |
| [`:21-29`](news-duo/Presentation/Root/ArticlesSplitView.swift:21) blok `detail` | Menampilkan `ArticleDetailView`, atau `ContentUnavailableView("Select an Article")` jika belum ada yang dipilih. Placeholder ini hanya terlihat di mode dua pane; di mode satu pane kolom detail belum tampil sebelum ada pilihan. |

**2. `ArticleListView`, `List(selection:)`** ([ArticleListView.swift:15](news-duo/Presentation/Components/ArticleListView.swift:15)): `selection` adalah kontrak antara list dan detail. Kode ini sama untuk kedua mode, tetapi efeknya berbeda:

- dua pane: mengubah `selection` mengganti isi pane kanan;
- satu pane: mengubah `selection` mendorong (push) detail ke atas list.

**3. `NewsFeedScreen`** ([NewsFeedScreen.swift:7](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift:7)) dan **`SavedScreen`** ([SavedScreen.swift:6](news-duo/Presentation/Saved/SavedScreen.swift:6)): memegang `@State selection` dan meneruskannya ke `ArticlesSplitView(articles:selection:)` ([NewsFeedScreen.swift:11](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift:11)). `ArticlesSplitView` mencari artikelnya (`articles.first { $0.id == selection }`) untuk kolom detail. Search, chip filter, dan tombol negara berada di kolom list, jadi tampil di kedua mode tanpa cabang kode.

**4. `ArticleDetailView`** ([ArticleDetailView.swift](news-duo/Presentation/Detail/ArticleDetailView.swift)):

- `.toolbar` ([:47](news-duo/Presentation/Detail/ArticleDetailView.swift:47)) dengan tombol Save dan Share menempel ke kolom detail. Di satu pane tombol itu muncul di navigation bar layar yang di-push (bersama tombol back). Di dua pane muncul di bar pane kanan.
- `.frame(maxWidth: 720)` ([:42](news-duo/Presentation/Detail/ArticleDetailView.swift:42)) menjaga panjang baris teks tetap nyaman saat pane kanan lebar.

**5. `RootView`** ([RootView.swift:9](news-duo/Presentation/Root/RootView.swift:9)): `TabView` standar (News, Saved). Menurut HIG, tab bar dan toolbar komponen standar dipindah sistem ke sisi vertikal di Duo, jadi tidak ada bar custom.

### Alur

```
                       ┌──────────────────────────┐
                       │      ArticlesSplitView   │
                       │   NavigationSplitView    │
                       └────────────┬─────────────┘
              regular width         │          compact width
     (Duo layar dalam, iPad)        │   (Duo layar luar, iPhone)
                                    │
   ┌──────────────┬───────────────┐ │ ┌──────────────┐    ┌──────────────┐
   │ ArticleList  │ ArticleDetail │ │ │ ArticleList  │ →  │ ArticleDetail│
   │ (kiri)       │ (kanan)       │ │ │ (root stack) │tap │ (di-push)    │
   └──────────────┴───────────────┘ │ └──────────────┘    └──────────────┘
    tap baris = ganti isi kanan     │   tap baris = push, back = kembali
```

### API iPhone Duo dan penyesuaian bar vertikal

Xcode 27.1 (iOS 27.1) menambah API Duo di SwiftUI: `ArrangementView`, `GeometryProxy.reservedRegions(...)`, `toolbarVerticalEdge`, `toolbarVerticalBehavior`, `toolbarVerticalCompressionBehavior`, dan `axisBehavior`. Yang **dipakai** dan yang **tidak**:

| Hal | Keputusan |
|---|---|
| `NavigationSplitView` | Dipakai. Dokumen Apple ("Preparing your app for iPhone Duo") menyebut split view, tab bar, dan navigation stack sebagai container sistem yang otomatis menyesuaikan layar luar/dalam dan area lipatan. |
| `ArrangementView` | Tidak dipakai. Belum perlu, dan Apple menyarankan tidak menaruhnya di dalam `NavigationSplitView`, `List`, atau `ScrollView`. |
| `reservedRegions` | Tidak dipakai. Tidak ada layout custom di sekitar lipatan. Baru relevan jika kelak ada konten yang harus menghindari area lipatan secara manual. |
| Bar vertikal | **Disesuaikan.** Di layar luar (dan di sisi pane detail) bar tampil vertikal dan hanya menampilkan ikon. Item tanpa ikon tidak ditampilkan di bar vertikal. |

Penyesuaian bar vertikal:

- [NewsFeedScreen.swift](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift): tombol negara adalah `Label` dengan **ikon `Image`** (bendera, dibuat oleh [FlagIcon.swift](news-duo/Presentation/Components/FlagIcon.swift)) dan judul nama negara. Sebelumnya berupa teks emoji saja, yang tidak akan tampil di bar vertikal. Ikon ditandai `.alwaysOriginal` karena toolbar memaksa `Image` menjadi template (bendera jadi siluet hitam).
- [CountryPickerView.swift](news-duo/Presentation/Components/CountryPickerView.swift): tombol Done punya ikon `checkmark` (sheet di layar luar memakai bar vertikal).
- [ArticleDetailView.swift](news-duo/Presentation/Detail/ArticleDetailView.swift): Save dan Share punya ikon dan judul, dengan `visibilityPriority` (Save `.high`, Share `.low`) agar Save tidak pindah ke overflow lebih dulu.

### Status verifikasi

Diuji di simulator **iPhone Duo (iOS 27.1)** dengan Xcode 27.1:

- **Layar luar (tertutup): terverifikasi.** Tab bar (News/Saved) dan toolbar (bendera) tampil di bar vertikal di sisi kanan; daftar berita satu kolom.
- **Layar dalam (terbuka), pose terlipat sebagian, dan perilaku di sekitar lipatan: belum diverifikasi.** Simulator tidak menyediakan perintah CLI untuk mengubah pose; pose diatur dari Device Hub.

Persiapan yang dibutuhkan untuk menguji Duo:

```bash
xcodebuild -downloadPlatform iOS
```

Perintah itu (dijalankan dengan Xcode 27.1 sebagai `DEVELOPER_DIR`) mengunduh runtime iOS 27.1 (sekitar 8 GB); tipe simulator "iPhone Duo" hanya tersedia di runtime tersebut. Proyek tetap bisa dibangun dengan Xcode 27.0 (deployment target 27.0, API yang dipakai ada di SDK 27.0), tetapi simulator Duo membutuhkan 27.1.

---

## Lazy load (10 per halaman)

Logika ada di [NewsFeedViewModel](news-duo/Presentation/NewsFeed/NewsFeedViewModel.swift); tampilannya di [NewsFeedScreen](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift).

| Bagian | Fungsi |
|---|---|
| Ukuran halaman | `NewsFeedViewModel.defaultPageSize = 10` |
| Pemicu | `loadMoreIfNeeded(after:)`: saat baris **terakhir** muncul, ambil halaman berikutnya via `loadMore()` |
| Halaman pertama | `loadFirstPage(clearingContent:)`: dipakai untuk load awal, pull-to-refresh, dan ganti filter |
| Respons usang | penghitung `generation`: respons untuk query lama dibuang |
| Batas paket | `maximumResultsReached` ditangani sebagai akhir data, bukan error |

Yang ditampilkan `NewsFeedViewModel.footerState` di baris setelah artikel terakhir (`loadMoreFooter`, [NewsFeedScreen.swift:141](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift:141)):

| State | Tampilan |
|---|---|
| `.loading` | spinner + "Loading more…" |
| `.failed(alasan)` | ikon peringatan + **alasan** (mis. "You appear to be offline…") + tombol **Try Again**. Artikel yang sudah dimuat tetap ada; menggulir lagi tidak mengulang otomatis. |
| `.endOfList(pesan)` | "You're all caught up." (atau pesan batas paket) |
| `.hidden` | tidak ada baris |

State lain: load awal (spinner di tengah), gagal load awal (`ContentUnavailableView` + alasan + Try Again), hasil kosong (pesan sesuai search atau headlines), gagal refresh saat konten ada (alert, konten lama tetap). Gambar artikel ([RemoteImageView](news-duo/Presentation/Components/RemoteImageView.swift)): spinner saat mengunduh, ikon `photo.badge.exclamationmark` jika gagal, ikon `photo` jika tidak ada URL.

## Arsitektur

Clean Architecture, dependensi hanya mengarah ke dalam: `Presentation → Domain ← Data`.

```
news-duo/
├── App/            AppContainer (composition root), AppConfig (mencari API key)
├── Domain/         Entities (Article, ArticleQuery, Country, ...), protocol repository, use case
├── Data/           Network (endpoint, HTTP), DTO + mapper, repository (NewsAPI, demo, file JSON)
└── Presentation/   Root, NewsFeed, Saved, Detail, Components
```

Alur data: `View → ViewModel → UseCase → Repository (protocol) → Data → NewsAPI / file JSON`. Detail dan alasan keputusan ada di [docs/STRATEGY.md](docs/STRATEGY.md).

## Filter dan search

| Kondisi | Endpoint | Kontrol |
|---|---|---|
| Search kosong | `/top-headlines` | tombol bendera (`CountryPickerView`) + chip kategori |
| Search di-submit | `/everything` | chip sortBy |

Search dijalankan saat **submit**, bukan tiap ketikan, karena paket developer NewsAPI dibatasi 100 request/hari. Bendera dibuat dari kode negara ISO sebagai emoji ([DisplayNames.swift](news-duo/Presentation/Components/DisplayNames.swift)), tanpa dependency.

## Batasan NewsAPI (paket developer, diperiksa 2026-09-20)

- `top-headlines` hanya berisi untuk `us`; negara lain mengembalikan 0 hasil tanpa error (app menampilkan empty state).
- `everything` bisa mengembalikan halaman pendek atau kosong (terutama Popularity), sehingga `hasMore` dihitung dari `totalResults`.
- Search tanpa filter bahasa mengembalikan artikel semua bahasa.
- Maksimum 100 hasil per query dan 100 request per hari.

## Test

77 unit test (Swift Testing) mencakup mapper DTO, endpoint, repository (HTTP di-stub), penyimpanan file, use case, dan ViewModel (paging, filter, search, footer, respons usang). Tidak ada UI test otomatis.
