# frozen_string_literal: true

require_relative "../monadic_gpt"

module MonadicGpt
  def self.authenticate(overwrite: false)
    if overwrite
      prompt_monadic
      access_token = nil
      access_token ||= PROMPT.mask("Input Input your API key:") until access_token

      File.open(CONFIG, "w") do |f|
        config = { "access_token" => access_token }
        f.write(JSON.pretty_generate(config))
        print "New access token has been saved to #{CONFIG}\n"
      end
    elsif File.exist?(CONFIG)
      json = File.read(CONFIG)
      config = JSON.parse(json)
      access_token = config["access_token"]
    else
      access_token ||= PROMPT.mask("Input Input your API key:") until access_token
      File.open(CONFIG, "w") do |f|
        config = { "access_token" => access_token }
        f.write(JSON.pretty_generate(config))
        print "New access token has been saved to config\n"
      end
    end

    print "Checking configuration ... "
    begin
      raise if OpenAI.models(access_token).empty?

      print "success.\n"
      OpenAI::Completion.new(access_token)
    rescue StandardError
      print "failure.\n"
      authenticate(overwrite: true)
    end
  end

  def self.prompt_monadic
    box_width = 10
    name = "Monadic".center(box_width, " ")
    color = "magenta"
    print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
  end

  def self.prompt_user
    box_width = 10
    color = "green"
    name = "User".center(box_width, " ")
    print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
  end

  def self.prompt_gpt3
    box_width = 10
    color = "red"
    name = "GPT".center(box_width, " ")
    print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
  end

  def self.banner(title, desc, color)
    title = title.center(40, " ")
    desc = desc.center(40, " ")
    help1 = "Type \"help\" for menu".center(40, " ")
    help2 = "Type \"exit\" to quit".center(40, " ")
    padding = "".center(40, " ")
    banner = <<~BANNER
      #{PASTEL.send(:"on_#{color}", padding)}
      #{PASTEL.send(:"on_#{color}").bold(title)}
      #{PASTEL.send(:"on_#{color}", desc)}
      #{PASTEL.send(:"on_#{color}", padding)}
      #{PASTEL.send(:"on_#{color}", help1)}
      #{PASTEL.send(:"on_#{color}", help2)}
      #{PASTEL.send(:"on_#{color}", padding)}
    BANNER
    print TTY::Box.frame banner.strip
  end
end
