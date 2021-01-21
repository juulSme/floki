# fast_html uses a C-Node worker for parsing, so starting the application
# is necessary for it to work
if Application.get_env(:floki, :html_parser) == Floki.HTMLParser.FastHtml do
  Application.ensure_all_started(:fast_html)
end

Application.put_env(:ex_unit, :module_load_timeout, 120_000)
ExUnit.start()
