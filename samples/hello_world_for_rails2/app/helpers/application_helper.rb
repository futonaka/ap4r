# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def monosp(sentence, style = "")
    %Q(<span style="font-family: monospace; #{style}">#{sentence}</span>)
  end
end
