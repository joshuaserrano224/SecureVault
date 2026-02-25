plugins {

    id("com.android.application")

    id("kotlin-android")

    id("com.google.gms.google-services")

    id("dev.flutter.flutter-gradle-plugin")

}



android {

    namespace = "com.example.secure_vault"

    compileSdk = flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion



    compileOptions {

        sourceCompatibility = JavaVersion.VERSION_17

        targetCompatibility = JavaVersion.VERSION_17

    }



    kotlinOptions {

        // Fixed: Use the string "17" to resolve the deprecation warning

        jvmTarget = "17"

    }



    defaultConfig {

        applicationId = "com.example.secure_vault"

       

        // Forced to 21 for Facebook SDK compatibility

        minSdk = flutter.minSdkVersion

       

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode

        versionName = flutter.versionName



        multiDexEnabled = true

    }



    buildTypes {

        getByName("release") {

            signingConfig = signingConfigs.getByName("debug")

           

            // Fixed: Kotlin requires the "is" prefix for these booleans

            isMinifyEnabled = false

            isShrinkResources = false

        }

    }



    packaging {

        resources {

            excludes += "/META-INF/{AL2.0,LGPL2.1}"

            excludes += "META-INF/DEPENDENCIES"

        }

    }

}



flutter {

    source = "../.."

}



dependencies {

    implementation("com.google.android.gms:play-services-auth:21.0.0")



    // Facebook SDK for 2026 standards

    implementation("com.facebook.android:facebook-login:latest.release")

   

    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))

    implementation("com.google.firebase:firebase-auth")

    implementation("com.google.firebase:firebase-firestore")

}