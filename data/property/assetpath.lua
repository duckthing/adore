local Property = require "data.property"
---@type Adore.Loader
local Loader = require "loader"

---@class Property.AssetPath: Property
local AssetP = Property:extend()
AssetP.TYPE = "AssetPath"

function AssetP:new(class, property, collectionName, defaultValue, setter)
	AssetP.super.new(self, class, property, defaultValue or class[property] or "")

	---@type string # The collection
	self.collectionName = collectionName

	if setter then self:withSetter(setter) end
end

function AssetP:add(a, b)
	return a
end

function AssetP:serialize(obj, propertyName, value, resources)
	if value then
		local collection = Loader.getCollection(self.collectionName)
		local path, _ = collection:getAssetPath(value)

		if path then
			return path
		else
			print(
				("[Property.AssetPath] Couldn't find the path for the asset in %s (on %s:%s)")
				:format(self.collectionName, tostring(obj), propertyName)
			)
		end
	end
end

function AssetP:deserialize(obj, propertyName, path, resources)
	if path ~= "" then
		local collection = Loader.getCollection(self.collectionName)

		local success, assetOrErr = pcall(collection.get, collection, path)
		if success then
			-- Loaded the asset
			self:set(obj, propertyName, assetOrErr)
		else
			-- Errored, print it out
			print(
				("[Property.AssetPath] Errored in %s['%s'] trying to load an asset at '%s':\n%s")
				:format(tostring(obj), propertyName, path, assetOrErr)
			)
		end
	end
end

return AssetP
