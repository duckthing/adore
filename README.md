<div align="center">
<h1>Adore</h1>
</div>

> [!WARNING]
> Since the API hasn't needed many drastic changes in a while, I've decided to release this. There may still be large
> refactors, hidden problems, and missing features that need to be added, so try at your own risk.

Adore is a library to combine the productivity and comfort of Godot with the flexibility of Love2D. It was initially
created to have a common UI framework between all of my projects, and has grown over time. Currently built for
Love2D v11.5.

## Features
* 2D
	* Wrappers around physics (via `Physical2d`-inherited objects)
		* Multiple physics worlds are supported (via a new `CanvasLayer` with a new `Viewport`)
	* Lighting
		* Screen-space lighting (and optional shadows)
		* ...or no lighting, by default
	* Render to **every** resolution you can think of
		* Set a target resolution independent from the window
			* Set a scale mode; keep the aspect ratio, stretch to fit, or do no canvas scaling at all
		* Scale up the pixel scale to render at a low resolution at any window size
		* Each `CanvasLayer` can have their own `Viewport` with a separate render resolution
	* Render separate scenes to different `CanvasLayer`s, apply post-processing, and more
* UI/Control
	* Themes
		* Inherit from other themes
		* Set overrides for certain parts of the tree
	* Keyboard and gamepad navigation
		* ...which can be modified/disabled via `CoreUIContext` and the input stack
	* Scale, rotate, and animate Controls while keeping mouse input functional
* Asset loader
	* Load an asset only once, and reference it anywhere
	* Load `.glsl` files into a shader
	* Importer-like asset collections
		* Some asset collections can cache their results, for faster second-launches (optionally)
		* If you cache all assets, you can include the cache folder in your game export and remove your original assets
	* AtlasLoader can automatically put all of your assets into an atlas
		* No refactoring required; get your assets like normal, and it will be taken from the atlas if loaded
	* SheetLoader can make frames for each part of your spritesheet
	* Write your own asset handler for your own assets
* Input stack
	* Standard game input (which keeps track of pressed/released states and axes) supported through `GameContext`
	* Other inputs, such as keyboard shortcuts, are supported through `ShortcutContext`
	* Sink input to prevent other Contexts from receiving it
		* Disable all default input sinks included with Adore (through `CoreUIContext` and `MainLoopContext`)
* Animation
	* Keyframes mark certain points
		* Property tracks can either lerp or jump to a specific value, based on the track mode and value type
			* ...and in Godot fashion, anything can be animated, but not everything is smooth
			* ...and you need to define the types first
		* Method tracks can call methods on a `Node`
	* Play forwards and backwards, with varying speeds
* Tweens
	* A convenient way to create temporary animations
	* Tween a function parameter with `:tweenArgument`, and run custom code with little boilerplate
* Math functions can avoid creating intermediary objects
	* In `Vec2`, methods that are prefixed with `:i...` are in-place, meaning they overwrite the existing object
* Pause processing at any step of the tree

## Minimal example
Clone the project into any folder. It may not work outside of your project root (`./adore`).
```sh
# Include Adore as a submodule (if you have an existing repository)
git submodule add https://github.com/duckthing/adore.git
# After adding the submodule, you'll have to update the submodules recursively
git submodule update --init --recursive

# Or as a basic clone
# (The project includes submodules, so you have to do a recursive clone)
git clone https://github.com/duckthing/adore.git --recursive
```
In `main.lua`, put the following:
```lua
local Adore = require "adore"

function love.load()
	local root = Adore:build()
	root:addMissingCallbacks()
end
```
When ran for one second, this should print to the console that you are missing a scene.
>[!WARNING]
>Do not set `love.update` or `love.draw`. Adore sets those with `root:addMissingCallbacks()`.

