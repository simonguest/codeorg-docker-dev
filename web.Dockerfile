FROM ubuntu:bionic

# Additional required packages
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm5 libgdbm-dev git chromium-browser parallel

# Set the non-root user for the container and switch
ARG UID
ARG GID
RUN apt-get -y install sudo
RUN groupadd -g ${GID} cdodev \
    && useradd -r -u ${UID} -g cdodev --shell /bin/bash --create-home cdodev \
    && echo 'cdodev ALL=NOPASSWD: ALL' >> /etc/sudoers \
    && chown -R cdodev /usr/local
USER cdodev

# Install rbenv
RUN sudo apt-get -y install rbenv \
    && mkdir -p "$(rbenv root)"/plugins \
    && git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build

# Install Ruby 2.7.5 and Bundler 2.3.22. Also replace the system ruby (required for RubyMine debugging).
RUN rbenv install 2.7.5 \
    && echo -n '\n# rbenv init\neval "$(rbenv init -)"\n' >> ~/.bashrc \
    && rbenv global 2.7.5 \
    && sudo rm /usr/bin/ruby \
    && sudo ln -s /home/cdodev/.rbenv/versions/2.7.5/bin/ruby /usr/bin/ruby

# Install Node 14.17.1
RUN sudo apt-get -y install nodejs npm \
    && npm install -g n \
    && n 14.17.1

# Install Yarn 1.22.5
RUN npm i -g yarn@1.22.5

# # Install ImageMagick
RUN sudo apt-get -y install libmagickwand-dev imagemagick

# # Install MySQL Native Client
RUN sudo apt-get -y install libsqlite3-dev libmysqlclient-dev mysql-client-core-5.7

# Install AWSCLI
RUN cd /home/cdodev \
    && if [ $(uname -m) = "aarch64" ]; then curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; else curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; fi \
    && unzip awscliv2.zip \
    && ./aws/install

# Add AWS_PROFILE env var
ENV AWS_PROFILE=cdo

# Add CHROME_BIN env var to bashrc
RUN echo -n '\n# Chromium Binary\nexport CHROME_BIN=/usr/bin/chromium-browser\n' >> ~/.bashrc

# Add Ruby binaries to path
RUN echo -n '\n# Add Ruby binaries on path\nexport PATH=$PATH:/home/cdodev/.rbenv/versions/2.7.5/bin\n' >> ~/.bashrc

# Make temporary directory and do a bundle install
RUN sudo mkdir -p /app/src
COPY src/Gemfile /app/src/.
COPY src/Gemfile.lock /app/src/.
COPY src/.ruby-version /app/src/.
RUN sudo chown -R cdodev /app
RUN cd /app/src \
    && eval "$(rbenv init -)" \
    && gem install bundler -v 2.3.22 \
    && bundle install

# Install node-pre-gyp (required for Web packaging)
RUN sudo apt install -y node-pre-gyp

# Install debugging tools
RUN sudo apt-get -y install gdb rsync lsof

# Install rbspy
RUN cd /home/cdodev \
    && if [ $(uname -m) = "aarch64" ]; then curl -L "https://github.com/rbspy/rbspy/releases/download/v0.12.1/rbspy-aarch64-musl.tar.gz" -o "rbspy.tar.gz"; else curl -L "https://github.com/rbspy/rbspy/releases/download/v0.12.1/rbspy-x86_64-musl.tar.gz" -o "rbspy.tar.gz"; fi \
    && tar -xvf ./rbspy.tar.gz \
    && chmod +x ./rbspy*musl \
    && sudo cp ./rbspy*musl /usr/local/bin
