class_name NoiseSettings
extends Node


# Change this to a random number, or else the world will be the same every time you make a new game.
var world_seed: int = 0
var altitude_generator = FastNoiseLite.new() # Surface height noise
var worm_steering_noise = FastNoiseLite.new() # Steers the direction of Perlin Worms, used for caves

func initialize() -> void:
	if SaveManager.is_loading:
		var world_data = SaveManager.load_world()
		if not world_data.is_empty():
			world_seed = int(world_data["seed"])

	altitude_generator.noise_type = FastNoiseLite.TYPE_SIMPLEX
	altitude_generator.frequency = 0.003
	altitude_generator.seed = world_seed

	# Low frequency = smooth, gradual turns. High frequency = tight, twisty worms.
	worm_steering_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	worm_steering_noise.frequency = 0.04
	worm_steering_noise.seed = world_seed + 1
