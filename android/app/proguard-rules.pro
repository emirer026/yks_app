# =========================================================
# WorkManager - AGP 9 / R8 sıkı mod düzeltmesi
# =========================================================
# R8, hiçbir yerden doğrudan çağrılmadığını gördüğü için WorkManager'ın
# reflection ile açılışta aradığı Room veritabanı sınıfını "kullanılmıyor"
# sanıp siliyor. Bu da "Failed to create an instance of WorkDatabase"
# çökmesine yol açıyor (google_mobile_ads dahil birçok paket WorkManager
# kullanıyor). Bu sınıfları R8'in silmesini/yeniden adlandırmasını
# engelliyoruz.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
-dontwarn androidx.work.**

# WorkManager kendi içinde Room kullanıyor; Room da reflection ile
# üretilen "_Impl" sınıflarına ihtiyaç duyuyor, onları da koruyoruz.
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-dontwarn androidx.room.paging.**

# androidx.startup (InitializationProvider) - başlangıçta reflection ile
# çağrılan Initializer sınıflarını da koru.
-keep class * extends androidx.startup.Initializer
-dontwarn androidx.startup.**