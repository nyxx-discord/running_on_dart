FROM google/dart:2.12.0-51.0.dev

WORKDIR /app

RUN git clone https://github.com/l7ssha/nyxx.git

WORKDIR /app/nyxx
RUN git fetch
RUN git checkout 1.1

WORKDIR /app/nyxx/nyxx
RUN dartdoc --enable-experiment=non-nullable

WORKDIR /app/nyxx/nyxx.commander
RUN dartdoc --enable-experiment=non-nullable

WORKDIR /app/nyxx/nyxx.extensions
RUN dartdoc --enable-experiment=non-nullable

WORKDIR /app/bot

ADD pubspec.* /app/bot/
RUN pub get

ADD . /app/bot/
RUN pub get --offline

RUN dart run ./scripts/genDocJson.dart

RUN dart2native --enable-experiment=non-nullable bin/running_on_dart.dart

CMD []
ENTRYPOINT [ "./bin/running_on_dart.exe" ]
