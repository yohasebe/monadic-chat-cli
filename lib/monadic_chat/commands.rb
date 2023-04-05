# frozen_string_literal: true

module MonadicChat
  def self.open_readme
    url = "https://github.com/yohasebe/monadic-chat/"
    Launchy.open(url)
  end

  def self.mdprint(str)
    print TTY::Markdown.parse(str, indent: 0)
  end

  def self.prompt_system
    box_width = 8
    name = "System".center(box_width, " ")
    color = "green"
    "\n#{PASTEL.send(:"on_#{color}", name)}"
  end

  def self.prompt_user
    box_width = 6
    color = "blue"
    name = "User".center(box_width, " ")
    "\n#{PASTEL.send(:"on_#{color}", name)}"
  end

  def self.prompt_assistant
    box_width = 5
    color = "red"
    name = "GPT".center(box_width, " ")
    "\n#{PASTEL.send(:"on_#{color}", name)}"
  end

  def self.tokenize(text)
    BLINGFIRE.text_to_ids(text)
  end

  def self.create_app(app_name)
    app_name = +app_name.downcase
    user_apps_dir = File.join(HOME, "user_apps")
    user_app_dir = File.join(user_apps_dir, app_name)
    FileUtils.mkdir_p(user_app_dir)
    # replace certain strings in boilerplate files (boilerplate.rb, boilerplate.json, boilerplate.md)
    [".rb", ".json", ".md"].each do |ext|
      file = File.join(HOME, "user_apps", "boilerplates", "boilerplate#{ext}")
      content = File.read(file)
      content.gsub!("{{APP_NAME}}", app_name)
      content.gsub!("{{APP_CLASS_NAME}}", app_name.capitalize)
      File.open(File.join(user_app_dir, "#{app_name}#{ext}"), "w") do |f|
        f.write(content)
      end
    end
    print PROMPT_SYSTEM.prefix, "Scaffolding of the app created successfully", "\n"
    print "Edit the app files:", "\n"
    print HOME, "\n"
    print "user_apps", "\n"
    print "└── #{app_name}", "\n"
    print "    ├── #{app_name}.json", "\n"
    print "    ├── #{app_name}.md", "\n"
    print "    └── #{app_name}.rb", "\n"
  end

  def self.delete_app(app_name)
    app_name = +app_name.downcase
    user_apps_dir = File.join(HOME, "user_apps")
    user_app_dir = File.join(user_apps_dir, app_name)
    # confirm user wants to delete the app
    if PROMPT_SYSTEM.yes?("Are you sure you want to delete the app #{app_name}?")
      FileUtils.rm_rf(user_app_dir)
      print PROMPT_SYSTEM.prefix, "App deleted successfully", "\n"
    else
      print PROMPT_SYSTEM.prefix, "App deletion cancelled", "\n"
    end
  end
end
