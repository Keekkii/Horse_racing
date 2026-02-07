class Horse
  attr_reader :name, :symbol, :speed_rating
  attr_accessor :position, :odds

  def initialize(name, symbol, speed_rating)
    @name = name
    @symbol = symbol
    @speed_rating = speed_rating
    @position = 0
    @odds = 0.0
  end

  def reset_position
    @position = 0
  end

  def move
    # Movement is based on speed rating plus a significant random factor for unpredictability
    move_amount = (@speed_rating * 0.5) + rand(1..4)
    @position += move_amount
  end
end

class Race
  TRACK_LENGTH = 100

  def initialize(horses)
    @horses = horses
  end

  def start
    @horses.each(&:reset_position)
    winner = nil
    
    puts "\n" * 50 # Clear screen simulation
    puts "THE RACE IS ABOUT TO START!"
    sleep(1.5)

    until winner
      puts "\n" * 50 # Clear screen
      puts "=" * (TRACK_LENGTH + 20)
      
      @horses.each do |horse|
        horse.move
        print_lane(horse)
        if horse.position >= TRACK_LENGTH && winner.nil?
          winner = horse
        end
      end
      
      puts "=" * (TRACK_LENGTH + 20)
      sleep(0.1) # Controls animation speed
    end
    
    puts "\nWINNER: #{winner.name}!"
    winner
  end

  def print_lane(horse)
    # Ensure position isn't visual past the finish line for rendering
    display_pos = [horse.position, TRACK_LENGTH].min.to_i
    
    # Calculate padding
    track_string = " " * display_pos + horse.symbol + " " * (TRACK_LENGTH - display_pos)
    puts "#{horse.name.ljust(10)} |#{track_string}|"
  end
end

class Game
  def initialize
    @balance = 100
    @horses = [
      Horse.new("Thunder", "T", 1.8),
      Horse.new("Lightning", "L", 1.9),
      Horse.new("Storm", "S", 1.6),
      Horse.new("Bolt", "B", 1.5),
      Horse.new("Flash", "F", 2.0)
    ]
    calculate_odds
  end

  def calculate_odds
    # Simple odds calculation: Lower speed rating = Higher odds
    # This is a simplification; in real life, higher speed = lower odds (better chance)
    # Here: 
    # Flash (2.0) -> Best horse
    # Bolt (1.5) -> Slowest horse
    
    # Let's inverse the speed for odds calculation base
    total_speed = @horses.sum(&:speed_rating)
    
    @horses.each do |horse|
      # Probability approx = individual_speed / total_speed
      # Decimal Odds approx = 1 / probability
      win_prob = horse.speed_rating / total_speed
      raw_odds = 1.0 / win_prob
      horse.odds = raw_odds.round(2)
    end
  end

  def display_menu
    puts "\n--- RUBY HORSE RACING ---"
    puts "Current Balance: $#{@balance}"
    puts "Available Horses:"
    @horses.each_with_index do |horse, index|
      puts "#{index + 1}. #{horse.name} (Odds: #{horse.odds}x) - Symbol: #{horse.symbol}"
    end
    puts "-------------------------"
    puts "1. Place Bet & Start Race"
    puts "2. Quit"
    print "Select an option: "
  end

  def place_bet
    print "Enter horse number (1-#{@horses.length}): "
    choice = gets.chomp.to_i
    if choice < 1 || choice > @horses.length
      puts "Invalid horse selection."
      return nil
    end

    print "Enter bet amount: $"
    amount = gets.chomp.to_i
    if amount > @balance
      puts "Insufficient funds!"
      return nil
    elsif amount <= 0
      puts "Bet must be positive."
      return nil
    end

    return { horse: @horses[choice - 1], amount: amount }
  end

  def run
    loop do
      display_menu
      choice = gets.chomp.to_i

      case choice
      when 1
        bet = place_bet
        next unless bet

        @balance -= bet[:amount]
        race = Race.new(@horses)
        winner = race.start

        if winner == bet[:horse]
          winnings = (bet[:amount] * winner.odds).floor
          @balance += winnings
          puts "\nCongratulations! You won $#{winnings}!"
        else
          puts "\nSorry, you lost your bet of $#{bet[:amount]}."
        end
        
        puts "Press Enter to continue..."
        gets

      when 2
        puts "Thanks for playing! Final Balance: $#{@balance}"
        break
      else
        puts "Invalid option."
      end

      if @balance <= 0
        puts "You are out of money! Game Over."
        break
      end
    end
  end
end

# Start the game
if __FILE__ == $0
  game = Game.new
  game.run
end
