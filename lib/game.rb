require_relative '../config/game_config'
require_relative '../db/database'
require_relative 'models/horse'
require_relative 'services/race_simulator'
require_relative 'services/odds_calculator'
require_relative 'services/terrain_generator'

class Game
  def initialize
    Database.setup
    @horses = Horse.active
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
    @horses = Horse.active

    puts "\n" * 2
    puts "=== RUBY HORSE RACING 2.0 ==="
    puts "Balance: $#{@balance.round(2)}"
    puts "1. Single Race (Betting)"
    puts "2. Championship Mode (Bracket)"
    puts "3. Stable (View Horses & Injuries)"
    puts "4. Quit"
    print "> "
  end

  def view_horses
    all = Horse.all
    puts "\n--- STABLE ---"
    puts sprintf("%-4s %-12s %-7s %-4s %-8s %-24s", "ID", "Name", "Status", "Age", "W/R", "Injury")
    all.each do |h|
      status = h.retired.to_i == 1 ? "Retired" : "Active"
      injury_str = h.current_injury ? "#{h.current_injury[:type]} (#{h.current_injury[:remaining]}rem)" : "-"
      puts sprintf("%-4d %-12s %-7s %-4d %-8s %-24s", h.id, h.name, status, h.age, "#{h.wins}/#{h.races_run}", injury_str)
    end
    puts "\nPress Enter to return..."
    gets
  end

  # =========================
  # Betting helpers (PLACE / EXACTA)
  # =========================

  def place_odds_from_prob(win_prob, places: 3)
    place_prob = 1.0 - (1.0 - win_prob) ** places
    place_prob = [place_prob, 0.97].min
    implied = place_prob * (1.0 + GameConfig::HOUSE_EDGE)
    odds = (1.0 / implied).round(2)
    odds = 1.10 if odds < 1.10
    odds
  end

  def exacta_odds_book(probabilities, first_id, second_id)
    p1 = probabilities[first_id]
    return 999.0 if p1.nil?

    pair_probs = {}
    ids = probabilities.keys

    ids.each do |i|
      pi = probabilities[i]
      next if pi.nil? || pi <= 0

      denom = [1.0 - pi, 0.0001].max
      ids.each do |j|
        next if i == j
        pj = probabilities[j]
        next if pj.nil? || pj <= 0
        pair_probs[[i, j]] = pi * (pj / denom)
      end
    end

    total_pairs = pair_probs.values.sum
    return 999.0 if total_pairs <= 0

    implied_pair = (pair_probs[[first_id, second_id]] / total_pairs) * (1.0 + GameConfig::HOUSE_EDGE)
    return 999.0 if implied_pair <= 0

    (1.0 / implied_pair).round(2)
  end

  # =========================
  # Terrain legend + per-horse terrain info
  # =========================

  def terrain_legend_line
    "Legend: grass=-----  mud=/////  sand=.....  gravel=:::::  incline=^^^^^"
  end

  def horse_terrain_info(sim, state)
    seg_i = (state[:position] / GameConfig::SEGMENT_LENGTH).floor
    seg = sim.terrain[seg_i] || sim.terrain.last
    mods = seg[:modifiers]
    type = seg[:type]
    " | #{type.to_s.ljust(7)} spd x#{mods[:speed]} drain x#{mods[:stamina_drain]}"
  end

  # =========================
  # Single race (betting)
  # =========================

  def single_race
    puts "\n--- SINGLE RACE EVENT ---"
    @horses = Horse.active

    available = @horses.reject { |h| h.current_injury }
    if available.size < 2
      puts "Not enough healthy horses (Need 2+)."
      return
    end

    participants = available.sample([5, available.size].min)

    seed = Random.new_seed
    sim = RaceSimulator.new(participants, seed, race_type: "Standard")

    odds_pack = OddsCalculator.calculate(participants, terrain_segments: sim.terrain)
    odds = odds_pack[:odds]

    puts "\nParticipants & Odds:"
    participants.each do |h|
      puts "ID: #{h.id} | #{h.name.ljust(10)} | Odds: #{odds[h.id]}"
    end

    puts "\nBet types:"
    puts "1. WIN (horse must win)"
    puts "2. PLACE (horse must finish top 3)"
    puts "3. EXACTA (pick 1st and 2nd in order)"
    puts "0. Skip betting"
    print "> "
    bet_type_choice = gets.chomp.to_i
    return if bet_type_choice == 0

    bet = { bet_type: nil, amount: 0.0, odds: 0.0, horse_id: nil, horse2_id: nil, selection: nil }

    case bet_type_choice
    when 1
      bet[:bet_type] = "WIN"
      print "Enter Horse ID to bet on: "
      bet[:horse_id] = gets.chomp.to_i
      unless participants.any? { |h| h.id == bet[:horse_id] }
        puts "Invalid Horse ID."
        return
      end
      bet[:odds] = odds[bet[:horse_id]]

    when 2
      bet[:bet_type] = "PLACE"
      print "Enter Horse ID to bet on (Top 3): "
      bet[:horse_id] = gets.chomp.to_i
      unless participants.any? { |h| h.id == bet[:horse_id] }
        puts "Invalid Horse ID."
        return
      end

      p = odds_pack[:probabilities][bet[:horse_id]]
      bet[:odds] = place_odds_from_prob(p, places: 3)

    when 3
      bet[:bet_type] = "EXACTA"
      print "Pick 1st place Horse ID: "
      bet[:horse_id] = gets.chomp.to_i
      print "Pick 2nd place Horse ID: "
      bet[:horse2_id] = gets.chomp.to_i

      if bet[:horse_id] == bet[:horse2_id]
        puts "Exacta requires two different horses."
        return
      end

      unless participants.any? { |h| h.id == bet[:horse_id] } && participants.any? { |h| h.id == bet[:horse2_id] }
        puts "Invalid Horse ID(s)."
        return
      end

      bet[:odds] = exacta_odds_book(odds_pack[:probabilities], bet[:horse_id], bet[:horse2_id])
      bet[:selection] = { first: bet[:horse_id], second: bet[:horse2_id] }

    else
      puts "Invalid bet type."
      return
    end

    if bet[:odds].nil? || bet[:odds] <= 1.0 || bet[:odds] >= 999.0
      puts "Bet not offered at these odds."
      return
    end

    print "Bet Amount ($): "
    amount = gets.chomp.to_f
    if amount > @balance || amount <= 0
      puts "Invalid amount."
      return
    end
    bet[:amount] = amount
    @balance -= amount

    puts "\nRace starting..."
    sleep(1)

    sim = run_race_simulation(participants, sim)
    Horse.recover_all_injuries!

    winner = sim.results.first[:horse]
    puts "\nWinner is #{winner.name}!"

    payout = 0.0
    won = false

    case bet[:bet_type]
    when "WIN"
      won = (winner.id == bet[:horse_id])
    when "PLACE"
      top3 = sim.results.take(3).map { |r| r[:horse].id }
      won = top3.include?(bet[:horse_id])
    when "EXACTA"
      first = sim.results[0][:horse].id
      second = sim.results[1][:horse].id
      won = (first == bet[:horse_id] && second == bet[:horse2_id])
    end

    if won
      payout = bet[:amount] * bet[:odds]
      @balance += payout
      puts "You WON $#{payout.round(2)}! (Odds: #{bet[:odds]})"
    else
      puts "You lost $#{bet[:amount]}."
    end

    Database.connection.execute(
      "INSERT INTO bets (race_id, bet_type, amount, odds, payout, horse_id, horse2_id, selection)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      [sim.race_id, bet[:bet_type], bet[:amount], bet[:odds], payout, bet[:horse_id], bet[:horse2_id], bet[:selection]&.to_json]
    )

    puts "Press Enter..."
    gets
  end

  # =========================
  # Championship (bracket + fatigue)
  # =========================

  def championship_mode
    puts "\n=== CHAMPIONSHIP MODE ==="
    @horses = Horse.active

    available = @horses.reject { |h| h.current_injury }
    if available.size < 8
      puts "Need at least 8 healthy horses for championship."
      return
    end

    bracket = available.sample(8)
    fatigue = {}
    bracket.each { |h| fatigue[h.id] = h.effective_stamina }

    round = 1
    while bracket.size > 1
      puts "\n--- ROUND #{round}: #{bracket.size} HORSES ---"
      next_round = []

      bracket.each_slice(2).with_index do |pair, idx|
        break if pair.size < 2

        puts "\nMatch #{idx + 1}: #{pair.map(&:name).join(' vs ')}"
        puts "Press Enter to start..."
        gets

        sim = RaceSimulator.new(
          pair,
          Random.new_seed,
          race_type: "Championship",
          start_stamina: fatigue
        )

        sim = run_race_simulation(pair, sim)
        Horse.recover_all_injuries!

        winner = sim.results.first[:horse]
        puts "Winner: #{winner.name}"

        pair.each do |horse|
          state = sim.get_state(horse.id)
          max_stamina = horse.effective_stamina
          recovered = state[:stamina] + (max_stamina - state[:stamina]) * GameConfig::CHAMPIONSHIP_STAMINA_RECOVERY
          fatigue[horse.id] = recovered
        end

        next_round << winner
      end

      bracket = next_round
      round += 1
    end

    champion = bracket.first
    puts "\n🏆 GRAND CHAMPION: #{champion.name} 🏆"

    reward = 750
    @balance += reward
    puts "You earned $#{reward}."

    puts "Press Enter..."
    gets
  end

  # =========================
  # Simulation rendering
  # =========================

  def run_race_simulation(horses, sim = nil)
    sim ||= RaceSimulator.new(horses)

    until sim.finished
      sim.step
      print_race_state(sim, horses)
      sleep(sim.time_step * 0.5)
    end
    sim
  end

  def print_race_state(sim, horses)
    system("cls") || system("clear")

    puts ("=" * 60)
    horses.each do |h|
      state = sim.get_state(h.id)

      track_len_chars = 50
      pos_chars = (state[:position] / GameConfig::TRACK_LENGTH * track_len_chars).to_i
      pos_chars = track_len_chars if pos_chars > track_len_chars

      lane = "-" * track_len_chars
      begin
        lane[pos_chars] = h.symbol
      rescue
        lane[-1] = h.symbol
      end

      stamina_den = [h.effective_stamina, 0.0001].max
      stamina_pct = (state[:stamina] / stamina_den * 100).to_i
      stamina_pct = 0 if stamina_pct < 0
      stamina_pct = 100 if stamina_pct > 100

      stamina_bar = "| STA: #{stamina_pct}%"
      terrain_info = horse_terrain_info(sim, state)

      puts "#{h.name.ljust(10)} [#{lane}] #{stamina_bar}#{terrain_info}"
    end
    puts ("=" * 60)
  end
end
