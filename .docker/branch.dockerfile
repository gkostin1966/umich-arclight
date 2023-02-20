FROM ruby:2.7

ARG UNAME=app
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND noninteractive

RUN curl https://deb.nodesource.com/setup_12.x | bash
RUN curl https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends vim nodejs yarn rclone

#RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
#RUN apt-get install -yqq --no-install-recommends ./google-chrome-stable_current_amd64.deb

RUN wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb
RUN apt-get install -yqq --no-install-recommends ./wkhtmltox_0.12.6.1-2.bullseye_amd64.deb

ENV APP_PATH /opt/app
RUN groupadd -g $GID -o $UNAME
RUN useradd -m -d $APP_PATH -u $UID -g $GID -o -s /bin/bash $UNAME

ENV DATA_PATH /var/opt/app
RUN mkdir -p $DATA_PATH && chown $UID:$GID $DATA_PATH

ENV BUNDLE_PATH /var/opt/app/gems
RUN mkdir -p $BUNDLE_PATH && chown $UID:$GID $BUNDLE_PATH

ENV FINDING_AID_DATA /var/opt/app/data
RUN mkdir -p $FINDING_AID_DATA && chown $UID:$GID $FINDING_AID_DATA

COPY --chown=$UID:$GID . $APP_PATH
COPY --chown=$UID:$GID ./sample-ead $FINDING_AID_DATA

USER $UNAME
WORKDIR $APP_PATH

RUN rm *.lock
RUN gem install 'bundler:~>2.2.21'
RUN bundle config --local build.sassc --disable-march-tune-native
RUN bundle install
RUN yarn install

ENV RAILS_ENV production
RUN bundle exec rails assets:precompile

CMD ["bundle", "exec", "bin/rails", "s", "-b", "0.0.0.0"]
