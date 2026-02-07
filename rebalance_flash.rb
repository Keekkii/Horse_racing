require_relative 'db/database'

puts "Rebalancing Flash..."

# Find Flash
flash = Database.connection.execute("SELECT * FROM horses WHERE name = 'Flash'").first

if flash
  puts "Found Flash. Old Speed: #{flash['base_speed']}"
  
  # Update Speed
  # Nerfing from 9.5 to 8.5
  # Also increasing stamina slightly to compensate? No, keep him as a "sprinter" who tires out.
  # Maybe improve acceleration slightly if we really want him to be a rocket starter? He's already max accel.
  
  Database.connection.execute("UPDATE horses SET base_speed = 8.5 WHERE id = ?", flash['id'])
  
  updated_flash = Database.connection.execute("SELECT * FROM horses WHERE id = ?", flash['id']).first
  puts "Updated Flash. New Speed: #{updated_flash['base_speed']}"
else
  puts "Flash not found in database."
end
