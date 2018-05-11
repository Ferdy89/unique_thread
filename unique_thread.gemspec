Gem::Specification.new do |s|
  s.name    = 'unique_thread'
  s.version = '0.1.0'
  s.summary = 'Allows a block of code to be run once across many processes'

  s.author   = 'Fernando Seror'
  s.email    = 'ferdy89@gmail.com'
  s.homepage = 'https://github.com/Ferdy89/unique_thread'

  s.files = Dir['lib/**/*.rb']

  s.add_dependency 'redis'
end
