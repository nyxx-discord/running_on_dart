FROM google/dart:2.9

WORKDIR /app

ADD pubspec.* /app/
RUN pub get

ADD . /app
RUN pub get --offline

CMD []
ENTRYPOINT [ "/usr/bin/dart", "--enable-experiment=non-nullable", "--no-null-safety", "bin/running_on_dart.dart" ]
