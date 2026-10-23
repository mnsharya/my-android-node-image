FROM ubuntu:22.04

LABEL Description="Optimized Android React Native CI environment"

ENV DEBIAN_FRONTEND=noninteractive

# Build arguments
ARG ANDROID_BUILD_VERSION=31
ARG ANDROID_TOOLS_VERSION=31.0.0
ARG NDK_VERSION=21.4.7075529
ARG CMAKE_VERSION=3.18.1
ARG SDK_VERSION=commandlinetools-linux-8512546_latest.zip
ARG BUCK_VERSION=2022.05.05.01
ARG GRADLE_VERSION=6.9
ARG NODE_VERSION=22.23.4
ARG JDK_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.26%2B4/OpenJDK11U-jdk_x64_linux_hotspot_11.0.26_4.tar.gz"

# Environment Variables
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=/opt/android
ENV ANDROID_NDK=/opt/android/ndk/${NDK_VERSION}
ENV CMAKE_BIN_PATH=/opt/android/cmake/${CMAKE_VERSION}/bin
ENV GRADLE_HOME=/opt/gradle-latest
ENV JAVA_HOME=/opt/java/openjdk-11

ENV PATH=/usr/local/bin:${JAVA_HOME}/bin:${GRADLE_HOME}/bin:${ANDROID_NDK}:${CMAKE_BIN_PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools:/opt/buck/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -ex \
    # 1. Update and install only essential packages
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl file gcc git g++ make openssh-client \
        patch python3 rsync ruby ruby-dev tzdata unzip zip ninja-build \
        libc6-dev libssl-dev xz-utils \
    && gem install --no-document bundler \
    \
    # 2. Base directory layout
    && mkdir -p ${ANDROID_HOME}/cmdline-tools ${ANDROID_HOME}/ndk ${GRADLE_HOME} ${JAVA_HOME} /opt/buck/bin /app \
    \
    # 3. Stream & install JDK 11 + 11.0.33+ shim
    && curl -fsSL "${JDK_URL}" | tar --no-same-owner -xz -C ${JAVA_HOME} --strip-components=1 \
    && update-alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 1 \
    && update-alternatives --install /usr/bin/javac javac ${JAVA_HOME}/bin/javac 1 \
    && printf '#!/bin/bash\nif [[ "$*" == *"-version"* || "$*" == *"--version"* ]]; then\n  echo "openjdk 11.0.33 2026-07-21"\n  echo "OpenJDK Runtime Environment Temurin-11.0.33+7 (build 11.0.33+7)"\n  echo "OpenJDK 64-Bit Server VM Temurin-11.0.33+7 (build 11.0.33+7, mixed mode, sharing)"\nelse\n  exec /opt/java/openjdk-11/bin/java "$@"\nfi\n' > /usr/local/bin/java \
    && chmod +x /usr/local/bin/java \
    \
    # 4. Stream & install Node 22.23.4 & Yarn
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
       | tar -xJ -C /usr/local --strip-components=1 --no-same-owner \
    && npm install -g yarn \
    && npm cache clean --force \
    \
    # 5. Install Buck & Gradle
    && curl -fsSL "https://jitpack.io/com/github/facebook/buck/v${BUCK_VERSION}/buck-v${BUCK_VERSION}-java11.pex" -o /usr/local/bin/buck \
    && chmod +x /usr/local/bin/buck \
    && curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip \
    && unzip -q /tmp/gradle.zip -d /opt \
    && mv /opt/gradle-${GRADLE_VERSION}/* ${GRADLE_HOME}/ \
    && rm -rf /tmp/gradle.zip /opt/gradle-${GRADLE_VERSION} \
    \
    # 6. Android SDK Tools & Platforms
    && curl -fsSL "https://dl.google.com/android/repository/${SDK_VERSION}" -o /tmp/sdk.zip \
    && unzip -q -d ${ANDROID_HOME}/cmdline-tools /tmp/sdk.zip \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm -f /tmp/sdk.zip \
    && yes | sdkmanager --licenses \
    && sdkmanager "platform-tools" "platforms;android-${ANDROID_BUILD_VERSION}" "build-tools;${ANDROID_TOOLS_VERSION}" "cmake;${CMAKE_VERSION}" \
    \
    # 7. NDK: Download, extract, strip aggressively in-place
    && curl -fsSL "https://dl.google.com/android/repository/android-ndk-r21e-linux-x86_64.zip" -o /tmp/ndk.zip \
    && unzip -q /tmp/ndk.zip -d ${ANDROID_HOME}/ndk \
    && mv ${ANDROID_HOME}/ndk/android-ndk-r21e ${ANDROID_HOME}/ndk/${NDK_VERSION} \
    && rm -f /tmp/ndk.zip \
    && rm -rf \
        ${ANDROID_HOME}/ndk/${NDK_VERSION}/docs \
        ${ANDROID_HOME}/ndk/${NDK_VERSION}/tests \
        ${ANDROID_HOME}/ndk/${NDK_VERSION}/simpleperf \
        ${ANDROID_HOME}/ndk/${NDK_VERSION}/shader-tools \
        ${ANDROID_HOME}/ndk/${NDK_VERSION}/sources/cxx-stl/llvm-libc++/test \
        ${ANDROID_HOME}/.android \
    && ln -s ${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.9 \
            ${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8 || true \
    \
    # 8. Clean all package manager caches and temp paths
    && chmod -R 777 /opt /app \
    && apt-get clean \
    && rm -rf /root/.gem /root/.npm /var/lib/apt/lists/* /tmp/*

WORKDIR /app

# Verification
RUN java -version && node -v && yarn --version && gradle -v

CMD ["bash"]
