Gem::Specification.new do |s|
  s.name    = 'unique_thread'
  s.version = '0.1.1'
  s.summary = 'Allows a block of code to be run once across many processes'
  s.license = 'MIT'

  s.author   = 'Fernando Seror'
  s.email    = 'ferdy89@gmail.com'
  s.homepage = 'https://github.com/Ferdy89/unique_thread'

  s.files = Dir['lib/**/*']

  s.add_dependency 'redis', '>= 3', '< 5'
end
