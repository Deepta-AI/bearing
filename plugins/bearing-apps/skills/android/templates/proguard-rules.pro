# __REPO_NAME__ R8 rules. Release builds run with full mode (R8's default
# since AGP 8.0). Retrofit, OkHttp, Hilt, Tink and kotlinx.serialization
# (1.5.0 and later) ship their own consumer rules, so this file stays
# nearly empty: a rule here is added for one class the bundled rules miss,
# after a release build shows the crash, never as a package wildcard.
# `-keep class com.example.app.** { *; }` switches R8 off for the whole
# package; the r8-analyzer skill (android/skills) ranks it the worst rule.

# Retrofit reads generic signatures and annotations at runtime.
-keepattributes *Annotation*, InnerClasses, Signature

# kotlinx.serialization: the bundled rules cover @Serializable classes and
# their generated serialisers. The one case they miss is a companion object
# with a custom name; that class gets its own conditional rule:
# -if @kotlinx.serialization.Serializable class com.example.app.data.network.SomeDto
# -keepclassmembers class com.example.app.data.network.SomeDto {
#     static com.example.app.data.network.SomeDto$Named Named;
# }

# Keep line numbers for readable crash reports; the mapping file de-obfuscates.
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile
