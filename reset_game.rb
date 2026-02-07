require_relative 'db/database'

puts "Resetting Game State..."

# 1. Clear Injuries
Database.connection.execute("DELETE FROM injuries")
puts "All injuries healed."

# 2. Clear Race Results & Races
Database.connection.execute("DELETE FROM race_results")
Database.connection.execute("DELETE FROM races")
puts "Race history cleared."

# 3. Reset Horse Stats
Database.connection.execute("UPDATE horses SET races_run = 0, wins = 0")
puts "Horse stats reset (races_run=0, wins=0)."

puts "Game state reset complete!"
