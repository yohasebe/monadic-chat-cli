# frozen_string_literal: true

require_relative "../monadic_gpt"

module MonadicGpt
  def self.authenticate(overwrite: false)
    if overwrite
      prompt_monadic
      access_token = nil
      access_token ||= PROMPT.mask(" Input your OpenAI access token:") until access_token

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
      access_token ||= PROMPT.mask(" Input your OpenAI access token:") until access_token
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
    color = "yellow"
    print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
  end

  def self.prompt_user
    box_width = 10
    color = "blue"
    name = "User".center(box_width, " ")
    print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
  end

  def self.prompt_gpt3
    box_width = 10
    color = "red"
    name = "GPT".center(box_width, " ")
    print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
  end

  def self.banner(title, desc, color1, color2)
    title = title.center(60, " ")
    desc = desc.center(60, " ")
    help = "Type \"help\" for menu".center(60, " ")
    padding = "".center(60, " ")
    banner = <<~BANNER
      #{PASTEL.send(:"on_#{color2}", padding)}
      #{PASTEL.send(:"on_#{color1}", padding)}
      #{PASTEL.send(:"on_#{color1}").bold(title)}
      #{PASTEL.send(:"on_#{color1}", desc)}
      #{PASTEL.send(:"on_#{color1}", padding)}
      #{PASTEL.send(:"on_#{color1}", help)}
      #{PASTEL.send(:"on_#{color1}", padding)}
      #{PASTEL.send(:"on_#{color2}", padding)}
    BANNER
    print TTY::Box.frame banner.strip
  end

  def self.clear_screen
    print "\e[2J\e[f"
  end
end
