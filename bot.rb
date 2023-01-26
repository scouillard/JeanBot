require "discordrb"
require "logger"
require "net/http"
require "json"
require "uri"

# setup logging
logger = Logger.new(STDOUT)

# API KEY
OPENAI_API_KEY = ENV["OPENAI_API_KEY"]
DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]

# create bot
bot = Discordrb::Bot.new token: DISCORD_BOT_TOKEN

# TODO: request only required permissions to delete and send messages
ADMINISTRATOR = 8

# Here we output the invite URL to the console so the bot account can be invited to the channel. This only has to be
# done once, afterwards, you can remove this part if you want
logger.info("This bot's invite URL is #{bot.invite_url(permission_bits: ADMINISTRATOR)}.")
logger.info("Click on it to invite it to your server.")

# TODO: replace hard coded users with a dynamic registry
users = []

users.each do |user|
  bot.message(from: user) do |event|
    case analysed = sentiment_analysis(event.message.content)
    when /Positive/i
      puts "Positive"
    when /Negative/i
      puts "Negative"
      edited = moderation_rewrite(event.message.content)
      puts edited
      event.message.delete("Moderation rewrite")
      event.respond("~~#{event.message.content}~~" + "\n" + edited)
    else
      puts "Neutral"
    end
  end
end

# main loop
bot.ready do |event|
  logger.info("Ready!")
  bot.online

  bot.servers.each do |server_id, server|
    logger.debug("#{server.name} #{server.channels.size} #{server_id}}")
    server.channels.each do |channel|
      if channel.type == 0
        logger.debug("#{channel.name} #{channel.type} #{channel.id}")
      end
    end
  end
end

# query OpenAI completions API for sentiment analysis
def sentiment_analysis(text)
  uri = URI.parse("https://api.openai.com/v1/completions")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{OPENAI_API_KEY}"
  request.body = {
    model: "text-davinci-003",
    prompt: "Do you feel like the statement : \"#{text}\" is positive, negative or neutral?",
    temperature: 0.7,
    max_tokens: 256,
    top_p: 1,
    frequency_penalty: 0,
    presence_penalty: 0,
  }.to_json

  response = http.request(request)
  ret = JSON.parse(response.body)
  if ret.include?("error")
    ret["error"]
  else
    ret["choices"][0]["text"].strip
  end
end

# moderation request
def moderation_rewrite(text)
  uri = URI.parse("https://api.openai.com/v1/completions")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{OPENAI_API_KEY}"
  request.body = {
    model: "text-davinci-003",
    prompt: "Rewrite the following statement in a positive manner : \"#{text}\"",
    temperature: 0.7,
    max_tokens: 256,
    top_p: 1,
    frequency_penalty: 0,
    presence_penalty: 0,
  }.to_json

  response = http.request(request)

  ret = JSON.parse(response.body)

  if ret.include?("error")
    ret["error"]
  else
    ret["choices"][0]["text"].strip
  end
end

# This method call has to be put at the end of your script, it is what makes the bot actually connect to Discord. If you
# leave it out (try it!) the script will simply stop and the bot will not appear online.
bot.run
