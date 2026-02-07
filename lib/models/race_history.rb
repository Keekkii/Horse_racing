require_relative '../../db/database'
require 'json'

class RaceHistory
  attr_accessor :id, :date, :terrain_seed, :winner_id, :race_type

  def initialize(attributes = {})
    @id = attributes['id']
    @date = attributes['date']
    @terrain_seed = attributes['terrain_seed']
    @winner_id = attributes['winner_id']
    @race_type = attributes['race_type']
  end

  def self.create(winner_id, terrain_seed, race_type, participating_horses_results)
    # 1. Insert Race
    Database.connection.execute(
      "INSERT INTO races (date, terrain_seed, winner_id, race_type) VALUES (CURRENT_TIMESTAMP, ?, ?, ?)",
      [terrain_seed, winner_id, race_type]
    )
    race_id = Database.connection.last_insert_row_id
    
    # 2. Insert Results
    participating_horses_results.each do |result|
      # result: { horse_id, position, time, splits }
      Database.connection.execute(
        "INSERT INTO race_results (race_id, horse_id, position, finish_time, segment_times) VALUES (?, ?, ?, ?, ?)",
        [race_id, result[:horse_id], result[:position], result[:finish_time], result[:splits].to_json]
      )
    end
  end
end
