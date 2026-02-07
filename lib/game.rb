require_relative '../config/game_config'
require_relative '../db/database'
require_relative 'models/horse'
require_relative 'services/race_simulator'
require_relative 'services/odds_calculator'
require_relative 'services/terrain_generator'

class Game
  def initialize
    # Inicijalizacija baze podataka i postavljanje početnog stanja
    Database.setup
    @horses = Horse.active
    @balance = 1000.0
  end

  def start
    # Glavna petlja igre koja prikazuje izbornik dok korisnik ne izađe
    loop do
      display_main_menu
      choice = gets.chomp.to_i
      case choice
      when 1 then single_race       # Pojedinačna utrka s klađenjem
      when 2 then championship_mode # Prvenstvo (turnir)
      when 3 then view_horses       # Pregled staje i konja
      when 4 then break             # Izlaz iz igre
      else puts "Invalid option"
      end
    end
    puts "Hvala na igranju!"
  end

  def display_main_menu
    # Osvježavamo listu aktivnih konja prije svakog prikaza izbornika
    @horses = Horse.active

    puts "\n" * 2
    puts "=== RUBY HORSE RACING 2.0 ==="
    puts "Balance: $#{@balance.round(2)}"
    puts "1. Single Race (Betting)"
    puts "2. Championship Mode (Betting & Bracket)"
    puts "3. Stable (View Horses & Injuries)"
    puts "4. Quit"
    print "> "
  end

  def view_horses
    # Prikaz svih konja, njihovog statusa (aktivan/umirovljen) i ozljeda
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
  # Pomoćne metode za klađenje (PLACE / EXACTA)
  # =========================

  def place_odds_from_prob(win_prob, places: 3)
    # Izračun kvote za "PLACE" okladu (konj završava u top 3)
    # Koristimo vjerojatnost pobjede da procijenimo šansu za plasman
    place_prob = 1.0 - (1.0 - win_prob) ** places
    place_prob = [place_prob, 0.97].min
    implied = place_prob * (1.0 + GameConfig::HOUSE_EDGE)
    odds = (1.0 / implied).round(2)
    odds = 1.10 if odds < 1.10
    odds
  end

  def exacta_odds_book(probabilities, first_id, second_id)
    # Izračun kvote za "EXACTA" okladu (točan poredak prvog i drugog konja)
    p1 = probabilities[first_id]
    return 999.0 if p1.nil?

    pair_probs = {}
    ids = probabilities.keys

    # Iteriramo kroz sve parove da normaliziramo vjerojatnosti
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

    # Primjenjujemo maržu kuće (House Edge)
    implied_pair = (pair_probs[[first_id, second_id]] / total_pairs) * (1.0 + GameConfig::HOUSE_EDGE)
    return 999.0 if implied_pair <= 0

    (1.0 / implied_pair).round(2)
  end

  # =========================
  # Legenda terena i informacije o konju
  # =========================

  def terrain_legend_line
    "Legend: grass=-----  mud=/////  sand=.....  gravel=:::::  incline=^^^^^"
  end

  def horse_terrain_info(sim, state)
    # Prikazuje trenutni tip terena i njegove modifikatore za konja
    seg_i = (state[:position] / GameConfig::SEGMENT_LENGTH).floor
    seg = sim.terrain[seg_i] || sim.terrain.last
    mods = seg[:modifiers]
    type = seg[:type]
    " | #{type.to_s.ljust(7)} spd x#{mods[:speed]} drain x#{mods[:stamina_drain]}"
  end

  # =========================
  # Zajednička logika za klađenje i utrke
  # =========================

  def display_odds_table(participants, odds)
    # Ispisuje tablicu sudionika i njihovih koeficijenata za pobjedu
    puts "\nParticipants & Odds:"
    participants.each do |h|
      puts "ID: #{h.id} | #{h.name.ljust(10)} | Odds: #{odds[h.id]}"
    end
  end

  def place_bet(participants, odds_pack, allowed_types: [:win, :place, :exacta])
    # Glavna metoda za postavljanje oklada.
    # allowed_types filtrira koje vrste oklada su dostupne (npr. samo :win za prvenstvo).
    odds = odds_pack[:odds]
    
    puts "\nBet types:"
    puts "1. WIN (horse must win)" if allowed_types.include?(:win)

    # PLACE oklada je moguća samo ako ima 4 ili više konja i ako je dozvoljena
    can_place = participants.size >= 4 && allowed_types.include?(:place)
    puts "2. PLACE (horse must finish top 3)" if can_place

    puts "3. EXACTA (pick 1st and 2nd in order)" if allowed_types.include?(:exacta)

    puts "0. Skip betting"
    print "> "
    bet_type_choice = gets.chomp.to_i
    return nil if bet_type_choice == 0

    bet = { bet_type: nil, amount: 0.0, odds: 0.0, horse_id: nil, horse2_id: nil, selection: nil }

    case bet_type_choice
    when 1
      unless allowed_types.include?(:win)
        puts "Invalid choice."
        return nil
      end
      bet[:bet_type] = "WIN"
      print "Enter Horse ID to bet on: "
      bet[:horse_id] = gets.chomp.to_i
      # Provjera postoji li konj s tim ID-om u utrci
      unless participants.any? { |h| h.id == bet[:horse_id] }
        puts "Invalid Horse ID."
        return nil
      end
      bet[:odds] = odds[bet[:horse_id]]

    when 2
      unless can_place
        puts "Invalid choice."
        return nil
      end
      bet[:bet_type] = "PLACE"
      print "Enter Horse ID to bet on (Top 3): "
      bet[:horse_id] = gets.chomp.to_i
      unless participants.any? { |h| h.id == bet[:horse_id] }
        puts "Invalid Horse ID."
        return nil
      end

      p = odds_pack[:probabilities][bet[:horse_id]]
      bet[:odds] = place_odds_from_prob(p, places: 3)

    when 3
      unless allowed_types.include?(:exacta)
        puts "Invalid choice."
        return nil
      end
      bet[:bet_type] = "EXACTA"
      print "Pick 1st place Horse ID: "
      bet[:horse_id] = gets.chomp.to_i
      print "Pick 2nd place Horse ID: "
      bet[:horse2_id] = gets.chomp.to_i

      if bet[:horse_id] == bet[:horse2_id]
        puts "Exacta requires two different horses."
        return nil
      end

      unless participants.any? { |h| h.id == bet[:horse_id] } && participants.any? { |h| h.id == bet[:horse2_id] }
        puts "Invalid Horse ID(s)."
        return nil
      end

      bet[:odds] = exacta_odds_book(odds_pack[:probabilities], bet[:horse_id], bet[:horse2_id])
      bet[:selection] = { first: bet[:horse_id], second: bet[:horse2_id] }

    else
      puts "Invalid bet type."
      return nil
    end

    # Provjera validnosti kvote
    if bet[:odds].nil? || bet[:odds] <= 1.0 || bet[:odds] >= 999.0
      puts "Bet not offered at these odds."
      return nil
    end

    print "Bet Amount ($): "
    amount = gets.chomp.to_f
    if amount > @balance || amount <= 0
      puts "Invalid amount. You have $#{@balance}."
      return nil
    end
    bet[:amount] = amount
    @balance -= amount
    puts "Bet placed! Remaining balance: $#{@balance.round(2)}"
    
    bet
  end

  def resolve_bet(bet, sim)
    return unless bet

    # Određivanje pobjednika i rezultata oklade
    winner = sim.results.first[:horse]
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

    # Spremanje oklade u bazu podataka za povijest
    Database.connection.execute(
      "INSERT INTO bets (race_id, bet_type, amount, odds, payout, horse_id, horse2_id, selection)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      [sim.race_id, bet[:bet_type], bet[:amount], bet[:odds], payout, bet[:horse_id], bet[:horse2_id], bet[:selection]&.to_json]
    )
  end

  # =========================
  # Pojedinačna utrka (Single race)
  # =========================

  def single_race
    puts "\n--- SINGLE RACE EVENT ---"
    @horses = Horse.active

    # Provjera ima li dovoljno zdravih konja
    available = @horses.reject { |h| h.current_injury }
    if available.size < 2
      puts "Not enough healthy horses (Need 2+)."
      return
    end

    # Odabir sudionika (max 5)
    participants = available.sample([5, available.size].min)

    seed = Random.new_seed
    sim = RaceSimulator.new(participants, seed, race_type: "Standard")

    # Izračun kvota
    odds_pack = OddsCalculator.calculate(participants, terrain_segments: sim.terrain)
    
    display_odds_table(participants, odds_pack[:odds])

    # Ovdje su dozvoljene sve vrste oklada (WIN, PLACE, EXACTA)
    bet = place_bet(participants, odds_pack)

    if bet
      puts "\nRace starting..."
      sleep(1)
    end

    # Pokretanje simulacije
    sim = run_race_simulation(participants, sim)
    Horse.recover_all_injuries! # Oporavak ozljeda nakon utrke

    winner = sim.results.first[:horse]
    puts "\nWinner is #{winner.name}!"

    # Isplata oklade
    resolve_bet(bet, sim)

    puts "Press Enter..."
    gets
  end

  # =========================
  # Prvenstvo (turnirski način)
  # =========================

  def championship_mode
    puts "\n=== CHAMPIONSHIP MODE ==="
    @horses = Horse.active

    available = @horses.reject { |h| h.current_injury }
    if available.size < 8
      puts "Need at least 8 healthy horses for championship."
      return
    end

    # Random ždrijeb za turnir od 8 konja
    bracket = available.sample(8)
    fatigue = {}
    bracket.each { |h| fatigue[h.id] = h.effective_stamina } # Svi počinju sa svježom kondicijom

    round = 1
    # Turnir se igra dok ne ostane samo jedan konj (pobjednik)
    while bracket.size > 1
      puts "\n--- ROUND #{round}: #{bracket.size} HORSES ---"
      next_round = []

      # Utrke u parovima (1 na 1)
      bracket.each_slice(2).with_index do |pair, idx|
        break if pair.size < 2

        puts "\nMatch #{idx + 1}: #{pair.map(&:name).join(' vs ')}"
        
        sim = RaceSimulator.new(
          pair,
          Random.new_seed,
          race_type: "Championship",
          start_stamina: fatigue # Prenosimo umor iz prethodnih rundi
        )
        
        odds_pack = OddsCalculator.calculate(pair, terrain_segments: sim.terrain)
        display_odds_table(pair, odds_pack[:odds])
        
        # OGRANIČENJE: U prvenstvu je dozvoljeno samo WIN klađenje
        bet = place_bet(pair, odds_pack, allowed_types: [:win])
        
        puts "Press Enter to start race..."
        gets

        sim = run_race_simulation(pair, sim)
        Horse.recover_all_injuries!

        winner = sim.results.first[:horse]
        puts "Winner: #{winner.name}"
        
        resolve_bet(bet, sim)

        # Ažuriranje umora za pobjednika (djelomični oporavak prije sljedeće runde)
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
    puts "You earned $#{reward} for the championship title!"

    puts "Press Enter..."
    gets
  end

  # =========================
  # Prikaz simulacije utrke
  # =========================

  def run_race_simulation(horses, sim = nil)
    sim ||= RaceSimulator.new(horses)

    # Petlja simulacije dok svi konji ne završe
    until sim.finished
      sim.step
      print_race_state(sim, horses)
      sleep(sim.time_step * 0.5) # Kontrola brzine prikaza
    end
    sim
  end

  def print_race_state(sim, horses)
    system("cls") || system("clear") # Čišćenje ekrana za animaciju

    puts ("=" * 60)
    horses.each do |h|
      state = sim.get_state(h.id)

      # Izračun pozicije na stazi za vizualizaciju
      track_len_chars = 50
      pos_chars = (state[:position] / GameConfig::TRACK_LENGTH * track_len_chars).to_i
      pos_chars = track_len_chars if pos_chars > track_len_chars

      lane = "-" * track_len_chars
      begin
        lane[pos_chars] = h.symbol
      rescue
        lane[-1] = h.symbol
      end

      # Prikaz stamina bara
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
