require_relative '../../db/database'
require_relative '../../config/game_config'

class Horse
  attr_accessor :id, :name, :symbol, :base_speed, :stamina_rating, :acceleration,
                :age, :races_run, :wins, :current_injury, :retired

  def initialize(attributes = {})
    @id = attributes['id']
    @name = attributes['name']
    @symbol = attributes['symbol']
    @base_speed = attributes['base_speed'].to_f
    @stamina_rating = attributes['stamina_rating'].to_f
    @acceleration = attributes['acceleration'].to_f
    @age = attributes['age'].to_i
    @races_run = (attributes['races_run'] || 0).to_i
    @wins = (attributes['wins'] || 0).to_i
    @retired = (attributes['retired'] || 0).to_i
    load_injuries
  end

  # ------------------------
  # Queries
  # ------------------------

  def self.all
    Database.connection.execute("SELECT * FROM horses").map { |row| new(row) }
  end

  def self.active
    Database.connection.execute("SELECT * FROM horses WHERE retired = 0").map { |row| new(row) }
  end

  def self.find(id)
    row = Database.connection.execute("SELECT * FROM horses WHERE id = ?", id).first
    return nil unless row
    new(row)
  end

  # ------------------------
  # Persistence
  # ------------------------

  def save
    Database.connection.execute(
      "UPDATE horses SET races_run = ?, wins = ?, age = ?, retired = ? WHERE id = ?",
      [@races_run, @wins, @age, @retired, @id]
    )
  end

  # ------------------------
  # Injuries
  # ------------------------

  def load_injuries
    row = Database.connection.execute(
      "SELECT * FROM injuries WHERE horse_id = ? AND races_remaining > 0 ORDER BY id DESC LIMIT 1",
      @id
    ).first

    if row
      @current_injury = { type: row['injury_type'], severity: row['severity'].to_i, remaining: row['races_remaining'].to_i }
    else
      @current_injury = nil
    end
  end

  def injure!(type, severity, duration)
    Database.connection.execute(
      "INSERT INTO injuries (horse_id, injury_type, severity, races_remaining) VALUES (?, ?, ?, ?)",
      [@id, type, severity, duration]
    )
    load_injuries
  end

  # Global recovery (call once per completed race event)
  def self.recover_all_injuries!
    Database.connection.execute(
      "UPDATE injuries SET races_remaining = races_remaining - 1 WHERE races_remaining > 0"
    )
  end

  # ------------------------
  # Age curve (smooth function)
  # ------------------------

  def age_multiplier
    peak = GameConfig::PEAK_AGE.to_f
    age = @age.to_f

    if age <= peak
      # from ~0.6 at age 0 to 1.0 at peak
      (0.6 + (age / peak) * 0.4)
    else
      # decline after peak, capped
      decline = [age - peak, 5.0].min
      (1.0 - decline * 0.10)
    end.clamp(0.4, 1.0)
  end

  # ------------------------
  # Form
  # ------------------------

  def form_multiplier(n: GameConfig::FORM_RACES_N)
    rows = Database.connection.execute(
      <<~SQL, [@id, n]
        SELECT rr.position
        FROM race_results rr
        WHERE rr.horse_id = ?
        ORDER BY rr.id DESC
        LIMIT ?
      SQL
    )

    return 1.0 if rows.empty?

    pos_to_score = lambda do |pos|
      case pos.to_i
      when 1 then 1.0
      when 2 then 0.7
      when 3 then 0.5
      when 4 then 0.35
      else 0.2
      end
    end

    weights = GameConfig::FORM_WEIGHTS.first(rows.length)
    w_sum = weights.sum
    weights = weights.map { |w| w / w_sum }

    weighted_score = 0.0
    rows.each_with_index do |r, idx|
      weighted_score += pos_to_score.call(r['position']) * weights[idx]
    end

    # score ~ 0.2..1.0 → convert around 1.0 multiplier
    (1.0 + (weighted_score - 0.5) * (2.0 * GameConfig::FORM_IMPACT)).round(4)
  end

  # ------------------------
  # Effective stats
  # ------------------------

  def effective_stats(form_n: GameConfig::FORM_RACES_N)
    age_mod = age_multiplier

    injury_mod = 1.0
    if @current_injury
      injury_mod -= (@current_injury[:severity] * 0.10)
      injury_mod = 0.1 if injury_mod < 0.1
    end

    form_mod = form_multiplier(n: form_n)

    {
      speed: (@base_speed * age_mod * injury_mod * form_mod),
      stamina: (@stamina_rating * age_mod * injury_mod * form_mod),
      acceleration: (@acceleration * age_mod * injury_mod),
      age_mod: age_mod,
      injury_mod: injury_mod,
      form_mod: form_mod
    }
  end

  def effective_speed
    effective_stats[:speed]
  end

  def effective_stamina
    effective_stats[:stamina]
  end

  # ------------------------
  # Aging + retirement
  # ------------------------

  def check_aging!
    return unless @races_run > 0
    if (@races_run % GameConfig::RACES_PER_YEAR) == 0
      @age += 1
      save
    end
  end

  def should_retire?
    return true if @age >= GameConfig::FORCED_RETIRE_AGE
    return false if @age < GameConfig::MIN_RETIRE_AGE
    rand < GameConfig::RETIRE_CHANCE_PER_YEAR
  end

  def retire!
    @retired = 1
    save
  end

  def self.create_rookie!
    name = "Rookie#{rand(1000..9999)}"
    symbol = ('A'..'Z').to_a.sample

    Database.connection.execute(
      "INSERT INTO horses (name, symbol, base_speed, stamina_rating, acceleration, age, races_run, wins, retired)
       VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0)",
      [
        name,
        symbol,
        rand(6.5..8.5).round(2),
        rand(6.0..8.5).round(2),
        rand(6.0..8.5).round(2),
        2
      ]
    )
  end
end
