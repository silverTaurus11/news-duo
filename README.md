# Briefly

Aplikasi berita SwiftUI untuk **iPhone Duo** (juga berjalan di iPhone biasa dan iPad), memakai [NewsAPI](https://newsapi.org).

- **List + detail:** di layar dalam Duo, list di kiri dan detail di kanan. Di layar luar, satu layar dengan navigasi push.
- **Top headlines:** pilih negara (bendera saja) dan kategori.
- **Search:** cari semua artikel dengan urutan Relevancy, Popularity, atau Newest.
- **Save / like:** tombol ❤︎ di list (swipe) dan di detail, plus tab **Saved**. Tersimpan lokal dan bisa dibaca offline.
- **Lazy load:** 10 artikel per halaman, dengan indikator loading, pesan error + coba lagi, dan penanda akhir data.

**Isi dokumen ini**

1. [Mulai cepat](#mulai-cepat)
2. [Bagaimana app membedakan mode Duo dan single screen](#bagaimana-app-membedakan-mode-duo-dan-single-screen)
3. [Panduan mengembangkan untuk iPhone Duo](#panduan-mengembangkan-untuk-iphone-duo)
4. [Fitur dan cara kerjanya](#fitur-dan-cara-kerjanya)
5. [Arsitektur, batasan NewsAPI, dan test](#arsitektur)

Dokumen lain: [docs/STRATEGY.md](docs/STRATEGY.md) berisi alasan di balik keputusan arsitektur.

---

## Mulai cepat

**Kebutuhan:** Xcode 27 (target iOS 27.0). Untuk menjalankan di simulator **iPhone Duo** perlu Xcode 27.1 atau lebih baru dan runtime khusus Duo; lihat [persiapan alat](#1-persiapan-alat).

1. Buka `news-duo.xcodeproj`, pilih scheme `news-duo`, lalu jalankan di simulator.
2. Isi API key NewsAPI. Dua cara, dicari berurutan (lihat [AppConfig.swift](news-duo/App/AppConfig.swift)):
   - env var `NEWS_API_KEY` di *Edit Scheme ▸ Run ▸ Arguments*, atau
   - salin [Secrets.example.plist](Secrets.example.plist) ke `news-duo/Secrets.plist` lalu isi key-nya. File itu ada di `.gitignore`, jadi tidak ikut ter-commit.
3. Tanpa key, app tetap jalan dengan **data demo** (subtitle "Demo data").

> Key yang dikompilasi ke app bisa diekstrak dari binary. Untuk app yang dirilis, arahkan request lewat backend Anda sendiri.

**Menjalankan test** (77 unit test, Swift Testing):

```bash
xcodebuild test -project news-duo.xcodeproj -scheme news-duo -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:news-duoTests
```

Proyek ini sudah dibangun dan dites dengan Xcode 27.0, 27.1, dan 27.2 beta.

---

## Bagaimana app membedakan mode Duo dan single screen

**Tidak ada kode yang mengecek "ini Duo atau bukan".** Tidak ada `if isDuo`, tidak ada model perangkat, tidak ada dua layout. Ada satu hierarki view, dan perbedaannya diputuskan **sistem** lewat horizontal size class, sesuai HIG (layar luar = *compact width*, layar dalam = *regular width*).

| Layar | Lebar | Yang tampil |
|---|---|---|
| Duo layar **dalam**, iPad | regular | **Dua pane**: list kiri, detail kanan |
| Duo layar **luar**, iPhone biasa | compact | **Satu pane**: list, tap baris membuka detail (push) |

Semua perbedaan itu berasal dari satu komponen, `NavigationSplitView`, yang hanya dipakai di satu tempat.

```
                       ┌──────────────────────────┐
                       │      ArticlesSplitView   │
                       │   NavigationSplitView    │
                       └────────────┬─────────────┘
              regular width         │          compact width
     (Duo layar dalam, iPad)        │   (Duo layar luar, iPhone)
   ┌──────────────┬───────────────┐ │ ┌──────────────┐    ┌──────────────┐
   │ ArticleList  │ ArticleDetail │ │ │ ArticleList  │ →  │ ArticleDetail│
   │ (kiri)       │ (kanan)       │ │ │ (root stack) │tap │ (di-push)    │
   └──────────────┴───────────────┘ │ └──────────────┘    └──────────────┘
    tap baris = ganti isi kanan     │   tap baris = push, back = kembali
```

### Class dan fungsi yang berperan

| Class / fungsi | Peran |
|---|---|
| **`ArticlesSplitView.body`** ([:17](news-duo/Presentation/Root/ArticlesSplitView.swift:17)) | Satu-satunya tempat yang memilih dua pane atau satu pane. Kolom pertama (`sidebar`) berisi list, kolom kedua (`detail`, [:20](news-duo/Presentation/Root/ArticlesSplitView.swift:20)) berisi artikel atau placeholder "Select an Article" (hanya terlihat di dua pane). |
| `columnVisibility = .all` ([:14](news-duo/Presentation/Root/ArticlesSplitView.swift:14)) | Di layar lebar, list selalu terlihat. Tidak berpengaruh di compact. |
| `.navigationSplitViewStyle(.balanced)` ([:32](news-duo/Presentation/Root/ArticlesSplitView.swift:32)) dan `.navigationSplitViewColumnWidth` ([:19](news-duo/Presentation/Root/ArticlesSplitView.swift:19)) | Detail mengecil mengikuti list; lebar kolom list 320–460. |
| **`ArticleListView`**, `List(selection:)` ([:15](news-duo/Presentation/Components/ArticleListView.swift:15)) | `selection` adalah kontrak list dan detail. Dua pane: mengganti isi pane kanan. Satu pane: mendorong (push) detail. Kodenya sama untuk kedua mode. |
| **`NewsFeedScreen`** ([:7](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift:7)) dan **`SavedScreen`** | Memegang `@State selection` dan meneruskannya ke `ArticlesSplitView`. Search, chip filter, dan tombol negara ada di kolom list, jadi tampil di kedua mode tanpa cabang kode. |
| **`ArticleDetailView`** ([.toolbar :47](news-duo/Presentation/Detail/ArticleDetailView.swift:47)) | Toolbar Save/Share menempel ke kolom detail. `.frame(maxWidth: 720)` ([:42](news-duo/Presentation/Detail/ArticleDetailView.swift:42)) menjaga teks tetap nyaman di pane lebar. |
| **`RootView`** ([TabView :9](news-duo/Presentation/Root/RootView.swift:9)) | `TabView` standar (News, Saved). Tidak ada tab bar custom. |

---

## Panduan mengembangkan untuk iPhone Duo

Rangkuman hal yang perlu diperhatikan. Sumbernya dokumen Apple [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) dan [HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), ketersediaan API diperiksa langsung di SDK Xcode 27.1, dan bagian yang sudah dicoba di proyek ini ditandai **(diverifikasi)**.

### 1. Persiapan alat

**Xcode dan runtime.** iPhone Duo memakai runtime khusus, bukan runtime iOS biasa:

| Runtime | Tipe perangkat | Bisa menjalankan Duo? |
|---|---|---|
| iOS 27.1 (24A94401) | hanya **iPhone Duo** | **Ya** |
| iOS 27.0 dan iOS 27.2 (umum) | 62 tipe (iPhone, iPad) | **Tidak**: membuat perangkat Duo ditolak (`Incompatible device`) |

Di mesin pengembangan ini hal itu diverifikasi. Dengan Xcode 27.1, `xcodebuild -downloadPlatform iOS` mengunduh runtime Duo (sekitar 7,9 GB). Dengan Xcode 27.2, perintah yang sama mengunduh runtime umum 27.2 (8,2 GB) yang **tidak** menjalankan Duo.

Membuat perangkat dan menjalankan app:

```bash
xcrun simctl create "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1
```

Karena deployment target proyek 27.0, app boleh dibangun dengan SDK yang lebih baru (27.1 atau 27.2) lalu dijalankan di runtime Duo 27.1. **(diverifikasi)**

**Dua layar, satu simulator.** Duo punya dua display. Di simulator keduanya terlihat sebagai framebuffer terpisah (layar luar sekitar 1398×2034 px, layar dalam 2007×2853 px). Yang tidak aktif tampil **hitam**, jadi jangan salah mengira app gagal jalan:

```bash
xcrun simctl io <udid> enumerate                                # daftar port display beserta UUID-nya
xcrun simctl io <udid> screenshot --display=<UUID-port> out.png # tangkap salah satu layar
```

UUID port berubah setelah simulator di-reboot, jadi jalankan `enumerate` lagi.

**Pose (tertutup, terbuka, terlipat sebagian) hanya bisa diatur dari Device Hub.** `simctl` tidak punya perintah untuk itu. Device Hub ada di `Xcode.app/Contents/Applications/DeviceHub.app`.

**Ketersediaan API.** Sebagian API Duo baru ada di iOS 27.1, sedangkan deployment target proyek ini 27.0, jadi bungkus dengan `#available(iOS 27.1, *)`:

| API | Ketersediaan |
|---|---|
| `visibilityPriority`, `presentationPlacement`, `ToolbarOverflowMenu` | iOS 27.0 |
| `toolbarVerticalBehavior`, `toolbarVerticalCompressionBehavior`, `axisBehavior`, `toolbarVerticalEdge` | iOS 27.1 |
| `ArrangementView`, `GeometryProxy.reservedRegions(...)` | iOS 27.1 |

Bangun dengan Xcode 26 atau lebih baru agar konten memakai seluruh layar (termasuk di bawah status bar dan kamera).

### 2. Aturan layout

- **Adaptif, bukan per perangkat.** Pakai size class. Jangan memutuskan layout dari `userInterfaceIdiom` atau orientasi; Apple menyebut keduanya secara eksplisit sebagai hal yang dihindari.
- **Ukur dari container, bukan dari layar.** Hitung layout dari bounds scene atau view pemuatnya. Hindari lebar dan tinggi tetap.
- **Utamakan container sistem:** `NavigationSplitView`, `TabView`, `NavigationStack`, dan `ArrangementView`. Semuanya otomatis menyesuaikan layar luar, layar dalam, dan area lipatan. Itu sebabnya app ini tidak punya layout khusus Duo.
- **Konten mendapat lebih sedikit lebar di layar luar.** Di layar luar, jam, sinyal, tab bar, dan toolbar pindah ke kolom vertikal di kanan **(diverifikasi)**, sehingga area konten menyempit. Jangan mengandalkan lebar layar penuh.
- **Konten yang di-scroll tidak perlu dipindah dari area lipatan.** Feed, dokumen, dan list sudah beradaptasi lewat scroll.
- **Grid: gunakan jumlah kolom genap** supaya terbagi rapi oleh lipatan (saran HIG).
- **Ubah seperlunya.** Pindahkan hanya elemen yang memang perlu, dan jaga ukuran teks dan kontrol tetap konsisten saat view di-resize.

### 3. Bar vertikal (bagian yang paling sering terlewat)

Bar (navigation bar, toolbar, tab bar) tampil **vertikal** di layar luar saat ditutup, dan di beberapa konteks di layar dalam:

| Konteks | Presentasi bar |
|---|---|
| Layar luar (tertutup) | vertikal |
| Split view: sidebar / content | horizontal |
| Split view: **detail** | **vertikal** |
| Inspector | horizontal |
| Sheet di layar luar | vertikal secara default (matikan dengan `toolbarVerticalBehavior`) |
| Sheet di layar dalam | tengah/leading horizontal; trailing vertikal (atur dengan `presentationPlacement`) |

Aturan yang harus dipatuhi:

- **Setiap item toolbar harus punya ikon *dan* judul.** Bar vertikal hanya menampilkan ikon. Menurut Apple, item **hanya-judul** dan item **custom view** tidak ditampilkan di bar vertikal. Judul tetap dipakai di overflow menu dan VoiceOver.
- **Pasang `.toolbar` pada `NavigationStack` atau `NavigationSplitView`.** Jangan membuat bar custom dari `UIToolbar`, `UINavigationBar`, atau `UITabBar`.
- **Susun item.** Bagian atas sumbu vertikal untuk navigasi utama (Back, Close), lalu aksi yang menonjol (Done). Untuk item navigasi yang menonjol pakai `ToolbarItemPlacement.topBarPinnedTrailing`, untuk Back/Close custom pakai `.cancellationAction`.
- **Kelola overflow.** Ruang bar vertikal terbatas. Beri `visibilityPriority` agar item penting tidak masuk overflow lebih dulu, atau sisipkan `ToolbarOverflowMenu` sendiri. Untuk app yang berfokus pada navigasi, tab bar dipertahankan dan item toolbar pindah ke overflow (default); untuk app yang berfokus pada tugas, atur dengan `toolbarVerticalCompressionBehavior`.
- **Gambar hero** yang harus terlihat sampai ke bawah bar vertikal: pakai `backgroundExtensionEffect()`. Untuk mengetahui bar sedang vertikal atau tidak di view custom, baca environment `toolbarVerticalEdge`.

Contoh dari proyek ini, [ArticleDetailView.swift:47](news-duo/Presentation/Detail/ArticleDetailView.swift:47): ikon + judul di setiap item, Save lebih penting daripada Share:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button { Task { await saved.toggle(article) } } label: {
            Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "heart.fill" : "heart")
        }
    }
    .visibilityPriority(.high)

    ToolbarItem(placement: .primaryAction) {
        ShareLink(item: article.url) { Label("Share", systemImage: "square.and.arrow.up") }
    }
    .visibilityPriority(.low)
}
```

**Jebakan yang ditemukan di proyek ini (diverifikasi):**

- **Ikon berupa `Text` diabaikan.** Toolbar hanya menganggap `Image` sebagai ikon `Label`. Emoji sebagai `Text` tampil sebagai teks di bar horizontal tetapi tidak punya ikon untuk bar vertikal.
- **Toolbar memaksa `Image` menjadi template.** Ikon berwarna (misalnya bendera) berubah jadi siluet hitam. `.renderingMode(.original)` di SwiftUI tidak dihormati; yang berhasil adalah menandai `UIImage`-nya `.alwaysOriginal`. Lihat [FlagIcon.swift](news-duo/Presentation/Components/FlagIcon.swift), yang dipakai tombol negara di [NewsFeedScreen.swift](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift).
- **Sheet ikut bar vertikal di layar luar.** Tombol "Done" di [CountryPickerView.swift](news-duo/Presentation/Components/CountryPickerView.swift) sengaja diberi ikon `checkmark`.

### 4. Area lipatan dan kamera: *reserved regions*

Saat Duo terlipat sebagian, layar dalam terbagi oleh **area lipatan**. Kamera menutupi sebagian layar (**occlusion**). iOS menyatakan keduanya sebagai *reserved region*:

| Jenis | Arti | Aktif kapan |
|---|---|---|
| `division` | area lipatan yang membagi view besar | hanya saat terlipat sebagian |
| `occlusion` | kamera menutupi konten | kamera luar selalu; kamera dalam hanya saat dipakai |

Setiap region punya `frame`, `margins`, dan status aktif atau tidak (query bisa menyertakan yang tidak aktif). Di SwiftUI:

```swift
GeometryReader { proxy in
    let regions = proxy.reservedRegions(kind: ..., options: ..., layoutDirectionBehavior: ...)
    // sesuaikan posisi view berdasarkan regions[i].frame
}
```

**Kapan perlu dipakai:** hanya untuk layout custom yang harus menghindari lipatan atau kamera secara manual. Container sistem (split view, tab bar, navigation stack, arrangement view) sudah menyesuaikan diri sendiri. Proyek ini tidak memakainya. `ArrangementView` (gaya `.split` atau `.overlay`) juga tidak dipakai; Apple menyarankan tidak menaruhnya di dalam `NavigationSplitView`, `List`, atau `ScrollView`.

### 5. Daftar uji

Dari checklist Apple, telusuri **setiap layar, sheet, dan popover** di setiap orientasi dan pose (tertutup, terbuka, terlipat sebagian):

- [ ] View ter-resize dengan baik saat perangkat dibuka, ditutup, dan diputar.
- [ ] Bar bersih di presentasi vertikal: tidak ada item yang hilang, urutan overflow masuk akal.
- [ ] Sheet dan popover tidak berpindah aneh saat perangkat dilipat atau dibuka.
- [ ] Tidak ada kontrol atau elemen penting yang jatuh di area lipatan (sulit dilihat dan disentuh).
- [ ] **State bertahan** saat berpindah layar: artikel yang dipilih, posisi scroll, teks search, filter. Ini belum diuji di proyek ini.

### 6. Status verifikasi proyek ini

| Sudah | Belum |
|---|---|
| Layar luar (tertutup) di simulator Duo: tab bar dan toolbar (bendera) tampil di bar vertikal kanan, daftar berita satu kolom, data live | Layar dalam (terbuka): dua pane list + detail |
| Bar Save/Share, Done, dan tombol negara memakai ikon + judul | Pose terlipat sebagian dan perilaku di area lipatan |
| Build dengan Xcode 27.0, 27.1, 27.2 beta; 77 test lulus di simulator Duo | Detail pane sebagai bar vertikal di layar dalam; sheet di layar dalam |
| | Kelangsungan state saat berpindah layar |
| | Grid negara memakai kolom adaptif (`.adaptive(minimum: 64)`); belum dipastikan genap, jadi belum tentu terbagi rapi oleh lipatan |

---

## Fitur dan cara kerjanya

### Filter dan search

| Kondisi | Endpoint | Kontrol |
|---|---|---|
| Search kosong | `/top-headlines` | tombol bendera (`CountryPickerView`) + chip kategori |
| Search di-submit | `/everything` | chip sortBy |

Search dijalankan saat **submit**, bukan tiap ketikan, karena paket developer NewsAPI dibatasi 100 request per hari. Bendera dibuat dari kode negara ISO sebagai emoji ([DisplayNames.swift](news-duo/Presentation/Components/DisplayNames.swift)), tanpa dependency.

### Lazy load (10 per halaman)

Logika di [NewsFeedViewModel](news-duo/Presentation/NewsFeed/NewsFeedViewModel.swift), tampilan di [NewsFeedScreen](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift).

| Bagian | Fungsi |
|---|---|
| Ukuran halaman | `NewsFeedViewModel.defaultPageSize = 10` |
| Pemicu | `loadMoreIfNeeded(after:)`: saat baris **terakhir** muncul, ambil halaman berikutnya via `loadMore()` |
| Halaman pertama | `loadFirstPage(clearingContent:)`: load awal, pull-to-refresh, dan ganti filter |
| Respons usang | penghitung `generation`: respons untuk query lama dibuang |
| Batas paket | `maximumResultsReached` diperlakukan sebagai akhir data, bukan error |

Baris setelah artikel terakhir (`footerState`, `loadMoreFooter` di [NewsFeedScreen.swift:147](news-duo/Presentation/NewsFeed/NewsFeedScreen.swift:147)):

| State | Tampilan |
|---|---|
| `.loading` | spinner + "Loading more…" |
| `.failed(alasan)` | ikon peringatan + **alasan** (mis. "You appear to be offline…") + tombol **Try Again**. Artikel yang sudah dimuat tetap ada; menggulir lagi tidak mengulang otomatis. |
| `.endOfList(pesan)` | "You're all caught up." (atau pesan batas paket) |
| `.hidden` | tidak ada baris |

State lain: load awal (spinner di tengah), gagal load awal (`ContentUnavailableView` + alasan + Try Again), hasil kosong (pesan sesuai search atau headlines), dan gagal refresh saat konten ada (alert; konten lama tetap). Gambar artikel ([RemoteImageView](news-duo/Presentation/Components/RemoteImageView.swift)): spinner saat mengunduh, `photo.badge.exclamationmark` jika gagal, `photo` jika tidak ada URL.

---

## Arsitektur

Clean Architecture; dependensi hanya mengarah ke dalam: `Presentation → Domain ← Data`.

```
news-duo/
├── App/            AppContainer (composition root), AppConfig (mencari API key)
├── Domain/         Entities (Article, ArticleQuery, Country, ...), protocol repository, use case
├── Data/           Network (endpoint, HTTP), DTO + mapper, repository (NewsAPI, demo, file JSON)
└── Presentation/   Root, NewsFeed, Saved, Detail, Components
```

Alur data: `View → ViewModel → UseCase → Repository (protocol) → Data → NewsAPI / file JSON`. Artikel yang di-save disimpan sebagai satu file JSON di `Application Support` ([FileSavedArticlesRepository](news-duo/Data/Repositories/FileSavedArticlesRepository.swift)), sehingga bisa dibaca offline tetapi tidak tersinkron antar perangkat.

## Batasan NewsAPI

Diperiksa dengan paket developer pada 2026-09-20:

- `top-headlines` hanya berisi untuk `us`; negara lain mengembalikan 0 hasil tanpa error (app menampilkan empty state). Jadi picker negara belum banyak berguna dengan key ini.
- `everything` bisa mengembalikan halaman pendek atau kosong (terutama Popularity), sehingga `hasMore` dihitung dari `totalResults`, bukan dari jumlah yang dikembalikan.
- Search tanpa filter bahasa mengembalikan artikel semua bahasa.
- Maksimum 100 hasil per query dan 100 request per hari.

## Test

77 unit test (Swift Testing) mencakup mapper DTO, endpoint, repository (HTTP di-stub), penyimpanan file, use case, dan ViewModel (paging, filter, search, footer, respons usang). Tidak ada UI test otomatis.
