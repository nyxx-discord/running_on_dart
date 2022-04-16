FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* /app/
RUN dart pub get

COPY . /app
RUN dart pub get --offline

CMD [ "dart", "run", "bin/running_on_dart.dart" ]
