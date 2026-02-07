require_relative '../../db/database'
require_relative '../../config/game_config'

class Horse
  attr_accessor :id, :name, :symbol, :base_speed, :stamina_rating, :acceleration, :age, :races_run, :wins, :current_injury

  def initialize(attributes = {})
    @id = attributes['id']
    @name = attributes['name']
    @symbol = attributes['symbol']
    @base_speed = attributes['base_speed']
    @stamina_rating = attributes['stamina_rating']
    @acceleration = attributes['acceleration']
    @age = attributes['age']
    @races_run = attributes['races_run'] || 0
    @wins = attributes['wins'] || 0    
    load_injuries
  end

  def self.all
    Database.connection.execute("SELECT * FROM horses").map { |row| new(row) }
  end

  def self.find(id)
    row = Database.connection.execute("SELECT * FROM horses WHERE id = ?", id).first
    return nil unless row
    new(row)
  end

  def save
    Database.connection.execute(
      "UPDATE horses SET races_run = ?, wins = ?, age = ? WHERE id = ?",
      [@races_run, @wins, @age, @id]
    )
  end

  def load_injuries
    row = Database.connection.execute("SELECT * FROM injuries WHERE horse_id = ? AND races_remaining > 0", @id).first
    if row
      @current_injury = { type: row['injury_type'], severity: row['severity'], remaining: row['races_remaining'] }
    else
      @current_injury = nil
    end
  end

  def effective_speed
    mod = GameConfig::AGE_GRAPH[@age] || 0.6
    s = @base_speed * mod
    s *= (1.0 - (@current_injury[:severity] * 0.1)) if @current_injury
    s
  end

  def effective_stamina
    mod = GameConfig::AGE_GRAPH[@age] || 0.6
    s = @stamina_rating * mod
    s *= (1.0 - (@current_injury[:severity] * 0.1)) if @current_injury
    s
  end

  def injure!(type, severity, duration)
    Database.connection.execute(
      "INSERT INTO injuries (horse_id, injury_type, severity, races_remaining) VALUES (?, ?, ?, ?)",
      [@id, type, severity, duration]
    )
    load_injuries
  end

  def recover_one_race
    return unless @current_injury
    
    Database.connection.execute(
      "UPDATE injuries SET races_remaining = races_remaining - 1 WHERE horse_id = ? AND races_remaining > 0",
      [@id]
    )
    load_injuries
  end

  def age_up!
    @age += 1
    save
  end
end
