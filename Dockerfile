FROM google/dart:2.9

WORKDIR /app

RUN git clone https://github.com/l7ssha/nyxx.git nyxx
RUN cd nyxx; git checkout rewrite_modular;

WORKDIR /app/bot

ADD pubspec.* /app/bot/
RUN pub get

ADD . /app/bot
RUN pub get --offline

CMD []
ENTRYPOINT [ "/usr/bin/dart", "--enable-experiment=non-nullable", "--no-null-safety", "bin/running_on_dart.dart" ]
