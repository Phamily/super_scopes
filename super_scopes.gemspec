Gem::Specification.new do |s|
  s.name        = 'super_scopes'
  s.version     = '0.0.6'
  s.date        = '2018-08-17'
  s.summary     = "Super Scopes!"
  s.description = "Dynamic SQL-backed field hydration"
  s.authors     = ["Bryce Harlan"]
  s.email       = 'bryce@jaanhealth.com'
  s.files       = ["lib/super_scopes.rb"]
  s.license       = 'MIT'
  s.add_runtime_dependency 'rodash', '~> 3.0.0'
end