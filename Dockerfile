FROM dart:3.8 AS build

WORKDIR /app
COPY pubspec.* /app/
RUN dart pub get

COPY . /app
RUN dart pub get --offline

FROM build AS dev

CMD [ "dart", "run", "bin/running_on_dart.dart" ]

FROM build AS build_prod

RUN dart run nyxx_commands:compile bin/running_on_dart.dart -o bot

FROM node:lts-slim as build_frontend

ARG REACT_APP_CLIENT_ID
ARG REACT_APP_REDIRECT_URL
ARG REACT_APP_API_SERVER

ENV REACT_APP_CLIENT_ID=$REACT_APP_CLIENT_ID
ENV REACT_APP_REDIRECT_URL=$REACT_APP_REDIRECT_URL
ENV REACT_APP_API_SERVER=$REACT_APP_API_SERVER

WORKDIR /app

COPY ./frontend/ /app

RUN npm install
RUN npm run build

FROM scratch AS prod

WORKDIR /app

COPY --from=build_prod /runtime /
COPY --from=build_prod /app/bot.exe /app
COPY --from=build_frontend /app/build /app/public

CMD [ "./bot.exe" ]
