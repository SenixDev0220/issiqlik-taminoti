# Flutter registers plugins by name; retain the generated entry point.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Firebase and Android SDK artifacts provide their own consumer rules.
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
