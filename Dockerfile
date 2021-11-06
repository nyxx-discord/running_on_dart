FROM google/dart:2.14.3 as builder

WORKDIR /app

ADD pubspec.* /app/
RUN pub get

ADD . /app/
RUN pub get --offline

RUN dart compile exe bin/running_on_dart.dart

FROM ubuntu
WORKDIR /app

COPY --from=builder /app/bin/running_on_dart.exe /app

CMD []
ENTRYPOINT [ "./running_on_dart.exe" ]
