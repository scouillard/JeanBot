FROM ruby:2.7.7

ARG OPENAI_API_KEY
ARG DOCKER_BOT_TOKEN

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY bot.rb .

ENV OPENAI_API_KEY=$OPENAI_API_KEY
ENV DISCORD_BOT_TOKEN=$DISCORD_BOT_TOKEN

CMD ["./bot.rb"]