require_relative '../../config/game_config'
require_relative '../models/race_history'
require_relative '../models/horse'
require_relative 'terrain_generator'

class RaceSimulator
  attr_reader :results, :finished, :time_step, :race_id, :seed, :terrain

  def initialize(horses, seed = nil, race_type: "Standard", start_stamina: {})
    @horses = horses
    @seed = seed || Random.new_seed
    @race_type = race_type
    @start_stamina = start_stamina
    @terrain = TerrainGenerator.generate_terrain(@seed)
    @time_step = 0.5 # sekunde po koraku simulacije
    @current_time = 0.0
    @horse_states = {}
    @results = []
    @finished = false
    @race_id = nil

    initialize_states
  end

  # Postavljanje početnog stanja za svakog konja
  def initialize_states
    @horses.each do |horse|
      stats = horse.effective_stats

      base_stamina = stats[:stamina]
      # Ako je definiran start_stamina (npr. u prvenstvu), koristimo manju vrijednost
      start_override = @start_stamina && @start_stamina[horse.id]
      start_stamina = start_override ? [start_override, base_stamina].min : base_stamina

      @horse_states[horse.id] = {
        position: 0.0,
        stamina: start_stamina,
        current_speed: 0.0,
        finished: false,
        segment_splits: [],
        next_segment_boundary: GameConfig::SEGMENT_LENGTH.to_f,
        segment_start_time: 0.0,
        finish_time: nil,
        injured: false,
        exhausted: false
      }
    end
  end

  # Glavni korak simulacije (poziva se u petlji)
  def step
    return if @finished

    active_horses = 0

    @horses.each do |horse|
      state = @horse_states[horse.id]
      next if state[:finished]
      active_horses += 1

      # Određivanje trenutnog segmenta terena
      segment_index = (state[:position] / GameConfig::SEGMENT_LENGTH).floor
      segment = @terrain[segment_index] || @terrain.last

      # Dinamičke statistike (dob + ozljede + forma)
      stats = horse.effective_stats
      max_stamina = stats[:stamina]

      target_speed = stats[:speed] * segment[:modifiers][:speed]

      # Logika Stamine
      if state[:stamina] > 0 && !state[:exhausted]
        # Ako ima stamine, konj može "boostati" (brže od osnovne brzine)
        target_speed *= GameConfig::BOOST_SPEED_MULTIPLIER

        # Potrošnja stamine ovisi o brzini i terenu
        speed_factor = [[state[:current_speed] / [stats[:speed], 0.0001].max, 0.5].max, 1.5].min
        drain = GameConfig::STAMINA_DRAIN_BASE * segment[:modifiers][:stamina_drain] * speed_factor * @time_step
        state[:stamina] -= drain

        if state[:stamina] <= 0
          state[:stamina] = 0.0
          state[:exhausted] = true # Konj se umorio
        end
      else
        # Ako je iscrpljen, kreće se sporije i oporavlja staminu
        target_speed *= GameConfig::DEPLETED_SPEED_MULTIPLIER

        recovery = GameConfig::RECOVERY_RATE * @time_step
        state[:stamina] += recovery

        if state[:stamina] >= max_stamina
          state[:stamina] = max_stamina
          state[:exhausted] = false # Oporavljen
        end
      end

      # Akceleracija (postepeno ubrzavanje/usporavanje prema ciljanoj brzini)
      if state[:current_speed] < target_speed
        state[:current_speed] += stats[:acceleration] * @time_step
        state[:current_speed] = target_speed if state[:current_speed] > target_speed
      elsif state[:current_speed] > target_speed
        state[:current_speed] -= stats[:acceleration] * @time_step
        state[:current_speed] = target_speed if state[:current_speed] < target_speed
      end

      # Pomicanje
      state[:position] += state[:current_speed] * @time_step

      # Bilježenje prolaznih vremena (splits)
      while state[:position] >= state[:next_segment_boundary] && state[:next_segment_boundary] < GameConfig::TRACK_LENGTH
        split_time = @current_time - state[:segment_start_time]
        state[:segment_splits] << split_time.round(3)
        state[:segment_start_time] = @current_time
        state[:next_segment_boundary] += GameConfig::SEGMENT_LENGTH
      end

      # Rizik od ozljede: teren + stamina + dob + tip utrke
      stamina_ratio = max_stamina <= 0 ? 0.0 : (state[:stamina] / max_stamina)
      low_th = GameConfig::INJURY_STAMINA_LOW_THRESHOLD
      stamina_mult = 1.0
      if stamina_ratio < low_th
        scale = (low_th - stamina_ratio) / low_th
        stamina_mult = 1.0 + scale * (GameConfig::INJURY_STAMINA_RISK_MAX - 1.0)
      end

      if horse.age >= GameConfig::PEAK_AGE
        age_mult = 1.0 + (horse.age - GameConfig::PEAK_AGE) * GameConfig::INJURY_AGE_RISK_PER_YEAR_OVER_PEAK
      else
        age_mult = 1.0 + (GameConfig::PEAK_AGE - horse.age) * GameConfig::INJURY_AGE_RISK_PER_YEAR_UNDER_PEAK
      end

      type_mult = GameConfig::RACE_TYPE_INJURY_MULTIPLIERS[@race_type] || 1.0

      injury_threshold = segment[:modifiers][:injury_chance] * stamina_mult * age_mult * type_mult * @time_step

      if !state[:injured] && rand < injury_threshold
        state[:injured] = true
        state[:current_speed] *= 0.5 # Ozljeda drastično usporava konja
      end

      # Provjera cilja
      if state[:position] >= GameConfig::TRACK_LENGTH
        state[:finished] = true
        state[:finish_time] = @current_time
        state[:position] = GameConfig::TRACK_LENGTH

        last_split = @current_time - state[:segment_start_time]
        state[:segment_splits] << last_split.round(3)

        @results << {
          horse: horse,
          time: @current_time,
          splits: state[:segment_splits],
          injured: state[:injured]
        }
      end
    end

    @current_time += @time_step

    # Ako su svi završili, spremi rezultate
    if active_horses == 0
      @finished = true
      record_race
    end
  end

  # Spremanje rezultata utrke u bazu i ažuriranje statusa konja
  def record_race
    @results.sort_by! { |r| r[:time] }

    winner_id = @results.first[:horse].id
    result_data = @results.map.with_index do |r, idx|
      {
        horse_id: r[:horse].id,
        position: idx + 1,
        finish_time: r[:time],
        splits: r[:splits]
      }
    end

    @race_id = RaceHistory.create(winner_id, @seed, @race_type, result_data)

    # Ažuriranje statistika konja (pobjede, utrke, ozljede, starenje)
    @results.each do |r|
      horse = r[:horse]
      horse.races_run += 1
      horse.wins += 1 if horse.id == winner_id

      if r[:injured]
        severity = rand(GameConfig::INJURY_SEVERITY_RANGE)
        duration = rand(GameConfig::INJURY_DURATION_RANGE)
        horse.injure!("Strain", severity, duration)
      end

      horse.check_aging!
      if horse.should_retire?
        horse.retire!
        Horse.create_rookie! # Zamijeni umirovljenog konja novim
      end

      horse.save
    end
  end

  def get_state(horse_id)
    @horse_states[horse_id]
  end
end
