FROM openjdk:8-jdk-slim
# Initial Command run as `root`.

ADD https://raw.githubusercontent.com/circleci/circleci-images/master/android/bin/circle-android /bin/circle-android
RUN chmod +rx /bin/circle-android

# make Apt non-interactive
RUN echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90circleci \
  && echo 'DPkg::Options "--force-confnew";' >> /etc/apt/apt.conf.d/90circleci

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && mkdir -p /usr/share/man/man1 \
  && apt-get install -y \
    git apt sudo openssh-client ca-certificates gzip curl make unzip


# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8

RUN groupadd --gid 3434 circleci \
  && useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
  && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
  && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

USER circleci
ENV PATH /home/circleci/.local/bin:/home/circleci/bin:${PATH}

CMD ["/bin/sh"]

ENV HOME /home/circleci

ARG sdk_version=sdk-tools-linux-4333796.zip
ARG android_home=/opt/android/sdk

# SHA-256 92ffee5a1d98d856634e8b71132e8a95d96c83a63fde1099be3d86df3106def9

RUN sudo apt-get update && \
    sudo apt-get install --yes \
        wget xvfb lib32z1 lib32stdc++6 build-essential python3-pip \
        libcurl4-openssl-dev libglu1-mesa libxi-dev libxmu-dev \
        libglu1-mesa-dev && \
    sudo rm -rf /var/lib/apt/lists/*

# Download Google Cloud SDK
RUN curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-323.0.0-linux-x86_64.tar.gz > /tmp/google-cloud-sdk.tar.gz

# Install Google Cloud SDK
RUN tar -C ${HOME} -xvf /tmp/google-cloud-sdk.tar.gz && \
    .${HOME}/google-cloud-sdk/install.sh

# Install Ruby
RUN sudo apt-get update && \
    cd /tmp && wget -O ruby-install-0.6.1.tar.gz https://github.com/postmodern/ruby-install/archive/v0.6.1.tar.gz && \
    tar -xzvf ruby-install-0.6.1.tar.gz && \
    cd ruby-install-0.6.1 && \
    sudo make install && \
    ruby-install --cleanup ruby 2.6.1 && \
    rm -r /tmp/ruby-install-* && \
    sudo rm -rf /var/lib/apt/lists/*

ENV PATH ${HOME}/.rubies/ruby-2.6.1/bin:${PATH}
RUN echo 'gem: --env-shebang --no-rdoc --no-ri' >> ~/.gemrc && gem install bundler

# Download and install Android SDK
RUN sudo mkdir -p ${android_home} && \
    sudo chown -R circleci:circleci ${android_home} && \
    curl --silent --show-error --location --fail --retry 3 --output /tmp/${sdk_version} https://dl.google.com/android/repository/${sdk_version} && \
    unzip -q /tmp/${sdk_version} -d ${android_home} && \
    rm /tmp/${sdk_version}

# Set environmental variables
ENV ANDROID_HOME ${android_home}
ENV ADB_INSTALL_TIMEOUT 120
ENV PATH=${ANDROID_HOME}/emulator:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}
ENV PATH ${PATH}:/usr/local/gcloud/google-cloud-sdk/bin

RUN mkdir ~/.android && echo '### User Sources for Android SDK Manager' > ~/.android/repositories.cfg

RUN yes | sdkmanager --licenses && yes | sdkmanager --update

RUN sdkmanager \
  "tools" \
  "platform-tools" \
  "emulator"

RUN sdkmanager \
  "build-tools;29.0.3"

RUN sdkmanager "platforms;android-28"
RUN sdkmanager "platforms;android-29"
RUN sdkmanager \
  "build-tools;28.0.3"

RUN gem install fastlane -NV -v 2.135.0