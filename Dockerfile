FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* /app/
RUN dart pub get

COPY . /app
RUN dart pub get --offline

FROM build AS dev

CMD [ "dart", "run", "bin/running_on_dart.dart" ]

FROM build AS build_prod

RUN dart run nyxx_commands:compile bin/running_on_dart.dart -o bot

FROM scratch AS prod

WORKDIR /app

COPY --from=build_prod /runtime /
COPY --from=build_prod /app/templates /app/templates
COPY --from=build_prod /app/bot.exe /app

CMD [ "./bot.exe" ]
