FROM google/dart:2.14.3

WORKDIR /app

ADD pubspec.* /app/
RUN pub get

ADD . /app/
RUN pub get --offline

RUN dart compile exe bin/running_on_dart.dart

CMD []
ENTRYPOINT [ "./bin/running_on_dart.exe" ]
