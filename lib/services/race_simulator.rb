require_relative '../../config/game_config'
require_relative '../models/race_history'
require_relative '../models/horse'
require_relative 'terrain_generator'

class RaceSimulator
  attr_reader :results, :finished, :time_step

  def initialize(horses, seed = nil)
    @horses = horses
    @seed = seed || Random.new_seed
    @terrain = TerrainGenerator.generate_terrain(@seed)
    @time_step = 0.5 # seconds
    @current_time = 0.0
    @horse_states = {} # Tracks dynamic state (position, stamina, etc.)
    @results = []
    @finished = false

    initialize_states
  end

  def initialize_states
    @horses.each do |horse|
      @horse_states[horse.id] = {
        position: 0.0,
        stamina: horse.effective_stamina,
        current_speed: 0.0,
        finished: false,
        segment_splits: [],
        finish_time: nil,
        injured: false,
        exhausted: false
      }
    end
  end

  def step
    return if @finished
    
    active_horses = 0

    @horses.each do |horse|
      state = @horse_states[horse.id]
      next if state[:finished]

      active_horses += 1
      
      # 1. Determine current terrain segment
      segment_index = (state[:position] / GameConfig::SEGMENT_LENGTH).floor
      segment = @terrain[segment_index] || @terrain.last # Fallback if past end
      
      # 2. Calculate Target Speed
      # Base speed * Terrain Modifier
      target_speed = horse.effective_speed * segment[:modifiers][:speed]
      
      # 3. Stamina Management
      max_stamina = horse.effective_stamina
      
      # Can only use stamina if not exhausted
      if state[:stamina] > 0 && !state[:exhausted]
        target_speed *= GameConfig::BOOST_SPEED_MULTIPLIER
        # Drain: base * terrain_drain * speed_factor (faster = more drain)
        drain = GameConfig::STAMINA_DRAIN_BASE * segment[:modifiers][:stamina_drain] * @time_step
        state[:stamina] -= drain
        
        # If drained, become exhausted
        if state[:stamina] <= 0
          state[:stamina] = 0.0
          state[:exhausted] = true
        end
      else
        # Recovering or Empty
        target_speed *= GameConfig::DEPLETED_SPEED_MULTIPLIER # Reduced speed while recovering
        
        # Stamina Recovery (slow) if pacing allows
        recovery = GameConfig::RECOVERY_RATE * @time_step
        state[:stamina] += recovery
        
        # Cap at max stamina
        if state[:stamina] >= max_stamina
          state[:stamina] = max_stamina
          state[:exhausted] = false # Fully recovered, can boost again
        end
      end

      # Apply Acceleration to reach Target Speed
      # Accelerate
      if state[:current_speed] < target_speed
        state[:current_speed] += horse.acceleration * @time_step
        state[:current_speed] = target_speed if state[:current_speed] > target_speed
      # Decelerate (fatigue or terrain change) - instant for now or use gravity?
      # Let's use acceleration for braking too effectively
      elsif state[:current_speed] > target_speed
        state[:current_speed] -= horse.acceleration * @time_step
        state[:current_speed] = target_speed if state[:current_speed] < target_speed
      end

      # 4. Move
      distance_moved = state[:current_speed] * @time_step
      state[:position] += distance_moved
      # state[:current_speed] is already updated

      # 5. Check Injury
      # Use segment modifier directly (e.g. 0.01) * time_step. 
      # Removing the extra 0.01 multiplier which made it 0.0001
      injury_threshold = segment[:modifiers][:injury_chance] * @time_step
      
      if !state[:injured] && rand < injury_threshold
        # Very small chance per step
        state[:injured] = true
        # Apply immediate penalty
        state[:current_speed] *= 0.5
        # Injure model later
      end

      # 6. Check Finish
      if state[:position] >= GameConfig::TRACK_LENGTH
        state[:finished] = true
        state[:finish_time] = @current_time
        state[:position] = GameConfig::TRACK_LENGTH # Clamp
        
        # Record result
        @results << {
          horse: horse,
          time: @current_time,
          splits: state[:segment_splits],
          injured: state[:injured]
        }
      end
    end

    @current_time += @time_step
    
    if active_horses == 0
      @finished = true
      record_race
    end
  end

  def record_race
    # Sort results by time
    @results.sort_by! { |r| r[:time] }
    
    # Save History
    winner_id = @results.first[:horse].id
    result_data = @results.map.with_index do |r, idx|
       {
         horse_id: r[:horse].id,
         position: idx + 1,
         finish_time: r[:time],
         splits: r[:splits]
       }
    end
    
    RaceHistory.create(winner_id, @seed, "Standard", result_data)

    # Process Injuries & Stats
    @results.each do |r|
       horse = r[:horse]
       # Update generic stats (races run)
       horse.races_run += 1
       if r[:horse].id == winner_id
         horse.wins += 1
       end
       
       # Apply injury if happened
       if r[:injured]
         # severity 1-3
         severity = rand(1..3)
         duration = rand(2..5)
         horse.injure!("Strain", severity, duration)
       else
         # Recover existing
         horse.recover_one_race
       end
       
       horse.save # Presumes save updates runs/wins
    end
  end
  
  # For UI animation
  def get_state(horse_id)
    @horse_states[horse_id]
  end
end
