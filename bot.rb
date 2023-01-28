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

bot.message do |event|
  puts sentiment_analysis(event.message.content)
  case analysed = sentiment_analysis(event.message.content)
  when /Positive/i
    puts analysed
    puts "Positive"
    puts "Toxic Message Generated"
    toxic_message = toxic_generator(event.message.content)
    corrected_message = rewrite(toxic_message)
    event.respond(corrected_message)
  else
    puts analysed
    puts "Neutral"
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
    prompt: "Do you feel like the statement : \"#{text}\" is related to one of the following subject \"#{trigger_words.join(", ")}\"?
             If so, respond with Positive.",
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

def toxic_generator(user_text)
  uri = URI.parse("https://api.openai.com/v1/completions")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{OPENAI_API_KEY}"
  request.body = {
    model: "text-davinci-003",
    prompt: "Write a short toxic masculinity statement relative to \"#{user_text}\" and \"#{antagonizing_subjects.sample}\"
             in an extremely bad french quebecois, with a lot of spelling mistakes.
             Talk about what real men would do. Talk about real men as \"les vrais hommes\" or \"gars de chantier\".
             Make it sound very aggressive.
             Use french quebecois slang.
             Make a lot of spelling mistakes.",
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
    puts ret["choices"][0]["text"].strip
    ret["choices"][0]["text"].strip
  end
end

DIACRITICS = [*0x1DC0..0x1DFF, *0x0300..0x036F, *0xFE20..0xFE2F].pack('U*')
def removeaccents(str)
  str
    .unicode_normalize(:nfd)
    .tr(DIACRITICS, '')
    .unicode_normalize(:nfc)
end

def rewrite(text)
  text.downcase!
  text.gsub! '.', [' . ', ''].sample
  text.gsub! ', ', [',', ' ', ', '].sample
  text.gsub! '!', [' . ', ''].sample
  text.gsub! '\'cest', 'ses'
  text.gsub! '\'', [' ', ''].sample
  text = removeaccents(text)
  return text
end

def trigger_words
  ["travail",
   "travail de la maison",
   "work from home",
   "gouvernement",
   "greve",
   "cheque",
   "chomage",
   "fonctionnaire"]
end

def antagonizing_subjects
  ["travail de la maison",
   "gouvernement",
   "greve au gouvernement",
   "cheque",
   "chomage",
   "fonctionnaire",
   "admin du discord corrompus"]
end

# This method call has to be put at the end of your script, it is what makes the bot actually connect to Discord. If you
# leave it out (try it!) the script will simply stop and the bot will not appear online.
bot.run


