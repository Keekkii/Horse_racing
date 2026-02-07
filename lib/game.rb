require_relative '../config/game_config'
require_relative '../db/database'
require_relative 'models/horse'
require_relative 'services/race_simulator'
require_relative 'services/odds_calculator'

class Game
  def initialize
    Database.setup
    @horses = Horse.all
    @balance = 1000.0
  end

  def start
    loop do
      display_main_menu
      choice = gets.chomp.to_i
      case choice
      when 1 then single_race
      when 2 then championship_mode
      when 3 then view_horses
      when 4 then break
      else puts "Invalid option"
      end
    end
    puts "Thanks for playing!"
  end

  def display_main_menu
    # Refresh wallet and horses
    @horses = Horse.all
    
    puts "\n" * 2
    puts "=== RUBY HORSE RACING 2.0 ==="
    puts "Balance: $#{@balance.round(2)}"
    puts "1. Single Race (Betting)"
    puts "2. Championship Mode (Simulate Season)"
    puts "3. Stable (View Horses & Injuries)"
    puts "4. Quit"
    print "> "
  end

  def view_horses
    @horses = Horse.all # Refresh
    puts "\n--- STABLE ---"
      puts sprintf("%-4s %-12s %-4s %-8s %-20s", "ID", "Name", "Age", "W/R", "Status")
    @horses.each do |h|
      status_str = h.current_injury ? "Inj: #{h.current_injury[:type]} (#{h.current_injury[:remaining]}rem)" : "Ready"
      puts sprintf("%-4d %-12s %-4d %-8s %-20s", h.id, h.name, h.age, "#{h.wins}/#{h.races_run}", status_str)
    end
    puts "\nPress Enter to return..."
    gets
  end

  def single_race
    puts "\n--- SINGLE RACE EVENT ---"
    
    available = @horses.reject { |h| h.current_injury }
    if available.size < 2
      puts "Not enough healthy horses (Need 2+)."
      return
    end

    participants = available.sample(5)
    odds = OddsCalculator.calculate(participants)

    puts "\nParticipants & Odds:"
    participants.each do |h|
      odd_val = odds[h.id]
      puts "ID: #{h.id} | #{h.name.ljust(10)} | Odds: #{odd_val}"
    end

    print "\nEnter Horse ID to bet on (0 to skip): "
    bet_horse_id = gets.chomp.to_i
    return if bet_horse_id == 0

    unless participants.any? { |h| h.id == bet_horse_id }
      puts "Invalid Horse ID."
      return
    end

    print "Bet Amount ($): "
    amount = gets.chomp.to_f
    if amount > @balance || amount <= 0
      puts "Invalid amount."
      return
    end

    @balance -= amount

    puts "\nRace starting..."
    sleep(1)
    
    sim = run_race_simulation(participants)
    winner = sim.results.first[:horse]

    puts "\nWinner is #{winner.name}!"
    
    if winner.id == bet_horse_id
      payout = amount * odds[winner.id]
      @balance += payout
      puts "You WON $#{payout.round(2)}! (Odds: #{odds[winner.id]})"
    else
      puts "You lost $#{amount}."
    end
    
    puts "Press Enter..."
    gets
  end

  def championship_mode
    puts "\n--- CHAMPIONSHIP SERIES ---"
    # Select 4 random horses
    available = @horses.reject { |h| h.current_injury }
    if available.size < 4
        puts "Not enough healthy horses for championship (need 4)."
        return
    end
    
    participants = available.sample(4)
    standings = Hash.new(0) # horse_id -> points
    
    3.times do |race_num|
      puts "\n--- RACE #{race_num + 1} of 3 ---"
      puts "Current Standings:"
      participants.sort_by { |h| -standings[h.id] }.each do |h|
          puts "#{h.name}: #{standings[h.id]} pts"
      end
      
      puts "\nPress Enter to start race..."
      gets
      
      sim = run_race_simulation(participants)
      
      # Award points: 1st=5, 2nd=3, 3rd=1
      # Results are ordered by time
      sim.results.each_with_index do |res, idx|
        horse = res[:horse]
        points = case idx
                 when 0 then 5
                 when 1 then 3
                 when 2 then 1
                 else 0
                 end
        standings[horse.id] += points
      end
    end
    
    puts "\n=== CHAMPIONSHIP RESULTS ==="
    winner_id = standings.max_by { |k, v| v }[0]
    winner = participants.find { |h| h.id == winner_id }
    puts "GRAND CHAMPION: #{winner.name} with #{standings[winner.id]} points!"
    
    # Maybe bonus?
    @balance += 500
    puts "You earned $500 for organizing the championship."
    
    puts "Press Enter..."
    gets
  end

  def run_race_simulation(horses)
    sim = RaceSimulator.new(horses)
    
    # Animation Loop
    until sim.finished
      sim.step
      print_race_state(sim, horses)
      sleep(sim.time_step * 0.5) # Speed up visualization slightly
    end
    sim
  end

  def print_race_state(sim, horses)
    # Clear screen (Windows/Linux compat)
    system("cls") || system("clear")
    
    puts "\n" + ("=" * 60)
    horses.each do |h|
      state = sim.get_state(h.id)
      # Visual Bar: 50 chars for 1000m
      track_len_chars = 50
      pos_chars = (state[:position] / GameConfig::TRACK_LENGTH * track_len_chars).to_i
      pos_chars = track_len_chars if pos_chars > track_len_chars
      
      lane = "-" * track_len_chars
      lane[pos_chars] = h.symbol rescue lane[-1] = h.symbol
      
      stamina_pct = (state[:stamina] / h.stamina_rating * 100).to_i
      stamina_bar = "| STA: #{stamina_pct}%"
      
      puts "#{h.name.ljust(10)} [#{lane}] #{stamina_bar}"
    end
    puts ("=" * 60)
  end
end
