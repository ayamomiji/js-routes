desc "Generate a JavaScript file that contains your Rails routes"
namespace :js do
  task :routes, [:filename, :tld_size] => [:environment] do |t, args|
    if Rails.version < "3.1.0"
      puts "Your Rails version is not supported."
      exit 1
    end

    tld_size = args[:tld_size].to_i
    tld_size = 2 if tld_size < 1

    filename = args[:filename].blank? ? "rails.routes.js" : args[:filename]
    save_path = "#{Rails.root}/app/assets/javascripts/#{filename}"

    routes = generate_routes

    javascript = "var Paths = {\n";
    javascript << routes.map do |route|
      generate_path_method(route[:name], route[:path])
    end.join(",\n")
    javascript << "\n};\n";

    javascript << "var Urls = {\n";
    javascript << "  _baseDomain: location.host.split('.').reverse().slice(0, #{tld_size}).reverse().join('.'),\n"
    javascript << "  _getDomain: function(subdomain) {
    if (typeof subdomain !== 'undefined' && subdomain !== null && subdomain.trim() !== '') {
      return [subdomain.trim(), Urls._baseDomain].join('.');
    } else {
      return Urls._baseDomain;
    }
  },\n"
    javascript << routes.map do |route|
      generate_url_method(route[:name], route[:path])
    end.join(",\n")
    javascript << "\n};\n";

    File.open(save_path, "w") { |f| f.write(javascript) }
    puts "Routes saved to #{save_path}."
  end
end

def generate_path_method(name, path)
  compare = /:(.*?)(\/|$)/
  path.sub!(compare, "' + params.#{$1} + '#{$2}") while path =~ compare
  """  #{name}: function(params) {
    return '#{path}' + (params && params.format ? '.' + params.format : '');
  }"""
end

def generate_url_method(name, path)
  compare = /:(.*?)(\/|$)/
  path.sub!(compare, "' + params.#{$1} + '#{$2}") while path =~ compare
  """  #{name}: function(params) {
    return 'http://' + Urls._getDomain(params.subdomain) + '#{path}' + (params && params.format ? '.' + params.format : '');
  }"""
end

def generate_routes
  Rails.application.reload_routes!
  processed_routes = []
  Rails.application.routes.routes.each do |route|
    processed_routes << {:name => route.name.camelize(:lower), :path => route.path.split("(")[0]} unless route.name.nil?
  end
  processed_routes
end
