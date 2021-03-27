FROM google/dart:2.12

WORKDIR /app

RUN git clone https://github.com/l7ssha/nyxx.git

WORKDIR /app/nyxx
RUN git fetch
RUN git checkout 1.1

WORKDIR /app/nyxx/nyxx
RUN dartdoc

WORKDIR /app/nyxx/nyxx.commander
RUN dartdoc

WORKDIR /app/nyxx/nyxx.extensions
RUN dartdoc

WORKDIR /app/bot

ADD pubspec.* /app/bot/
RUN pub get

ADD . /app/bot/
RUN pub get --offline

RUN dart run ./scripts/genDocJson.dart

RUN dart2native bin/running_on_dart.dart

CMD []
ENTRYPOINT [ "./bin/running_on_dart.exe" ]
