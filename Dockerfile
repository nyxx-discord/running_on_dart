FROM google/dart:2.11.0-189.0.dev

WORKDIR /app

RUN git clone https://github.com/l7ssha/nyxx.git
RUN cd nyxx; git fetch; git checkout 1.1

WORKDIR /app/bot

ADD pubspec.* /app/bot/
RUN pub get

ADD . /app/bot/
RUN pub get --offline

RUN dart2native --enable-experiment=non-nullable bin/running_on_dart.dart

CMD []
ENTRYPOINT [ "./bin/running_on_dart.exe" ]
