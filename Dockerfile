FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* /app/
RUN dart pub get

COPY . /app
RUN dart pub get --offline

FROM build as dev

CMD [ "dart", "run", "bin/running_on_dart.dart" ]

FROM build as prod

RUN dart run nyxx_commands:compile bin/running_on_dart.dart -o bot.exe

CMD [ "./bot.exe" ]