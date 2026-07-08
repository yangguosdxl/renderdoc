shopt -s expand_aliases

ANDROID_SDK='G:/Android/sdk-tools-windows-3859397/tools'
ANDROID_NDK='G:/Android/android-ndk-r14b-windows-x86_64/android-ndk-r14b'

JAVA_HOME='/G/Android/openjdk/jdk-17.0.8.101-hotspot'
CPP_PATH='/G/Android/android-ndk-r14b-windows-x86_64/android-ndk-r14b/toolchains/arm-linux-androideabi-4.9/prebuilt/windows-x86_64/bin'
CmakePath='/D/Program Files/Unity 2021.3.43f1/Editor/Data/PlaybackEngines/AndroidPlayer/SDK/cmake/3.22.1/bin/'
PATH=$MakePath:$JAVA_HOME/bin:$CmakePath:$PATH
echo $PATH


cmake -DBUILD_ANDROID=On -DANDROID_ABI=armeabi-v7a -G "Ninja" ..
ninja -j8