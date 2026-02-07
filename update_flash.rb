require_relative 'db/database'

Database.connection.execute("UPDATE horses SET base_speed = 9.0 WHERE name = 'Flash'")
puts "Updated Flash speed to 9.0"