Scenes are functions. Write your own in here:
```lua
local Adore = require "adore"
local Nodes = Adore.Nodes
local Node2d = Nodes("Node2d")
local Sprite = Nodes("Sprite")

local TextureLoader = Adore.Loader.getCollection("TextureLoader")
local playerImage = TextureLoader:get("assets/player.png")

---@type SceneFunction
local function myScene(parent)
	-- Create a scene root
	local scene = Node2d()

	-- Build your tree here
	local sprite = Sprite()
	sprite:setTexture(playerImage)
	scene:addChild(sprite)
	--...

	-- Once done, add it to the parent if it was passed
	if parent then
		parent:addChild(scene)
	end

	-- Then return the scene root
	return scene
end

-- Change the scene through the root
root:changeSceneTo(myScene)
```
You may want some way to get input now. Use a new `GameContext`.
```lua
local Adore = "adore"
local GameContext = Adore.Resources("GameContext")

local inputContext = GameContext({
	actions = {
		-- Actions are an independent value, from 0..1
		"left", "right", "up", "down",
		"interact",
	},
	pairs = {
		-- Pairs are combinations of different actions
		move = {"left", "right", "up", "down"},
	},
	scancodes = {
		-- Scancodes map to actions
		a = "left",
		d = "right",
		s = "down",
		w = "up",

		e = "interact",
	},
	gamepadAxes = {
		-- So do gamepad axes/buttons
		["leftx-"] = "left",
		["leftx+"] = "right",
		["lefty-"] = "up",
		["lefty+"] = "down",
	},
	gamepadButtons = {
		a = "interact"
	}
})
inputContext.name = "MyInput"

-- In your scene...
function myScene(parent)
	--...
	-- Push the Context
	-- When changing scenes, all pushed Contexts will be removed before instancing the new scene
	inputContext:push()
	return scene
end

-- Somewhere else...
local Player = Adore.Nodes("RigidBody"):extend()
Player.CLASS_NAME = "Player"

function Player:new(...)
	Player.super.new(self, ...)
	self.speed = 10
end

function Player:update(dt)
	local x, y = inputContext:getVector("move")
	--...
	if inputContext:isJustPressed("interact") then
		--...
	end
end
```
Maybe your scene isn't behaving. Load the editor (`Toolbox`) and press the backtick key <kbd>`</kbd> to open it.
```lua
-- main.lua
function love.load()
	local root = Adore
		-- Insert this before `:build`
		:with(require "adore.toolbox")
		:build(...)
	--...
end
```
Having experience with Godot will be very useful, but Adore has more differences that you'll find later. Setting up
sumneko's Lua Language Server may help; almost every part of Adore is annotated and documented.

> [!NOTE]
> The wiki (which I haven't set up at this time) should go over deeper concepts. It will be a link on this page
> eventually.

## Contributing
Feel free to open issues and pull requests. New features should be discussed in the issues before making a pull request.
Any content suspected to be assisted/created with generative AI/LLM (other than translation) will not be accepted due
to legal and ethical concerns.

## Platform Support
The target platforms for Adore is *Windows*, *Linux*, and *web* (through [love.js](https://github.com/Davidobot/love.js/)).
I do not have the ability to test Android, iOS, and Mac right now.

> [!NOTE]
> Some parts of Adore do not work on all targets. See [INCOMPATIBILITY.md](./INCOMPATIBILITY.md) for more information.

## Acknowledgments
These projects are used within Adore (inside `./lib`). You are also required to acknowledge them in your projects.

* classic, flux, and shash.lua (by *rxi*, MIT)
* nativefs (by *megagrump*, MIT)
* tinytoml (by *FourierTransformer*, MIT)
* numberlua (by *David Manura*, MIT)
* InputField (by *Marcus 'ReFreezed' Thunström*, MIT)
* Runtime-TextureAtlas (by *EngineerSmith*, MIT)

## License
Unless otherwise noted, all files outside of `./lib` are licensed under the terms of the [zlib license](./LICENSE).
There are a few dependencies that are under a different license, which all require acknowledgment by your project.
